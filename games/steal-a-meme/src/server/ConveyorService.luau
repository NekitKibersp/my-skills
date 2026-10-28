-- «Красная дорожка»: мемы появляются из портала, идут по дорожке, их можно купить.
-- Редкость и мутация выбираются на сервере; Удача сервера и Ночь Смайлика меняют шансы.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local MemeFactory = require(script.Parent.MemeFactory)
local PlotService = require(script.Parent.PlotService)
local Remotes = require(script.Parent.Remotes)
local Hooks = require(script.Parent.Hooks)
local AnalyticsService = require(script.Parent.AnalyticsService)

local ConveyorService = {}

local carpetStart: Vector3
local carpetEnd: Vector3
local folder: Folder
local walking: { [Model]: number } = {} -- модель -> пройденное расстояние
local random = Random.new()

local LUCKY_RARITIES = { Legendary = true, Mythic = true, God = true, Secret = true }

local function weightedPick<T>(items: { T }, weightOf: (T) -> number): T
	local total = 0
	for _, item in items do
		total += weightOf(item)
	end
	local roll = random:NextNumber() * total
	for _, item in items do
		roll -= weightOf(item)
		if roll <= 0 then
			return item
		end
	end
	return items[#items]
end

local function isLucky(): boolean
	return (ReplicatedStorage:GetAttribute("LuckEndsAt") or 0) > workspace:GetServerTimeNow()
end

local function rollCreature(): string
	local night = ReplicatedStorage:GetAttribute("NightActive") == true
	local season = ReplicatedStorage:GetAttribute("Season")
	local seasonal = {}
	for _, creature in Config.Creatures do
		if creature.Event and creature.Season == season then
			table.insert(seasonal, creature)
		end
	end
	if night and #seasonal > 0 and random:NextNumber() < Config.Conveyor.EventChance then
		return weightedPick(seasonal, function(creature)
			return creature.EventWeight or 1
		end).Id
	end

	-- Лимитированный мем недели (WeeklyService) — редкий гость на дорожке
	local weekly = ReplicatedStorage:GetAttribute("WeeklyMeme")
	if type(weekly) == "string" and Config.GetCreature(weekly) and random:NextNumber() < Config.Weekly.Chance then
		return weekly
	end

	-- Удача: покупка «Удача сервера» и множитель админ-ивента складываются
	local luck = (if isLucky() then Config.Conveyor.LuckMult else 1) * (ReplicatedStorage:GetAttribute("EventLuckMult") or 1)
	local rarity = weightedPick(Config.Rarities, function(r)
		return r.Weight * (if LUCKY_RARITIES[r.Id] then luck else 1)
	end)
	local pool = {}
	for _, creature in Config.Creatures do
		if creature.Rarity == rarity.Id and not creature.Event and not creature.Limited and not creature.Exclusive then
			table.insert(pool, creature)
		end
	end
	if #pool == 0 then
		return Config.Creatures[1].Id
	end
	return pool[random:NextInteger(1, #pool)].Id
end

local function rollMutation(): string
	local night = ReplicatedStorage:GetAttribute("NightActive") == true
	local season = ReplicatedStorage:GetAttribute("Season")
	local pool = {}
	for _, mutation in Config.Mutations do
		if not mutation.Event or (night and mutation.Season == season) then
			table.insert(pool, mutation)
		end
	end
	-- Шторм мутаций (админ-ивент): с этим шансом мутация гарантирована
	local forceMutation = random:NextNumber() < (ReplicatedStorage:GetAttribute("EventMutationChance") or 0)
	return weightedPick(pool, function(m)
		if forceMutation and m.Id == "None" then
			return 0
		end
		return m.Weight
	end).Id
end

local function carpetCFrame(distance: number, model: Model): CFrame
	local direction = (carpetEnd - carpetStart).Unit
	local position = carpetStart + direction * distance
	-- Лёгкое покачивание «шаг-шаг»
	local bob = math.abs(math.sin(distance * 0.9)) * 0.5
	return CFrame.lookAt(position, position + direction) * CFrame.new(0, MemeFactory.BodyOffset(model) + bob, 0)
end

local function tryBuy(player: Player, model: Model)
	if not DataService.IsLoaded(player) or not walking[model] or model:GetAttribute("State") ~= "Carpet" then
		Remotes.Notify:FireClient(player, "AlreadyTaken", nil, "error")
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or (root.Position - model:GetPivot().Position).Magnitude > 20 then
		return
	end
	local id = model:GetAttribute("CreatureId")
	local mutationId = model:GetAttribute("Mutation")
	local price = model:GetAttribute("Price")
	if DataService.Get(player, "Coins") < price then
		Remotes.Notify:FireClient(player, "NotEnoughCash", { Price = price }, "error")
		return
	end
	if not PlotService.FreeSlot(player) then
		Remotes.Notify:FireClient(player, "BaseFull", nil, "error")
		return
	end

	-- Сначала забираем мема с дорожки, потом списываем деньги и выдаём
	walking[model] = nil
	model:SetAttribute("State", "Walking")
	local from = model:GetPivot()
	model:Destroy()

	DataService.Increment(player, "Coins", -price)
	AnalyticsService.Economy(player, "Sink", price, "Shop", id)
	PlotService.AddMeme(player, id, mutationId, false, from)
	Remotes.Fx:FireAllClients("Bought", { Position = from.Position, Rarity = Config.GetCreature(id).Rarity })
	Remotes.Notify:FireClient(player, "Bought", { Meme = id }, "success")
	Hooks.Fire(player, "Buy", 1)
end

function ConveyorService.Spawn(forcedId: string?, forcedMutation: string?): Model?
	local count = 0
	for _ in walking do
		count += 1
	end
	local cap = Config.Conveyor.MaxOnCarpet * math.min(ReplicatedStorage:GetAttribute("EventSpawnMult") or 1, 2)
	if count >= cap and not forcedId then
		return nil
	end

	local id = forcedId or rollCreature()
	local mutationId = forcedMutation or rollMutation()
	local model = MemeFactory.Create(id, mutationId, false, CFrame.new(carpetStart))
	model:SetAttribute("State", "Carpet")
	model:SetAttribute("Price", Config.PriceOf(id, mutationId))
	model:PivotTo(carpetCFrame(0, model))

	local prompt = MemeFactory.AddPrompt(model, "BuyPrompt", "Buy", 0)
	prompt.MaxActivationDistance = 14
	prompt.Triggered:Connect(function(player)
		tryBuy(player, model)
	end)

	walking[model] = 0
	model.Parent = folder
	return model
end

-- Призыв Мем-Бога (покупка за Robux): случайный мем редкости God на дорожке
-- Случайный мем нужной редкости на дорожку (Секретный дроп админ-ивента и т.п.)
function ConveyorService.SpawnRarity(rarityId: string)
	local pool = {}
	for _, creature in Config.Creatures do
		if creature.Rarity == rarityId and not creature.Event then
			table.insert(pool, creature.Id)
		end
	end
	if #pool > 0 then
		ConveyorService.Spawn(pool[random:NextInteger(1, #pool)])
	end
end

function ConveyorService.SummonGod()
	local gods = {}
	for _, creature in Config.Creatures do
		if creature.Rarity == "God" then
			table.insert(gods, creature.Id)
		end
	end
	if #gods > 0 then
		ConveyorService.Spawn(gods[random:NextInteger(1, #gods)])
	end
end

function ConveyorService.Start(startPosition: Vector3, endPosition: Vector3)
	carpetStart = startPosition
	carpetEnd = endPosition
	folder = Instance.new("Folder")
	folder.Name = "CarpetMemes"
	folder.Parent = workspace

	local length = (carpetEnd - carpetStart).Magnitude

	RunService.Heartbeat:Connect(function(dt)
		for model, distance in walking do
			if not model.Parent then
				walking[model] = nil
				continue
			end
			distance += Config.Conveyor.Speed * dt
			if distance >= length then
				walking[model] = nil
				model:Destroy()
				continue
			end
			walking[model] = distance
			model:PivotTo(carpetCFrame(distance, model))
		end
	end)

	task.spawn(function()
		while true do
			ConveyorService.Spawn()
			-- Мем-дождь (админ-ивент) ускоряет появление
			task.wait(Config.Conveyor.SpawnInterval / math.max(ReplicatedStorage:GetAttribute("EventSpawnMult") or 1, 0.1))
		end
	end)
end

return ConveyorService
