-- Предметы из Config.Items: оружие (тапок, бита, сковородка, бан-молот) и гаджеты
-- (энергетик, банановая кожура, шапка-невидимка). Покупка за монеты навсегда, выдача в рюкзак,
-- вся логика ударов и перезарядок — на сервере.
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Remotes = require(script.Parent.Remotes)
local StealService = require(script.Parent.StealService)
local Hooks = require(script.Parent.Hooks)

local ItemService = {}

-- Колбэк удара по монстру (выставляет init.server): (player, origin, range) -> boolean
ItemService.OnMonsterHit = nil :: ((player: Player, origin: Vector3, range: number) -> boolean)?

local cooldowns: { [Player]: { [string]: number } } = {} -- игрок -> предмет -> os.clock() конца перезарядки
local bananas: { [Player]: { BasePart } } = {}
local invisibleToken: { [Player]: number } = {}
local bananaFolder: Folder

local function now(): number
	return workspace:GetServerTimeNow()
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function aliveHumanoid(player: Player): Humanoid?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		return humanoid
	end
	return nil
end

-- ===== Владение =====

function ItemService.Owns(player: Player, id: string): boolean
	if id == "Slipper" then
		return true
	end
	local item = Config.GetItem(id)
	if item and item.Pass then
		return player:GetAttribute("Pass_" .. item.Pass) == true
	end
	return DataService.IsLoaded(player) and DataService.GetTable(player, "Items")[id] == true
end

local function syncItems(player: Player)
	local owned = {}
	for _, item in Config.Items do
		if ItemService.Owns(player, item.Id) then
			table.insert(owned, item.Id)
		end
	end
	player:SetAttribute("ItemsJson", HttpService:JSONEncode(owned))
end

-- Изменились геймпассы (куплен предмет за Robux, золотой тапок) — обновить список и рюкзак
function ItemService.RefreshPasses(player: Player)
	if DataService.IsLoaded(player) then
		syncItems(player)
		ItemService.GiveTools(player)
	end
end

-- ===== Внешний вид (детали из примитивов) =====

local function addPart(tool: Tool, handle: BasePart, props: { [string]: any }, offset: CFrame)
	local p = Instance.new("Part")
	p.CanCollide = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	p.CFrame = handle.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = p
	weld.Parent = p
	p.Parent = tool
end

local function buildTool(item: any, gold: boolean): Tool
	local tool = Instance.new("Tool")
	tool.Name = item.Id
	tool.ToolTip = item.Face .. " " .. item.Name
	tool.CanBeDropped = false
	tool:SetAttribute("ItemId", item.Id)
	tool:SetAttribute("CooldownEndsAt", 0)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.CanCollide = false
	handle.Massless = true
	handle.TopSurface = Enum.SurfaceType.Smooth
	handle.BottomSurface = Enum.SurfaceType.Smooth
	handle.Parent = tool

	local id = item.Id
	if id == "Slipper" then
		handle.Size = Vector3.new(1.2, 2.6, 0.35)
		handle.Color = if gold then Color3.fromRGB(255, 205, 50) else Color3.fromRGB(70, 90, 200)
		handle.Material = if gold then Enum.Material.Foil else Enum.Material.Fabric
		tool.Grip = CFrame.new(0, -0.9, 0) * CFrame.Angles(0, math.rad(90), 0)
		addPart(tool, handle, { Size = Vector3.new(1.25, 0.35, 0.5), Color = Color3.fromRGB(240, 240, 240) }, CFrame.new(0, 0.6, -0.3))
	elseif id == "Bat" then
		handle.Size = Vector3.new(0.5, 4.5, 0.5)
		handle.Color = Color3.fromRGB(170, 120, 70)
		handle.Material = Enum.Material.Wood
		tool.Grip = CFrame.new(0, -1.6, 0)
		addPart(tool, handle, { Size = Vector3.new(0.9, 1.8, 0.9), Color = Color3.fromRGB(150, 100, 60), Material = Enum.Material.Wood }, CFrame.new(0, 1.6, 0))
	elseif id == "Pan" then
		handle.Size = Vector3.new(0.35, 2.2, 0.35)
		handle.Color = Color3.fromRGB(40, 40, 45)
		tool.Grip = CFrame.new(0, -0.8, 0)
		addPart(tool, handle, {
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.3, 2.6, 2.6),
			Color = Color3.fromRGB(30, 30, 35),
			Material = Enum.Material.Metal,
		}, CFrame.new(0, 2.2, 0) * CFrame.Angles(0, math.rad(90), 0))
	elseif id == "BanHammer" then
		handle.Size = Vector3.new(0.5, 4.5, 0.5)
		handle.Color = Color3.fromRGB(60, 40, 30)
		handle.Material = Enum.Material.Wood
		tool.Grip = CFrame.new(0, -1.6, 0)
		addPart(tool, handle, { Size = Vector3.new(3.2, 1.8, 1.8), Color = Color3.fromRGB(230, 40, 50), Material = Enum.Material.Neon }, CFrame.new(0, 2.4, 0))
	elseif id == "Energy" then
		handle.Shape = Enum.PartType.Cylinder
		handle.Size = Vector3.new(1.4, 0.8, 0.8)
		handle.Color = Color3.fromRGB(70, 220, 90)
		handle.Material = Enum.Material.Metal
		tool.Grip = CFrame.Angles(0, 0, math.rad(90))
	elseif id == "Banana" then
		handle.Size = Vector3.new(0.6, 1.8, 0.4)
		handle.Color = Color3.fromRGB(255, 225, 60)
		tool.Grip = CFrame.new(0, -0.4, 0)
	elseif id == "RubberChicken" then
		handle.Size = Vector3.new(0.6, 2.8, 0.6)
		handle.Color = Color3.fromRGB(255, 230, 90)
		tool.Grip = CFrame.new(0, -1, 0)
		addPart(tool, handle, { Size = Vector3.new(0.5, 0.4, 0.7), Color = Color3.fromRGB(255, 140, 40) }, CFrame.new(0, 1.5, -0.4))
		addPart(tool, handle, { Size = Vector3.new(0.4, 0.5, 0.2), Color = Color3.fromRGB(230, 40, 40) }, CFrame.new(0, 1.7, 0))
	elseif id == "Snowball" or id == "ConfettiCannon" then
		local confetti = id == "ConfettiCannon"
		handle.Size = Vector3.new(0.8, 1.2, 0.8)
		handle.Color = if confetti then Color3.fromRGB(255, 90, 200) else Color3.fromRGB(120, 180, 230)
		tool.Grip = CFrame.new(0, -0.3, 0.6)
		addPart(tool, handle, {
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(3, 1, 1),
			Color = if confetti then Color3.fromRGB(255, 220, 60) else Color3.fromRGB(230, 245, 255),
			Material = if confetti then Enum.Material.Neon else Enum.Material.SmoothPlastic,
		}, CFrame.new(0, 0.5, -1.4) * CFrame.Angles(0, math.rad(90), 0))
	elseif id == "RocketBoots" then
		handle.Size = Vector3.new(1, 1, 1.6)
		handle.Color = Color3.fromRGB(200, 40, 40)
		addPart(tool, handle, { Size = Vector3.new(0.6, 0.6, 0.4), Color = Color3.fromRGB(255, 170, 40), Material = Enum.Material.Neon }, CFrame.new(0, 0, 0.9))
	elseif id == "FreezeBomb" then
		handle.Shape = Enum.PartType.Ball
		handle.Size = Vector3.one * 1.3
		handle.Color = Color3.fromRGB(140, 220, 255)
		handle.Material = Enum.Material.Ice
	elseif id == "InvisHat" then
		handle.Shape = Enum.PartType.Cylinder
		handle.Size = Vector3.new(1.4, 1.3, 1.3)
		handle.Color = Color3.fromRGB(25, 25, 30)
		tool.Grip = CFrame.Angles(0, 0, math.rad(90))
		addPart(tool, handle, {
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.15, 2.2, 2.2),
			Color = Color3.fromRGB(25, 25, 30),
		}, CFrame.new(-0.65, 0, 0))
		addPart(tool, handle, {
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.3, 1.35, 1.35),
			Color = Color3.fromRGB(150, 60, 255),
			Material = Enum.Material.Neon,
		}, CFrame.new(-0.3, 0, 0))
	end
	return tool
end

-- ===== Перезарядка =====

local function ready(player: Player, item: any, tool: Tool): boolean
	-- Срабатывает только предмет в руках своего персонажа
	if tool.Parent ~= player.Character then
		return false
	end
	local list = cooldowns[player]
	if not list then
		list = {}
		cooldowns[player] = list
	end
	local t = os.clock()
	if (list[item.Id] or 0) > t then
		return false
	end
	list[item.Id] = t + item.Cooldown
	tool:SetAttribute("CooldownEndsAt", now() + item.Cooldown)
	return true
end

-- ===== Невидимость =====

local function setInvisible(player: Player, invisible: boolean)
	local character = player.Character
	if not character then
		return
	end
	if (character:GetAttribute("Invisible") == true) == invisible then
		return
	end
	character:SetAttribute("Invisible", invisible)
	-- Рюкзак тоже: предмет, надетый во время невидимости, не должен выдавать игрока,
	-- а снятый — остаться прозрачным навсегда
	local descendants = character:GetDescendants()
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		for _, descendant in backpack:GetDescendants() do
			table.insert(descendants, descendant)
		end
	end
	for _, descendant in descendants do
		if descendant:IsA("BasePart") or descendant:IsA("Decal") then
			if invisible then
				if descendant:GetAttribute("OrigTransparency") == nil then
					descendant:SetAttribute("OrigTransparency", descendant.Transparency)
				end
				descendant.Transparency = 1
			else
				local original = descendant:GetAttribute("OrigTransparency")
				if original ~= nil then
					descendant.Transparency = original
					descendant:SetAttribute("OrigTransparency", nil)
				end
			end
		end
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = if invisible then Enum.HumanoidDisplayDistanceType.None else Enum.HumanoidDisplayDistanceType.Viewer
	end
	local root = rootOf(player)
	if root then
		Remotes.Fx:FireAllClients("Invisible", { Position = root.Position })
	end
end

-- Снять невидимость (начал кражу или ударил)
function ItemService.BreakInvisibility(player: Player)
	invisibleToken[player] = nil
	setInvisible(player, false)
end

-- ===== Оружие =====

local function swing(tool: Tool)
	local baseGrip = tool:GetAttribute("BaseGrip") or tool.Grip
	tool:SetAttribute("BaseGrip", baseGrip)
	tool.Grip = baseGrip * CFrame.Angles(math.rad(-80), 0, 0)
	task.delay(0.15, function()
		if tool.Parent then
			tool.Grip = baseGrip
		end
	end)
end

local function attack(player: Player, item: any, tool: Tool)
	local root = rootOf(player)
	if not root or not aliveHumanoid(player) or not ready(player, item, tool) then
		return
	end
	ItemService.BreakInvisibility(player)
	swing(tool)

	local gold = item.Id == "Slipper" and player:GetAttribute("Pass_GoldSlipper") == true
	local range = if gold then Config.Slap.GoldRange else item.Range
	local power = if gold then Config.Slap.GoldKnockback else item.Knockback
	local look = root.CFrame.LookVector

	local targets: { Player } = {}
	local best: Player? = nil
	local bestDistance = range
	for _, other in Players:GetPlayers() do
		if other == player or not aliveHumanoid(other) then
			continue
		end
		local otherRoot = rootOf(other)
		if not otherRoot then
			continue
		end
		local offset = otherRoot.Position - root.Position
		local distance = offset.Magnitude
		if item.Area then
			if distance <= range then
				table.insert(targets, other)
			end
		elseif distance <= bestDistance and (distance < 3 or offset.Unit:Dot(look) > 0.2) then
			best, bestDistance = other, distance
		end
	end
	if best then
		table.insert(targets, best)
	end

	for _, target in targets do
		local targetRoot = rootOf(target) :: BasePart
		StealService.Knock(target, root.Position, power, item.Stun)
		Remotes.Fx:FireAllClients("Slap", { Position = targetRoot.Position })
	end
	if #targets > 0 then
		Hooks.Fire(player, "Slap", #targets)
	end
	if (#targets == 0 or item.Area) and ItemService.OnMonsterHit then
		ItemService.OnMonsterHit(player, root.Position, range + 4)
	end
end

-- ===== Гаджеты =====

local function useEnergy(player: Player, item: any, tool: Tool)
	local character = player.Character
	local root = rootOf(player)
	if not character or not root or not aliveHumanoid(player) or not ready(player, item, tool) then
		return
	end
	character:SetAttribute("BoostUntil", now() + item.Duration)
	character:SetAttribute("BoostSpeed", item.Speed)
	StealService.UpdateSpeed(player)
	Remotes.Fx:FireAllClients("Energy", { Position = root.Position })
	task.delay(item.Duration + 0.05, function()
		if player.Parent and player.Character == character then
			StealService.UpdateSpeed(player)
		end
	end)
end

local function placeBanana(player: Player, item: any, tool: Tool)
	local root = rootOf(player)
	if not root or not aliveHumanoid(player) or not ready(player, item, tool) then
		return
	end
	-- Кладём под ноги чуть позади: ловушка для того, кто бежит следом
	local origin = root.Position - root.CFrame.LookVector * 3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: Model, bananaFolder }
	local hit = workspace:Raycast(origin, Vector3.new(0, -12, 0), params)
	local groundY = if hit then hit.Position.Y else root.Position.Y - 3

	local banana = Instance.new("Part")
	banana.Name = "Banana"
	banana.Size = Vector3.new(2, 0.3, 1.2)
	banana.Color = Color3.fromRGB(255, 225, 60)
	banana.Material = Enum.Material.SmoothPlastic
	banana.Anchored = true
	banana.CanCollide = false
	banana.CFrame = CFrame.new(origin.X, groundY + 0.15, origin.Z) * CFrame.Angles(0, math.rad(math.random(0, 360)), 0)
	banana:SetAttribute("OwnerUserId", player.UserId)
	CollectionService:AddTag(banana, "Banana")

	local list = bananas[player] or {}
	bananas[player] = list
	table.insert(list, banana)
	while #list > item.MaxActive do
		local old = table.remove(list, 1)
		if old then
			old:Destroy()
		end
	end

	local used = false
	banana.Touched:Connect(function(other)
		if used then
			return
		end
		local victim = Players:GetPlayerFromCharacter(other.Parent)
		if not victim or victim == player or not aliveHumanoid(victim) then
			return
		end
		used = true
		local position = banana.Position
		banana:Destroy()
		local current = bananas[player]
		local index = current and table.find(current, banana)
		if current and index then
			table.remove(current, index)
		end
		StealService.Knock(victim, position - Vector3.new(0, 1, 0), 25, item.Stun)
		Remotes.Fx:FireAllClients("Banana", { Position = position })
	end)
	banana.Parent = bananaFolder

	task.delay(item.Duration, function()
		if banana.Parent then
			banana:Destroy()
		end
		local current = bananas[player]
		if current then
			local index = table.find(current, banana)
			if index then
				table.remove(current, index)
			end
		end
	end)
end

local function useInvisHat(player: Player, item: any, tool: Tool)
	if not aliveHumanoid(player) or StealService.IsCarrying(player) or not ready(player, item, tool) then
		return
	end
	local token = (invisibleToken[player] or 0) + 1
	invisibleToken[player] = token
	setInvisible(player, true)
	task.delay(item.Duration, function()
		if invisibleToken[player] == token then
			invisibleToken[player] = nil
			setInvisible(player, false)
		end
	end)
end

-- Дальний бой: первый враг в узком конусе перед персонажем, если его не закрывает стена
local function shoot(player: Player, item: any, tool: Tool)
	local root = rootOf(player)
	if not root or not aliveHumanoid(player) or not ready(player, item, tool) then
		return
	end
	ItemService.BreakInvisibility(player)
	local look = root.CFrame.LookVector
	local origin = root.Position + Vector3.new(0, 1.5, 0)

	local best: Player? = nil
	local bestDistance = item.Range
	for _, other in Players:GetPlayers() do
		if other == player or not aliveHumanoid(other) then
			continue
		end
		local otherRoot = rootOf(other)
		if not otherRoot then
			continue
		end
		local offset = otherRoot.Position - root.Position
		local distance = offset.Magnitude
		if distance <= bestDistance and distance > 0.1 and offset.Unit:Dot(look) > 0.93 then
			best, bestDistance = other, distance
		end
	end

	local hitPosition = origin + look * item.Range
	if best then
		local targetRoot = rootOf(best) :: BasePart
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		local ignore: { Instance } = { player.Character :: Model, best.Character :: Model, bananaFolder }
		local carpet = workspace:FindFirstChild("CarpetMemes")
		if carpet then
			table.insert(ignore, carpet)
		end
		params.FilterDescendantsInstances = ignore
		local blocked = workspace:Raycast(origin, targetRoot.Position - origin, params)
		if blocked and blocked.Instance.CanCollide then
			hitPosition = blocked.Position
		else
			hitPosition = targetRoot.Position
			StealService.Knock(best, root.Position, item.Knockback, item.Stun)
			Hooks.Fire(player, "Slap", 1)
		end
	end
	Remotes.Fx:FireAllClients("Shot", { From = origin, To = hitPosition, Item = item.Id })
	if not best and ItemService.OnMonsterHit then
		-- По монстру дальнобой бьёт, если тот стоит в пределах дальности перед игроком
		ItemService.OnMonsterHit(player, root.Position + look * math.min(item.Range, 30), 18)
	end
end

local function useRocket(player: Player, item: any, tool: Tool)
	local root = rootOf(player)
	if not root or not aliveHumanoid(player) or not ready(player, item, tool) then
		return
	end
	local look = root.CFrame.LookVector
	-- Толчок делает клиент владельца (персонажем управляет он), stun = 0 — без падения
	Remotes.Knockback:FireClient(player, Vector3.new(look.X, 0, look.Z) * item.Forward + Vector3.new(0, item.Jump, 0), 0)
	Remotes.Fx:FireAllClients("Rocket", { Position = root.Position })
end

local function useFreeze(player: Player, item: any, tool: Tool)
	local root = rootOf(player)
	if not root or not aliveHumanoid(player) or not ready(player, item, tool) then
		return
	end
	ItemService.BreakInvisibility(player)
	local hits = 0
	for _, other in Players:GetPlayers() do
		local otherRoot = rootOf(other)
		if other ~= player and otherRoot and aliveHumanoid(other) and (otherRoot.Position - root.Position).Magnitude <= item.Range then
			StealService.Knock(other, root.Position, 8, item.Stun)
			hits += 1
		end
	end
	if hits > 0 then
		Hooks.Fire(player, "Slap", hits)
	end
	Remotes.Fx:FireAllClients("Freeze", { Position = root.Position, Radius = item.Range })
end

local USE = {
	Energy = useEnergy,
	Banana = placeBanana,
	InvisHat = useInvisHat,
	RocketBoots = useRocket,
	FreezeBomb = useFreeze,
}

-- ===== Выдача =====

function ItemService.GiveTools(player: Player)
	local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 5)
	if not backpack then
		return
	end
	for _, container in { backpack, player.Character } do
		if container then
			for _, child in container:GetChildren() do
				if child:IsA("Tool") and child:GetAttribute("ItemId") then
					child:Destroy()
				end
			end
		end
	end
	local gold = player:GetAttribute("Pass_GoldSlipper") == true
	for _, item in Config.Items do
		if not ItemService.Owns(player, item.Id) then
			continue
		end
		local tool = buildTool(item, gold)
		-- Перезарядка переживает респавн
		local endsAt = cooldowns[player] and cooldowns[player][item.Id]
		if endsAt and endsAt > os.clock() then
			tool:SetAttribute("CooldownEndsAt", now() + (endsAt - os.clock()))
		end
		tool.Activated:Connect(function()
			if item.Kind == "Weapon" and item.Ranged then
				shoot(player, item, tool)
			elseif item.Kind == "Weapon" then
				attack(player, item, tool)
			else
				local use = USE[item.Id]
				if use then
					use(player, item, tool)
				end
			end
		end)
		tool.Parent = backpack
	end
end

function ItemService.Buy(player: Player, id: unknown): (boolean, string)
	if type(id) ~= "string" or not DataService.IsLoaded(player) then
		return false, "NotLoaded"
	end
	local item = Config.GetItem(id)
	if not item then
		return false, "NotLoaded"
	end
	if ItemService.Owns(player, id) then
		return false, "ItemOwned"
	end
	if item.Pass then
		return false, "PassOnly" -- такие предметы продаются только за Robux (геймпасс)
	end
	if DataService.Get(player, "Coins") < item.Price then
		Remotes.Notify:FireClient(player, "NotEnoughCash", { Price = item.Price }, "error")
		return false, "NotEnoughCash"
	end
	DataService.Increment(player, "Coins", -item.Price)
	DataService.GetTable(player, "Items")[id] = true
	syncItems(player)
	ItemService.GiveTools(player)
	Remotes.Notify:FireClient(player, "ItemBought", { Item = id }, "success")
	return true, "ItemBought"
end

function ItemService.OnLoaded(player: Player)
	syncItems(player)
end

function ItemService.OnCharacter(player: Player, character: Model)
	invisibleToken[player] = nil
	character:SetAttribute("Invisible", false)
	ItemService.GiveTools(player)
end

function ItemService.OnPlayerRemoving(player: Player)
	for _, banana in bananas[player] or {} do
		banana:Destroy()
	end
	bananas[player] = nil
	cooldowns[player] = nil
	invisibleToken[player] = nil
end

function ItemService.Start()
	bananaFolder = Instance.new("Folder")
	bananaFolder.Name = "Bananas"
	bananaFolder.Parent = workspace

	StealService.OnStealStarted = ItemService.BreakInvisibility
	Remotes.BuyItem.OnServerInvoke = ItemService.Buy
end

return ItemService
