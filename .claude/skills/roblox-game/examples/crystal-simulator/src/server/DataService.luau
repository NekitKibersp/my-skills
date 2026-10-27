-- Хранит прогресс игроков, сохраняет его в DataStore и дублирует в атрибуты игрока,
-- чтобы клиентский интерфейс видел актуальные значения без лишних RemoteEvent'ов.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(script.Parent.Remotes)

local DataService = {}

local STORE_NAME = "CrystalSimulator_v1"
local AUTOSAVE_INTERVAL = 120

local DEFAULT_DATA = {
	Coins = 0,
	Ore = 0,
	TotalOre = 0,
	Rebirths = 0,
	ToolTier = 1,
	BackpackTier = 1,
	MaxZone = 1,
}

local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[DataService] DataStore недоступен:", result)
	end
end

type Profile = { Data: { [string]: number }, CanSave: boolean }
local profiles: { [Player]: Profile } = {}

local changedEvent = Instance.new("BindableEvent")
DataService.Changed = changedEvent.Event -- (player, key, value)

local function keyFor(player: Player): string
	return "player_" .. player.UserId
end

local function withRetries(callback: () -> any): (boolean, any)
	local lastError
	for attempt = 1, 3 do
		local ok, result = pcall(callback)
		if ok then
			return true, result
		end
		lastError = result
		if attempt < 3 then
			task.wait(attempt * 2)
		end
	end
	return false, lastError
end

local function syncAttribute(player: Player, key: string, value: number)
	player:SetAttribute(key, value)

	if key == "BackpackTier" then
		player:SetAttribute("Capacity", Config.Backpacks[value].Capacity)
	elseif key == "Rebirths" then
		player:SetAttribute("Multiplier", Config.Multiplier(value))
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		if key == "Coins" then
			leaderstats["Монеты"].Value = value
		elseif key == "Rebirths" then
			leaderstats["Перерождения"].Value = value
		end
	end
end

local function createLeaderstats(player: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local coins = Instance.new("IntValue")
	coins.Name = "Монеты"
	coins.Parent = leaderstats

	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Перерождения"
	rebirths.Parent = leaderstats

	leaderstats.Parent = player
end

local function sanitize(saved: any): { [string]: number }
	local data = table.clone(DEFAULT_DATA)
	if type(saved) == "table" then
		for key, default in DEFAULT_DATA do
			if type(saved[key]) == type(default) then
				data[key] = saved[key]
			end
		end
	end
	data.ToolTier = math.clamp(data.ToolTier, 1, #Config.Tools)
	data.BackpackTier = math.clamp(data.BackpackTier, 1, #Config.Backpacks)
	data.MaxZone = math.clamp(data.MaxZone, 1, #Config.Zones)
	return data
end

function DataService.Load(player: Player)
	local saved = nil
	local canSave = store ~= nil

	if store then
		local ok, result = withRetries(function()
			return (store :: DataStore):GetAsync(keyFor(player))
		end)
		if ok then
			saved = result
		else
			-- Не сохраняем поверх, иначе пустые данные затрут настоящий прогресс.
			canSave = false
			warn("[DataService] Не удалось загрузить данные", player.Name, result)
		end
	end

	if not player.Parent then
		return
	end

	local data = sanitize(saved)
	profiles[player] = { Data = data, CanSave = canSave }

	createLeaderstats(player)
	for key, value in data do
		syncAttribute(player, key, value)
	end
	player:SetAttribute("DataLoaded", true)

	if not canSave then
		Remotes.Notify:FireClient(
			player,
			"Сохранение недоступно. В Studio включите Game Settings → Security → Enable Studio Access to API Services.",
			"error"
		)
	end
end

function DataService.IsLoaded(player: Player): boolean
	return profiles[player] ~= nil
end

function DataService.Get(player: Player, key: string): number
	local profile = profiles[player]
	assert(profile, "Данные игрока ещё не загружены")
	return profile.Data[key]
end

function DataService.Set(player: Player, key: string, value: number)
	local profile = profiles[player]
	assert(profile, "Данные игрока ещё не загружены")
	profile.Data[key] = value
	syncAttribute(player, key, value)
	changedEvent:Fire(player, key, value)
end

function DataService.Increment(player: Player, key: string, delta: number): number
	local value = DataService.Get(player, key) + delta
	DataService.Set(player, key, value)
	return value
end

function DataService.Save(player: Player)
	local profile = profiles[player]
	if not profile or not profile.CanSave or not store then
		return
	end

	local snapshot = table.clone(profile.Data)
	local ok, err = withRetries(function()
		return (store :: DataStore):SetAsync(keyFor(player), snapshot, { player.UserId })
	end)
	if not ok then
		warn("[DataService] Не удалось сохранить", player.Name, err)
	end
end

function DataService.Start()
	Players.PlayerRemoving:Connect(function(player)
		DataService.Save(player)
		profiles[player] = nil
	end)

	game:BindToClose(function()
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				DataService.Save(player)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for player in profiles do
				task.spawn(DataService.Save, player)
			end
		end
	end)
end

return DataService
