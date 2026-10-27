-- Прогресс игроков: загрузка/сохранение в DataStore, leaderstats и зеркало в атрибутах игрока,
-- чтобы клиентский UI читал значения через player:GetAttribute без лишних remotes.
-- Хранит только числа; для сложных данных (инвентарь) расширьте sanitize и syncAttribute.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Remotes = require(script.Parent.Remotes)

local DataService = {}

local STORE_NAME = "GameData_v1" -- смена версии = чистый старт для всех
local AUTOSAVE_INTERVAL = 120

-- Все сохраняемые поля и их значения по умолчанию.
local DEFAULT_DATA: { [string]: number } = {
	Coins = 0,
}

-- Поля, которые видны в таблице игроков: ключ данных -> подпись.
local LEADERSTATS: { { Key: string, Label: string } } = {
	{ Key = "Coins", Label = "Монеты" },
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

	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		for _, stat in LEADERSTATS do
			if stat.Key == key then
				(leaderstats:FindFirstChild(stat.Label) :: IntValue).Value = value
			end
		end
	end
end

local function createLeaderstats(player: Player)
	if #LEADERSTATS == 0 then
		return
	end
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	for _, stat in LEADERSTATS do
		local value = Instance.new("IntValue")
		value.Name = stat.Label
		value.Parent = leaderstats
	end
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
	assert(DEFAULT_DATA[key] ~= nil, "Неизвестное поле данных: " .. key)
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
