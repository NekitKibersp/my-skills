-- Логика зон большой карты (детали строит ZoneBuilder): телепорт-площадки, Башня мемов (лава,
-- чекпоинты, исчезающие платформы, вращающиеся перекладины, призы ярусов раз в день),
-- Торговая площадь (безопасная зона: атрибут персонажа InSafeZone, вор с мемом его роняет),
-- Конфетный парк (батуты и сезонные пикапы с лимитом) и секретная пещера (сундук раз в день).
-- Всё решает сервер: касания, дистанции, кулдауны, награды. Любой серверный перенос персонажа
-- ставит ServerMovedAt — анти-чит переноски (StealService) не считает его телепортом читера.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local StealService = require(script.Parent.StealService)
local Grant = require(script.Parent.Grant)
local BattlePassService = require(script.Parent.BattlePassService)
local Remotes = require(script.Parent.Remotes)

local ZoneService = {}

local ZONES = Config.Zones
local SAFE_HEIGHT = 60 -- выше площади (батут, ракета) — уже не безопасная зона

type PlayerState = {
	Checkpoint: number, -- последний чекпоинт башни (1 — старт)
	Reached: { [number]: number }, -- чекпоинт -> os.clock() последнего касания
	LastTeleport: number,
	LastLava: number,
	LastTrampoline: number,
	LastPrizeTouch: number,
	LastPickup: number,
	PickupTimes: { number },
	Notified: { [string]: number }, -- ключ уведомления -> os.clock() (не спамим)
}

local states: { [Player]: PlayerState } = {}
local zones: any = nil
local pickupCount = 0

local function clock(): number
	return os.clock()
end

local function today(): number
	return os.time() // 86400
end

local function stateOf(player: Player): PlayerState?
	return states[player]
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function alive(player: Player): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

-- Игрок, чья деталь коснулась (в том числе аксессуар: Handle -> Accessory -> персонаж)
local function playerFromHit(hit: BasePart): Player?
	local parent = hit.Parent
	if not parent then
		return nil
	end
	local player = Players:GetPlayerFromCharacter(parent)
	if not player and parent.Parent then
		player = Players:GetPlayerFromCharacter(parent.Parent)
	end
	return player
end

local function notify(player: Player, key: string, args: { [string]: any }?, kind: string, every: number)
	local state = stateOf(player)
	if not state then
		return
	end
	local t = clock()
	if t - (state.Notified[key] or -math.huge) < every then
		return
	end
	state.Notified[key] = t
	Remotes.Notify:FireClient(player, key, args, kind)
end

-- Серверный перенос персонажа (не телепорт читера для анти-чита переноски)
local function moveCharacter(player: Player, cframe: CFrame)
	local character = player.Character
	local root = rootOf(player)
	if not character or not root then
		return
	end
	character:SetAttribute("ServerMovedAt", workspace:GetServerTimeNow())
	root.AssemblyLinearVelocity = Vector3.zero
	character:PivotTo(cframe)
end

local function nearPart(player: Player, target: BasePart, range: number): boolean
	local root = rootOf(player)
	return root ~= nil and (root.Position - target.Position).Magnitude <= range + target.Size.Magnitude / 2
end

-- ===== Телепорт-площадки =====

local function destination(player: Player, target: string): CFrame?
	if target == "Base" then
		local plot = PlotService.GetPlot(player)
		return if plot then PlotService.SpawnPoint(plot) else nil
	elseif target == "TowerDown" then
		return zones.Destinations.Tower
	end
	return zones.Destinations[target]
end

local function onPad(player: Player, pad: BasePart)
	local state = stateOf(player)
	if not state or not alive(player) or not nearPart(player, pad, ZONES.Teleport.PadRange) then
		return
	end
	local t = clock()
	if t - state.LastTeleport < ZONES.Teleport.Cooldown then
		return
	end
	if StealService.IsCarrying(player) then
		notify(player, "ZoneTpCarrying", nil, "error", 3)
		return
	end
	local target = pad:GetAttribute("Target")
	local cframe = if type(target) == "string" then destination(player, target) else nil
	if not cframe then
		return
	end
	state.LastTeleport = t
	if target == "Tower" or target == "TowerDown" then
		state.Checkpoint = 1
	end
	-- StreamingEnabled: сначала подгружаем место назначения клиенту, потом переносим
	local destinationCFrame = cframe :: CFrame
	task.spawn(function()
		pcall(function()
			player:RequestStreamAroundAsync(destinationCFrame.Position, 2)
		end)
		-- За время ожидания игрок мог взять мема или выйти
		if player.Parent and stateOf(player) and alive(player) and not StealService.IsCarrying(player) then
			moveCharacter(player, destinationCFrame)
		end
	end)
end

-- ===== Башня мемов =====

local function checkpointSpawn(index: number): CFrame
	local entry = zones.Tower.Checkpoints[index] or zones.Tower.Checkpoints[1]
	return entry.Spawn
end

local function onLava(player: Player)
	local state = stateOf(player)
	if not state or not alive(player) then
		return
	end
	local t = clock()
	if t - state.LastLava < 1 then
		return
	end
	state.LastLava = t
	-- С мемом в лаву — мем возвращается хозяину (иначе лава стала бы бесплатным телепортом)
	if StealService.IsCarrying(player) then
		StealService.Fail(player)
	end
	moveCharacter(player, checkpointSpawn(state.Checkpoint))
	notify(player, "TowerLava", nil, "info", 4)
end

-- Касание чекпоинта. Новый чекпоинт засчитывается, только если предыдущий был взят
-- не меньше MinTierSeconds назад (защита от телепорта прямо к вершине).
local function onCheckpoint(player: Player, index: number)
	local state = stateOf(player)
	if not state or not alive(player) then
		return
	end
	local t = clock()
	local reached = state.Reached
	if not reached[index] and index > 1 then
		local previous = reached[index - 1]
		if not previous or t - previous < ZONES.Tower.MinTierSeconds then
			return
		end
	end
	reached[index] = t
	if index > state.Checkpoint then
		notify(player, "TowerCheckpoint", { Tier = index }, "success", 2)
	end
	state.Checkpoint = index
end

local function pickWeighted(options: { any }): any
	local total = 0
	for _, option in options do
		total += option.Weight
	end
	local roll = math.random() * total
	for _, option in options do
		roll -= option.Weight
		if roll <= 0 then
			return option
		end
	end
	return options[#options]
end

-- Выдать список наград и сложить итог для Popup
local function giveAll(player: Player, rewards: { any }): { [string]: any }
	local total: { [string]: any } = {}
	for _, reward in rewards do
		local result = Grant.Give(player, reward)
		if result.Coins then
			total.Coins = (total.Coins or 0) + result.Coins
		end
		if result.Spins then
			total.Spins = (total.Spins or 0) + result.Spins
		end
		if result.Meme then
			total.Meme = result.Meme
		end
	end
	return total
end

local function onPrize(player: Player, tier: number)
	local state = stateOf(player)
	if not state or not alive(player) or not DataService.IsLoaded(player) then
		return
	end
	local t = clock()
	if t - state.LastPrizeTouch < 1.5 then
		return
	end
	state.LastPrizeTouch = t
	-- Приз яруса N стоит на чекпоинте N + 1: засчитываем его (с той же проверкой времени)
	onCheckpoint(player, tier + 1)
	local started = state.Reached[tier]
	if not started or not state.Reached[tier + 1] or t - started < ZONES.Tower.MinTierSeconds then
		return
	end
	local options = ZONES.Tower.Prizes[tier]
	if not options then
		return
	end
	local data = DataService.GetTable(player, "Zones")
	local key = "Tower" .. tier
	local day = today()
	if data[key] == day then
		notify(player, "TowerPrizeTaken", nil, "info", 6)
		return
	end
	data[key] = day
	local total = giveAll(player, pickWeighted(options).Rewards)
	total.Zone = "Tower"
	total.Tier = tier
	Remotes.Popup:FireClient(player, "Zone", total)
	local root = rootOf(player)
	if root then
		Remotes.Fx:FireAllClients("Merged", { Position = root.Position })
	end
end

-- Вращение перекладин (каждый кадр) и проверка задевших игроков (математикой: Touched
-- у детали, которую двигают через CFrame, срабатывает ненадёжно)
local spinAngle = 0
local function spinStep(dt: number)
	spinAngle = (spinAngle + dt * ZONES.Tower.SpinSpeed) % (math.pi * 2)
	for _, spinner in zones.Tower.Spinners do
		spinner.Part.CFrame = CFrame.new(spinner.Center) * CFrame.Angles(0, spinAngle + spinner.Phase, 0)
	end
end

local function spinnerHits()
	local center = zones.Tower.Center
	for player in states do
		local root = rootOf(player)
		if not root then
			continue
		end
		local position = root.Position
		if Vector3.new(position.X - center.X, 0, position.Z - center.Z).Magnitude > zones.Tower.Radius then
			continue
		end
		for _, spinner in zones.Tower.Spinners do
			-- Корень персонажа ~3 studs над платформой, перекладина ~1.5 над ней
			local dy = position.Y - spinner.Center.Y
			if dy < -1.5 or dy > 3.4 then
				continue
			end
			local offset = Vector3.new(position.X - spinner.Center.X, 0, position.Z - spinner.Center.Z)
			local axis = spinner.Part.CFrame.RightVector
			axis = Vector3.new(axis.X, 0, axis.Z)
			if axis.Magnitude < 0.01 then
				continue
			end
			axis = axis.Unit
			local along = offset:Dot(axis)
			local perpendicular = (offset - axis * along).Magnitude
			if math.abs(along) <= spinner.Length / 2 + 0.5 and perpendicular <= 1.6 then
				onLava(player)
				break
			end
		end
	end
end

-- Исчезающие платформы: видна VanishShown сек, мигает последние 0.5 сек, пропадает на VanishHidden
local function vanishStep()
	local shown, hidden = ZONES.Tower.VanishShown, ZONES.Tower.VanishHidden
	local cycle = shown + hidden
	local t = clock()
	for _, entry in zones.Tower.Vanishing do
		local phase = (t + entry.Offset) % cycle
		local solid = phase < shown
		local transparency = if not solid then 0.9 elseif phase > shown - 0.5 then 0.55 else 0.1
		if entry.Part.CanCollide ~= solid then
			entry.Part.CanCollide = solid
		end
		if entry.Part.Transparency ~= transparency then
			entry.Part.Transparency = transparency
		end
	end
end

-- ===== Торговая площадь: безопасная зона =====

local function inPlaza(position: Vector3): boolean
	local plaza = zones.Plaza
	return math.abs(position.X - plaza.Center.X) <= plaza.Size.X / 2
		and math.abs(position.Z - plaza.Center.Z) <= plaza.Size.Y / 2
		and position.Y < plaza.Center.Y + SAFE_HEIGHT
end

local function safeZoneStep()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = rootOf(player)
		if not character or not root then
			continue
		end
		local inside = inPlaza(root.Position) and alive(player)
		if (character:GetAttribute("InSafeZone") == true) ~= inside then
			character:SetAttribute("InSafeZone", inside)
		end
		if inside and StealService.IsCarrying(player) then
			notify(player, "SafeZoneDrop", { Meme = player:GetAttribute("Carrying") }, "error", 2)
			StealService.Fail(player)
		end
	end
end

-- ===== Конфетный парк =====

local function onTrampoline(player: Player, trampoline: BasePart)
	local state = stateOf(player)
	if not state or not alive(player) or not nearPart(player, trampoline, 6) then
		return
	end
	local t = clock()
	if t - state.LastTrampoline < ZONES.Park.TrampolineCooldown then
		return
	end
	state.LastTrampoline = t
	local character = player.Character :: Model
	local root = rootOf(player) :: BasePart
	-- Грейс анти-чита: прыжок с батута быстрее обычного бега
	character:SetAttribute("MoveGraceUntil", workspace:GetServerTimeNow() + 3)
	local velocity = root.AssemblyLinearVelocity
	local flat = Vector3.new(velocity.X, 0, velocity.Z)
	if flat.Magnitude > 30 then
		flat = flat.Unit * 30
	end
	Remotes.Knockback:FireClient(player, flat + Vector3.new(0, ZONES.Park.TrampolinePower, 0), 0)
end

local PICKUP_LOOKS = {
	Halloween = { Emoji = "🍬", Colors = { Color3.fromRGB(255, 140, 30), Color3.fromRGB(170, 70, 255) }, Shape = "Ball" },
	Winter = { Emoji = "❄️", Colors = { Color3.fromRGB(235, 245, 255) }, Shape = "Ball" },
	None = { Emoji = "🪙", Colors = { Color3.fromRGB(255, 205, 50) }, Shape = "Coin" },
}

local function pickupCoins(player: Player): number
	return math.max(ZONES.Park.MinCoins, math.floor(PlotService.IncomeOf(player) * ZONES.Park.IncomeSeconds))
end

-- Можно ли игроку взять пикап сейчас (лимиты против фарма); при true записывает взятие
local function allowPickup(state: PlayerState, player: Player): boolean
	local t = clock()
	if t - state.LastPickup < ZONES.Park.MinInterval then
		return false
	end
	local times = state.PickupTimes
	local window = ZONES.Park.WindowSeconds
	while #times > 0 and t - times[1] > window do
		table.remove(times, 1)
	end
	if #times >= ZONES.Park.WindowMax then
		notify(player, "ParkLimit", nil, "info", 30)
		return false
	end
	state.LastPickup = t
	table.insert(times, t)
	return true
end

local function randomParkPoint(random: Random): Vector3?
	local park = zones.Park
	for _ = 1, 10 do
		local x = park.Center.X + random:NextNumber(-park.Size.X / 2 + 6, park.Size.X / 2 - 6)
		local z = park.Center.Z + random:NextNumber(-park.Size.Y / 2 + 6, park.Size.Y / 2 - 6)
		local free = true
		for _, spot in park.TrampolineSpots do
			if Vector3.new(x - (park.Center.X + spot.X), 0, z - (park.Center.Z + spot.Z)).Magnitude < 8 then
				free = false
				break
			end
		end
		if free then
			return Vector3.new(x, park.Center.Y + 2.2, z)
		end
	end
	return nil
end

local function spawnPickup(random: Random)
	local position = randomParkPoint(random)
	if not position then
		return
	end
	local season = ReplicatedStorage:GetAttribute("Season")
	local look = PICKUP_LOOKS[if type(season) == "string" then season else "None"] or PICKUP_LOOKS.None

	local pickup = Instance.new("Part")
	pickup.Name = "Pickup"
	pickup.Anchored = true
	pickup.CanCollide = false
	pickup.CanQuery = false
	pickup.Material = Enum.Material.Neon
	pickup.Color = look.Colors[random:NextInteger(1, #look.Colors)]
	if look.Shape == "Coin" then
		pickup.Shape = Enum.PartType.Cylinder
		pickup.Size = Vector3.new(0.4, 2.2, 2.2)
		pickup.CFrame = CFrame.new(position) * CFrame.Angles(0, math.rad(random:NextNumber(0, 180)), 0)
	else
		pickup.Shape = Enum.PartType.Ball
		pickup.Size = Vector3.one * 1.8
		pickup.CFrame = CFrame.new(position)
	end
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(2.2, 2.2)
	gui.StudsOffset = Vector3.new(0, 1.8, 0)
	gui.MaxDistance = 70
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.TextScaled = true
	label.Text = look.Emoji
	label.Parent = gui
	gui.Parent = pickup

	local taken = false
	pickup.Touched:Connect(function(hit)
		if taken then
			return
		end
		local player = playerFromHit(hit)
		local state = player and stateOf(player)
		if not player or not state or not alive(player) or not DataService.IsLoaded(player) or not nearPart(player, pickup, 6) then
			return
		end
		if not allowPickup(state, player) then
			return
		end
		taken = true
		local where = pickup.Position
		pickup:Destroy()
		local coins = pickupCoins(player)
		PlotService.AddCoins(player, coins)
		BattlePassService.AddXp(player, ZONES.Park.Xp)
		Remotes.Fx:FireClient(player, "Pickup", { Position = where, Coins = coins, UserId = player.UserId })
	end)
	pickup.Destroying:Connect(function()
		pickupCount -= 1
	end)
	pickupCount += 1
	pickup.Parent = zones.Park.Pickups
	task.delay(ZONES.Park.PickupLifetime, function()
		if pickup.Parent then
			pickup:Destroy()
		end
	end)
end

-- ===== Секретная пещера =====

local function onChest(player: Player)
	local state = stateOf(player)
	if not state or not alive(player) or not DataService.IsLoaded(player) then
		return
	end
	if not nearPart(player, zones.Cave.Chest, ZONES.Cave.PromptDistance) then
		return
	end
	local data = DataService.GetTable(player, "Zones")
	local day = today()
	if data.Cave == day then
		notify(player, "SecretEmpty", nil, "info", 4)
		return
	end
	data.Cave = day
	local total = giveAll(player, { ZONES.Cave.Reward })
	if total.Meme then
		Remotes.Notify:FireClient(player, "SecretFound", { Meme = total.Meme }, "success")
	else
		Remotes.Notify:FireClient(player, "SecretFoundCoins", { Coins = total.Coins or 0 }, "success")
	end
	total.Zone = "Cave"
	Remotes.Popup:FireClient(player, "Zone", total)
end

-- ===== Подключение =====

local function onTouchedBy(partToWatch: BasePart, handler: (Player) -> ())
	partToWatch.Touched:Connect(function(hit)
		local player = playerFromHit(hit)
		if player then
			handler(player)
		end
	end)
end

-- Цикл с паузой и pcall: ошибка одного тика не останавливает зону навсегда
local function loop(name: string, interval: number, step: () -> ())
	task.spawn(function()
		while true do
			task.wait(interval)
			local ok, err = pcall(step)
			if not ok then
				warn("[ZoneService] " .. name .. ":", err)
			end
		end
	end)
end

function ZoneService.Start(builtZones: any)
	zones = builtZones
	if not zones or not zones.Tower then
		warn("[ZoneService] зоны не построены")
		return
	end

	for _, pad in zones.Pads do
		onTouchedBy(pad, function(player)
			onPad(player, pad)
		end)
	end
	for _, lava in zones.Tower.Lava do
		onTouchedBy(lava, onLava)
	end
	for _, entry in zones.Tower.Checkpoints do
		local index = entry.Part:GetAttribute("Checkpoint")
		onTouchedBy(entry.Part, function(player)
			onCheckpoint(player, index)
		end)
	end
	for _, prize in zones.Tower.Prizes do
		local tier = prize:GetAttribute("PrizeTier")
		onTouchedBy(prize, function(player)
			onPrize(player, tier)
		end)
	end
	for _, trampoline in zones.Park.Trampolines do
		onTouchedBy(trampoline, function(player)
			onTrampoline(player, trampoline)
		end)
	end
	zones.Cave.Prompt.Triggered:Connect(function(player)
		local ok, err = pcall(onChest, player)
		if not ok then
			warn("[ZoneService] chest:", err)
		end
	end)

	RunService.Heartbeat:Connect(function(dt)
		local ok, err = pcall(spinStep, dt)
		if not ok then
			warn("[ZoneService] spin:", err)
		end
	end)
	loop("tower", 0.1, function()
		vanishStep()
		spinnerHits()
	end)
	loop("safe zone", 0.25, safeZoneStep)

	local random = Random.new()
	loop("pickups", ZONES.Park.SpawnEvery, function()
		if pickupCount < ZONES.Park.MaxPickups then
			spawnPickup(random)
		end
	end)
end

function ZoneService.OnLoaded(player: Player)
	states[player] = {
		Checkpoint = 1,
		Reached = {},
		LastTeleport = -math.huge,
		LastLava = -math.huge,
		LastTrampoline = -math.huge,
		LastPrizeTouch = -math.huge,
		LastPickup = -math.huge,
		PickupTimes = {},
		Notified = {},
	}
end

function ZoneService.OnPlayerRemoving(player: Player)
	states[player] = nil
end

return ZoneService
