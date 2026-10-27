-- Серверные ивенты: «В ТРЕНДЕ» (один вид мема даёт ×3) и Ночь Смайлика — темнеет, по карте
-- ходит жёлтый смайлик-монстр и утаскивает мемов с открытых баз; игроки отбиваются тапками.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local MemeFactory = require(script.Parent.MemeFactory)
local PlotService = require(script.Parent.PlotService)
local Remotes = require(script.Parent.Remotes)

local EventService = {}

local random = Random.new()
local mapHalfX = 230
local mapHalfZ = 130

local function now(): number
	return workspace:GetServerTimeNow()
end

-- ===== В ТРЕНДЕ =====

local function pickTrend(): string
	local present = {}
	for _, player in Players:GetPlayers() do
		if PlotService.GetPlot(player) then
			local ok, entries = pcall(PlotService.GetEntries, player)
			if ok then
				for _, entry in entries do
					if not table.find(present, entry.Id) then
						table.insert(present, entry.Id)
					end
				end
			end
		end
	end
	-- Чаще выбираем то, что уже есть на базах — тогда начинается охота за этим мемом
	if #present > 0 and random:NextNumber() < 0.75 then
		return present[random:NextInteger(1, #present)]
	end
	local pool = {}
	for _, creature in Config.Creatures do
		if creature.Rarity == "Common" or creature.Rarity == "Rare" or creature.Rarity == "Epic" then
			table.insert(pool, creature.Id)
		end
	end
	return pool[random:NextInteger(1, #pool)]
end

local function startTrend()
	local previous = ReplicatedStorage:GetAttribute("TrendingId")
	local id = pickTrend()
	for _ = 1, 5 do
		if id ~= previous then
			break
		end
		id = pickTrend()
	end
	ReplicatedStorage:SetAttribute("TrendingId", id)
	ReplicatedStorage:SetAttribute("TrendEndsAt", now() + Config.Trend.Interval)
	PlotService.RefreshAllIncome()
	Remotes.Notify:FireAllClients("TrendNow", { Meme = id, Mult = Config.Trend.Mult }, "info")
end

-- ===== Смайлик =====

type MonsterState = {
	Model: Model,
	Hp: number,
	Damage: { [Player]: number },
	Carry: { Owner: Player, Slot: number, Model: Model, Id: string }?,
	Defeated: boolean,
}
local monster: MonsterState? = nil

local function buildMonster(position: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "Smiley"
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(8, 8, 8)
	body.Color = Color3.fromRGB(255, 220, 30)
	body.Material = Enum.Material.SmoothPlastic
	body.Anchored = true
	body.CanCollide = false
	body.CFrame = CFrame.new(position + Vector3.new(0, 4.5, 0))
	body.Parent = model
	model.PrimaryPart = body

	local gui = Instance.new("SurfaceGui")
	gui.Name = "FaceGui"
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.CanvasSize = Vector2.new(200, 200)
	gui.Parent = body
	local face = Instance.new("TextLabel")
	face.Name = "Face"
	face.Size = UDim2.fromScale(1, 1)
	face.BackgroundTransparency = 1
	face.TextScaled = true
	face.Font = Enum.Font.GothamBlack
	face.TextColor3 = Color3.fromRGB(20, 20, 20)
	face.Text = ":)"
	face.Parent = gui

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 230, 80)
	light.Range = 30
	light.Brightness = 2
	light.Parent = body

	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	game:GetService("CollectionService"):AddTag(model, "Monster")
	model.Parent = workspace
	return model
end

local function setFace(state: MonsterState, text: string)
	local gui = (state.Model.PrimaryPart :: BasePart):FindFirstChild("FaceGui")
	if gui then
		(gui:FindFirstChild("Face") :: TextLabel).Text = text
	end
end

local function returnCarried(state: MonsterState)
	local carry = state.Carry
	if not carry then
		return
	end
	state.Carry = nil
	state.Model:SetAttribute("Carrying", "")
	setFace(state, ":)")
	if carry.Owner.Parent and PlotService.GetPlot(carry.Owner) and DataService.IsLoaded(carry.Owner)
		and PlotService.GetEntry(carry.Owner, carry.Slot) then
		PlotService.ReturnModel(carry.Owner, carry.Slot, carry.Model)
		PlotService.SetAway(carry.Owner, carry.Slot, false)
		Remotes.Notify:FireClient(carry.Owner, "MemeReturned", { Meme = carry.Id }, "success")
	else
		carry.Model:Destroy()
	end
end

local function despawnMonster()
	local state = monster
	if not state then
		return
	end
	monster = nil
	returnCarried(state)
	state.Model:Destroy()
end

local function rewardBest(state: MonsterState)
	local best: Player? = nil
	local bestDamage = 0
	for player, damage in state.Damage do
		-- Награду кладём в данные игрока — без загруженных данных (или базы) выдать её нельзя
		if player.Parent and DataService.IsLoaded(player) and damage > bestDamage then
			best, bestDamage = player, damage
		end
	end
	if not best then
		return
	end
	Remotes.Notify:FireAllClients("MonsterDefeated", { Player = best.DisplayName }, "success")

	local night = Config.Night
	local total = 0
	for _, weight in night.RewardWeights do
		total += weight
	end
	local roll = random:NextNumber() * total
	local rarity = night.RewardRarities[1]
	for i, weight in night.RewardWeights do
		roll -= weight
		if roll <= 0 then
			rarity = night.RewardRarities[i]
			break
		end
	end
	local pool = {}
	for _, creature in Config.Creatures do
		if creature.Rarity == rarity and not creature.Event then
			table.insert(pool, creature.Id)
		end
	end
	if #pool == 0 then
		return
	end
	local id = pool[random:NextInteger(1, #pool)]
	if PlotService.AddMeme(best, id, "None", false) then
		Remotes.Notify:FireClient(best, "NightReward", { Meme = id }, "success")
	else
		local coins = math.floor(Config.PriceOf(id, "None") * 0.5)
		PlotService.AddCoins(best, coins)
		Remotes.Notify:FireClient(best, "NightRewardCoins", { Coins = coins }, "success")
	end
end

-- Удар тапком по Смайлику. Возвращает true, если попал.
function EventService.HitMonster(player: Player, origin: Vector3, range: number): boolean
	local state = monster
	if not state or state.Defeated then
		return false
	end
	local position = state.Model:GetPivot().Position
	if (position - origin).Magnitude > range + 4 then
		return false
	end
	state.Hp -= 1
	state.Damage[player] = (state.Damage[player] or 0) + 1
	state.Model:SetAttribute("Hp", state.Hp)
	Remotes.Fx:FireAllClients("MonsterHit", { Position = position })
	if state.Hp <= 0 then
		state.Defeated = true
		rewardBest(state)
		despawnMonster()
	end
	return true
end

-- Монстр шагает к точке. Возвращает false, если по дороге его победили/убрали.
local function walkTo(state: MonsterState, target: Vector3, shouldAbort: (() -> boolean)?): boolean
	while monster == state and not state.Defeated do
		local pivot = state.Model:GetPivot()
		local flatTarget = Vector3.new(target.X, pivot.Position.Y, target.Z)
		local offset = flatTarget - pivot.Position
		if offset.Magnitude < 1.5 then
			return true
		end
		if shouldAbort and shouldAbort() then
			return false
		end
		local dt = RunService.Heartbeat:Wait()
		local step = math.min(Config.Night.MonsterSpeed * dt, offset.Magnitude)
		local nextPosition = pivot.Position + offset.Unit * step
		state.Model:PivotTo(CFrame.lookAt(nextPosition, nextPosition + offset.Unit))
	end
	return false
end

local function pickTarget(): (Player?, number?)
	local candidates = {}
	for _, player in Players:GetPlayers() do
		local plot = PlotService.GetPlot(player)
		if plot and not PlotService.IsLocked(plot) then
			local ok, entries = pcall(PlotService.GetEntries, player)
			if ok then
				for _, entry in entries do
					if PlotService.GetModel(player, entry.Slot) then
						table.insert(candidates, { player, entry.Slot })
					end
				end
			end
		end
	end
	if #candidates == 0 then
		return nil, nil
	end
	local pick = candidates[random:NextInteger(1, #candidates)]
	return pick[1], pick[2]
end

local function nearestEdge(position: Vector3): Vector3
	local options = {
		Vector3.new(mapHalfX - 4, position.Y, position.Z),
		Vector3.new(-mapHalfX + 4, position.Y, position.Z),
		Vector3.new(position.X, position.Y, mapHalfZ - 4),
		Vector3.new(position.X, position.Y, -mapHalfZ + 4),
	}
	local best, bestDistance = options[1], math.huge
	for _, option in options do
		local distance = (option - position).Magnitude
		if distance < bestDistance then
			best, bestDistance = option, distance
		end
	end
	return best
end

local function monsterBrain(state: MonsterState)
	while monster == state and not state.Defeated do
		task.wait() -- страховка: ни одна ветка ниже не должна крутить цикл без паузы
		if monster ~= state or state.Defeated then
			break
		end
		local owner, slot = pickTarget()
		if not owner or not slot then
			-- Все базы закрыты — бродим по дорожке
			local wander = Vector3.new(random:NextNumber(-150, 150), 0, random:NextNumber(-10, 10))
			walkTo(state, wander)
			task.wait(1)
			continue
		end
		local plot = PlotService.GetPlot(owner) :: Model
		local function abort(): boolean
			return not owner.Parent or PlotService.GetPlot(owner) ~= plot or PlotService.IsLocked(plot)
				or PlotService.GetModel(owner, slot) == nil
		end
		if not walkTo(state, PlotService.OutsidePoint(plot).Position, abort) then
			continue
		end
		local target = PlotService.GetModel(owner, slot)
		if not target or not walkTo(state, target:GetPivot().Position, abort) then
			continue
		end
		-- Пауза «ворую...» — шанс отбить мема тапками
		setFace(state, ">:)")
		local deadline = os.clock() + Config.Night.MonsterStealPause
		while os.clock() < deadline and monster == state and not abort() do
			task.wait(0.1)
		end
		if monster ~= state or abort() then
			setFace(state, ":)")
			continue
		end

		local model = PlotService.DetachModel(owner, slot) :: Model
		PlotService.SetAway(owner, slot, true)
		for _, child in (model.PrimaryPart :: BasePart):GetChildren() do
			if child:IsA("ProximityPrompt") then
				child:Destroy()
			end
		end
		model:SetAttribute("State", "Carried")
		local body = state.Model.PrimaryPart :: BasePart
		MemeFactory.AttachTo(model, body, CFrame.new(0, body.Size.Y / 2 + (model.PrimaryPart :: BasePart).Size.Y / 2 + 1, 0))
		model.Parent = workspace
		local id = model:GetAttribute("CreatureId")
		state.Carry = { Owner = owner, Slot = slot, Model = model, Id = id }
		state.Model:SetAttribute("Carrying", id)
		Remotes.Notify:FireAllClients("MonsterStole", { Meme = id, Player = owner.DisplayName }, "error")

		local escaped = walkTo(state, nearestEdge(state.Model:GetPivot().Position))
		if escaped and monster == state and state.Carry then
			local carry = state.Carry :: { Owner: Player, Slot: number, Model: Model, Id: string }
			state.Carry = nil
			state.Model:SetAttribute("Carrying", "")
			carry.Model:Destroy()
			if carry.Owner.Parent and PlotService.GetPlot(carry.Owner) and DataService.IsLoaded(carry.Owner) then
				PlotService.RemoveEntry(carry.Owner, carry.Slot)
				Remotes.Notify:FireClient(carry.Owner, "MonsterEscaped", { Meme = carry.Id }, "error")
			end
			setFace(state, ":)")
		end
	end
end

local function spawnMonster()
	despawnMonster()
	local playerCount = math.max(#Players:GetPlayers(), 1)
	local hp = Config.Night.MonsterHpPerPlayer * playerCount
	local model = buildMonster(Vector3.new(-200, 0.5, 0))
	model:SetAttribute("Hp", hp)
	model:SetAttribute("MaxHp", hp)
	model:SetAttribute("Carrying", "")
	local state: MonsterState = { Model = model, Hp = hp, Damage = {}, Carry = nil, Defeated = false }
	monster = state
	task.spawn(monsterBrain, state)
end

-- Хозяин выходит — Смайлик бросает его мема (мем остаётся в сохранении хозяина)
function EventService.OnPlayerRemoving(player: Player)
	local state = monster
	if state and state.Carry and state.Carry.Owner == player then
		state.Carry.Model:Destroy()
		state.Carry = nil
		state.Model:SetAttribute("Carrying", "")
		setFace(state, ":)")
	end
	if state then
		state.Damage[player] = nil
	end
end

-- ===== Ночь =====

local savedLighting: { [string]: any } = {}

local function setNight(active: boolean)
	ReplicatedStorage:SetAttribute("NightActive", active)
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if active then
		savedLighting = {
			ClockTime = Lighting.ClockTime,
			Brightness = Lighting.Brightness,
			Ambient = Lighting.Ambient,
			OutdoorAmbient = Lighting.OutdoorAmbient,
			AtmosphereColor = atmosphere and atmosphere.Color,
			AtmosphereDensity = atmosphere and atmosphere.Density,
		}
		Lighting.ClockTime = 0
		Lighting.Brightness = 1
		Lighting.Ambient = Color3.fromRGB(60, 30, 80)
		Lighting.OutdoorAmbient = Color3.fromRGB(70, 40, 100)
		if atmosphere then
			atmosphere.Color = Color3.fromRGB(120, 60, 160)
			atmosphere.Density = 0.45
		end
	elseif savedLighting.ClockTime then
		Lighting.ClockTime = savedLighting.ClockTime
		Lighting.Brightness = savedLighting.Brightness
		Lighting.Ambient = savedLighting.Ambient
		Lighting.OutdoorAmbient = savedLighting.OutdoorAmbient
		if atmosphere and savedLighting.AtmosphereColor then
			atmosphere.Color = savedLighting.AtmosphereColor
			atmosphere.Density = savedLighting.AtmosphereDensity
		end
	end
end

function EventService.Start(halfX: number, halfZ: number)
	mapHalfX, mapHalfZ = halfX, halfZ
	ReplicatedStorage:SetAttribute("TrendingId", "")
	ReplicatedStorage:SetAttribute("TrendEndsAt", 0)
	ReplicatedStorage:SetAttribute("NightActive", false)
	ReplicatedStorage:SetAttribute("NightEndsAt", 0)
	ReplicatedStorage:SetAttribute("LuckEndsAt", 0)

	task.spawn(function()
		task.wait(20)
		while true do
			startTrend()
			task.wait(Config.Trend.Interval)
		end
	end)

	task.spawn(function()
		while true do
			ReplicatedStorage:SetAttribute("NextNightAt", now() + Config.Night.Interval)
			task.wait(Config.Night.Interval)
			ReplicatedStorage:SetAttribute("NightEndsAt", now() + Config.Night.Duration)
			setNight(true)
			Remotes.Notify:FireAllClients("NightStart", nil, "info")
			spawnMonster()
			task.wait(Config.Night.Duration)
			despawnMonster()
			setNight(false)
			Remotes.Notify:FireAllClients("NightEnd", nil, "info")
		end
	end)
end

return EventService
