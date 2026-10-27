-- Прогресс игроков: загрузка/сохранение в DataStore, leaderstats и зеркало чисел в атрибутах игрока,
-- чтобы клиентский UI читал значения через player:GetAttribute без лишних remotes.
-- Числовые поля — через Get/Set/Increment; таблицы (мемы на базе, Индекс, чеки покупок) — через GetTable.
local DataStoreService = game:GetService("DataStoreService")

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local Remotes = require(script.Parent.Remotes)

local DataService = {}

local STORE_NAME = "StealAMeme_v1" -- смена версии = чистый старт для всех
local AUTOSAVE_INTERVAL = 120
local MAX_RECEIPTS = 100

-- Числовые поля и значения по умолчанию
local DEFAULT_NUMBERS: { [string]: number } = {
	Coins = Config.StartCoins,
	Rebirths = 0,
	Stolen = 0,
	TotalEarned = 0,
	GuardLevel = 0,
	LastSeen = 0,
	DailyStreak = 0,
	LastDailyDay = 0,
}

-- Табличные поля:
--   Memes    — массив { Id, Mut, Viral, Slot } (мемы на базе)
--   Index    — { ["Id|Mut"] = true } (открытые записи Индекса)
--   Receipts — массив PurchaseId обработанных покупок за Robux (защита от двойной выдачи)
local TABLE_KEYS = { "Memes", "Index", "Receipts" }

-- Поля в таблице игроков: ключ данных -> подпись
local LEADERSTATS: { { Key: string, Label: string } } = {
	{ Key = "Coins", Label = "Cash" },
	{ Key = "Stolen", Label = "Steals" },
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

type Profile = { Data: { [string]: any }, CanSave: boolean, IsNew: boolean }
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
				(leaderstats:FindFirstChild(stat.Label) :: IntValue).Value = math.floor(value)
			end
		end
	end
end

local function createLeaderstats(player: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	for _, stat in LEADERSTATS do
		local value = Instance.new("IntValue")
		value.Name = stat.Label
		value.Parent = leaderstats
	end
	leaderstats.Parent = player
end

local function sanitizeMemes(saved: any): { any }
	local result = {}
	local usedSlots = {}
	if type(saved) ~= "table" then
		return result
	end
	for _, entry in saved do
		if type(entry) == "table" and type(entry.Id) == "string" and Config.GetCreature(entry.Id)
			and type(entry.Slot) == "number" and entry.Slot >= 1 and entry.Slot <= Config.AbsoluteMaxSlots
			and not usedSlots[entry.Slot] then
			usedSlots[entry.Slot] = true
			table.insert(result, {
				Id = entry.Id,
				Mut = if type(entry.Mut) == "string" then Config.GetMutation(entry.Mut).Id else "None",
				Viral = entry.Viral == true,
				Slot = math.floor(entry.Slot),
			})
		end
	end
	return result
end

local function sanitize(saved: any): ({ [string]: any }, boolean)
	local data: { [string]: any } = table.clone(DEFAULT_NUMBERS)
	local isNew = type(saved) ~= "table"
	if not isNew then
		for key, default in DEFAULT_NUMBERS do
			if type(saved[key]) == type(default) then
				data[key] = saved[key]
			end
		end
	end
	local savedTable = if isNew then {} else saved
	data.Memes = sanitizeMemes(savedTable.Memes)
	data.Index = {}
	if type(savedTable.Index) == "table" then
		for key, value in savedTable.Index do
			if type(key) == "string" and value == true then
				data.Index[key] = true
			end
		end
	end
	data.Receipts = {}
	if type(savedTable.Receipts) == "table" then
		for _, id in savedTable.Receipts do
			if type(id) == "string" then
				table.insert(data.Receipts, id)
			end
		end
	end
	return data, isNew
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

	local data, isNew = sanitize(saved)
	profiles[player] = { Data = data, CanSave = canSave, IsNew = isNew }

	createLeaderstats(player)
	for key in DEFAULT_NUMBERS do
		syncAttribute(player, key, data[key])
	end

	if not canSave then
		Remotes.Notify:FireClient(player, "SaveDisabled", nil, "error")
	end
end

function DataService.IsLoaded(player: Player): boolean
	return profiles[player] ~= nil
end

-- Новый игрок (сохранения ещё не было)
function DataService.IsNew(player: Player): boolean
	local profile = profiles[player]
	return profile ~= nil and profile.IsNew
end

function DataService.Get(player: Player, key: string): number
	local profile = profiles[player]
	assert(profile, "Данные игрока ещё не загружены")
	return profile.Data[key]
end

function DataService.Set(player: Player, key: string, value: number)
	local profile = profiles[player]
	assert(profile, "Данные игрока ещё не загружены")
	assert(DEFAULT_NUMBERS[key] ~= nil, "Неизвестное числовое поле: " .. key)
	profile.Data[key] = value
	syncAttribute(player, key, value)
	changedEvent:Fire(player, key, value)
end

function DataService.Increment(player: Player, key: string, delta: number): number
	local value = DataService.Get(player, key) + delta
	DataService.Set(player, key, value)
	return value
end

-- Возвращает саму таблицу (не копию): меняйте её на месте.
function DataService.GetTable(player: Player, key: string): any
	local profile = profiles[player]
	assert(profile, "Данные игрока ещё не загружены")
	assert(table.find(TABLE_KEYS, key), "Неизвестное табличное поле: " .. key)
	return profile.Data[key]
end

function DataService.HasReceipt(player: Player, purchaseId: string): boolean
	return table.find(DataService.GetTable(player, "Receipts"), purchaseId) ~= nil
end

function DataService.AddReceipt(player: Player, purchaseId: string)
	local receipts = DataService.GetTable(player, "Receipts")
	table.insert(receipts, purchaseId)
	while #receipts > MAX_RECEIPTS do
		table.remove(receipts, 1)
	end
end

local function snapshot(data: { [string]: any }): { [string]: any }
	local copy = table.clone(data)
	copy.Memes = {}
	for _, entry in data.Memes do
		table.insert(copy.Memes, { Id = entry.Id, Mut = entry.Mut, Viral = entry.Viral, Slot = entry.Slot })
	end
	copy.Index = table.clone(data.Index)
	copy.Receipts = table.clone(data.Receipts)
	return copy
end

function DataService.Save(player: Player): boolean
	local profile = profiles[player]
	if not profile or not profile.CanSave or not store then
		return false
	end

	profile.Data.LastSeen = os.time()
	local copy = snapshot(profile.Data)
	local ok, err = withRetries(function()
		return (store :: DataStore):SetAsync(keyFor(player), copy, { player.UserId })
	end)
	if not ok then
		warn("[DataService] Не удалось сохранить", player.Name, err)
	end
	return ok
end

-- Вызывается из init.server после того, как другие сервисы отработали выход игрока
-- (например, вернули украденного мема хозяину), чтобы сохранить итоговое состояние.
function DataService.Release(player: Player)
	DataService.Save(player)
	profiles[player] = nil
end

function DataService.Start()
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
