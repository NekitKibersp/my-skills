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
	TutorialDone = 0,
	GiftDay = 0, -- день (os.time() // 86400), к которому относятся PlayedToday и GiftsClaimed
	GiftsClaimed = 0,
	PlayedToday = 0, -- секунд сыграно за день (для подарков за время)
	TurretLevel = 0, -- уровень турели на базе (Config.Defense.Turret)
	LaserLevel = 0, -- уровень лазерных ворот (Config.Defense.LaserGate)
	Spins = 0, -- купленные/выигранные вращения колеса
	LastFreeSpinDay = 0, -- UTC-день последнего бесплатного вращения
}

-- Табличные поля:
--   Memes    — массив { Id, Mut, Viral, Slot } (мемы на базе)
--   Index    — { ["Id|Mut"] = true } (открытые записи Индекса)
--   Receipts — массив PurchaseId обработанных покупок за Robux (защита от двойной выдачи)
--   Items    — { [itemId] = true } купленные предметы (Config.Items)
--   Quests   — { Day, List = { { Id, Goal, Progress, Claimed } }, AllClaimed } ежедневные квесты (проверяет QuestService)
--   BattlePass — { Season, Xp, Free = { [level] = true }, Premium = { [level] = true } } (BattlePassService)
--   Skins    — { Owned = { [skinId] = true }, Base = id, Slipper = id } (SkinService)
--   Codes    — { [CODE] = true } введённые коды (SocialService)
--   Zones    — { Tower1 = day, Tower2 = day, Tower3 = day, Cave = day } UTC-дни забранных призов зон (ZoneService)
local TABLE_KEYS = { "Memes", "Index", "Receipts", "Items", "Quests", "BattlePass", "Skins", "Codes", "Zones" }
-- Таблицы, которые хранятся как есть (проверяют их сами сервисы)
local FREEFORM_TABLES = { "Quests", "BattlePass", "Skins", "Codes", "Zones" }

-- Блокировка сессии: пока игрок на одном сервере, другой сервер не загрузит его данные
-- (иначе при быстром переходе между серверами можно задублировать мемов).
local LOCK_STALE_AFTER = 300 -- сек: блокировку упавшего сервера считаем протухшей
local LOCK_RETRIES = 6
local LOCK_RETRY_DELAY = 4

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
	data.Items = {}
	if type(savedTable.Items) == "table" then
		for key, value in savedTable.Items do
			if type(key) == "string" and value == true and Config.GetItem(key) then
				data.Items[key] = true
			end
		end
	end
	for _, key in FREEFORM_TABLES do
		data[key] = if type(savedTable[key]) == "table" then savedTable[key] else {}
	end
	-- Старые сохранения (до туториала) — туториал не показываем
	if not isNew and saved.TutorialDone == nil then
		data.TutorialDone = 1
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
		local loaded = false
		for attempt = 1, LOCK_RETRIES do
			local lockedElsewhere = false
			local ok, result = withRetries(function()
				return (store :: DataStore):UpdateAsync(keyFor(player), function(old)
					lockedElsewhere = false
					local session = type(old) == "table" and old.Session
					if type(session) == "table" and session.JobId ~= game.JobId
						and os.time() - (tonumber(session.Time) or 0) < LOCK_STALE_AFTER
						and attempt < LOCK_RETRIES then
						lockedElsewhere = true
						return nil -- не трогаем: данные ещё держит другой сервер
					end
					local value = if type(old) == "table" then old else {}
					value.Session = { JobId = game.JobId, Time = os.time() }
					return value, { player.UserId }
				end)
			end)
			if not ok then
				warn("[DataService] Не удалось загрузить данные", player.Name, result)
				break
			end
			if not lockedElsewhere then
				saved = result
				loaded = true
				break
			end
			-- Прошлый сервер ещё сохраняет игрока — подождём
			task.wait(LOCK_RETRY_DELAY)
			if not player.Parent then
				return
			end
		end
		if not loaded then
			-- Не сохраняем поверх, иначе пустые данные затрут настоящий прогресс.
			canSave = false
		elseif type(saved) == "table" and next(saved) and saved.Coins == nil then
			saved = nil -- в хранилище только блокировка, данных ещё не было
		end
	end

	if not player.Parent then
		-- Игрок ушёл, пока грузились данные: снимаем свою блокировку, иначе следующий сервер
		-- будет ждать её протухания
		if store and canSave then
			pcall(function()
				(store :: DataStore):UpdateAsync(keyFor(player), function(old)
					if type(old) == "table" and type(old.Session) == "table" and old.Session.JobId == game.JobId then
						old.Session = nil
						return old, { player.UserId }
					end
					return nil
				end)
			end)
		end
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

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for key, inner in value do
		result[key] = deepCopy(inner)
	end
	return result
end

local function snapshot(data: { [string]: any }): { [string]: any }
	local copy = table.clone(data)
	copy.Memes = {}
	for _, entry in data.Memes do
		table.insert(copy.Memes, { Id = entry.Id, Mut = entry.Mut, Viral = entry.Viral, Slot = entry.Slot })
	end
	copy.Index = table.clone(data.Index)
	copy.Receipts = table.clone(data.Receipts)
	copy.Items = table.clone(data.Items)
	for _, key in FREEFORM_TABLES do
		copy[key] = deepCopy(data[key])
	end
	return copy
end

-- release = true снимает блокировку сессии (игрок уходит с сервера)
function DataService.Save(player: Player, release: boolean?): boolean
	local profile = profiles[player]
	if not profile or not profile.CanSave or not store then
		return false
	end

	profile.Data.LastSeen = os.time()
	local copy = snapshot(profile.Data)
	copy.Session = if release then nil else { JobId = game.JobId, Time = os.time() }
	local lostLock = false
	local ok, err = withRetries(function()
		return (store :: DataStore):UpdateAsync(keyFor(player), function(old)
			lostLock = false
			local session = type(old) == "table" and old.Session
			if type(session) == "table" and session.JobId ~= game.JobId then
				-- Данные уже забрал другой сервер — не затираем их устаревшей копией
				lostLock = true
				return nil
			end
			-- UserIds (для запросов GDPR) передаются вторым значением из функции, а не аргументом UpdateAsync
			return copy, { player.UserId }
		end)
	end)
	if lostLock then
		warn("[DataService] Сессия игрока открыта на другом сервере, сохранение пропущено", player.Name)
		profile.CanSave = false
		return false
	end
	if not ok then
		warn("[DataService] Не удалось сохранить", player.Name, err)
	end
	return ok
end

-- Вызывается из init.server после того, как другие сервисы отработали выход игрока
-- (например, вернули украденного мема хозяину), чтобы сохранить итоговое состояние.
function DataService.Release(player: Player)
	DataService.Save(player, true)
	profiles[player] = nil
end

function DataService.Start()
	game:BindToClose(function()
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				DataService.Save(player, true)
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
