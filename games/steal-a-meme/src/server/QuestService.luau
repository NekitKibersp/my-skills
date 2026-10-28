-- Ежедневные квесты: Config.Quests.PerDay случайных заданий из пула, сброс в полночь UTC.
-- Прогресс двигают Hooks (другие сервисы сообщают «что произошло»), время в игре считаем здесь же.
-- Данные: DataService.GetTable(player, "Quests") = { Day, List = { { Id, Goal, Progress, Claimed } }, AllClaimed }.
-- Клиент читает атрибут QuestsJson и просит награду через Remotes.ClaimQuest(index | "All").
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local Hooks = require(script.Parent.Hooks)
local Remotes = require(script.Parent.Remotes)

local QuestService = {}

local SECONDS_PER_DAY = 86400
local DAY_CHECK = 30
local PLAY_TICK = 5

local function currentDay(): number
	return os.time() // SECONDS_PER_DAY
end

local function isReady(player: Player): boolean
	return player.Parent ~= nil and player:GetAttribute("DataLoaded") == true and DataService.IsLoaded(player)
end

-- Сохранённые квесты могли испортиться или устареть после правки конфига — проверяем всё
local function isValid(data: any): boolean
	if type(data) ~= "table" or type(data.Day) ~= "number" or type(data.List) ~= "table" then
		return false
	end
	for _, quest in data.List do
		if type(quest) ~= "table" or type(quest.Id) ~= "string" or not Config.GetQuest(quest.Id)
			or type(quest.Goal) ~= "number" or quest.Goal < 1
			or type(quest.Progress) ~= "number" or type(quest.Claimed) ~= "boolean" then
			return false
		end
	end
	return #data.List > 0
end

-- Новый набор квестов на день
local function roll(player: Player, data: { [string]: any })
	local pool = table.clone(Config.Quests.Pool)
	local list = {}
	for _ = 1, math.min(Config.Quests.PerDay, #pool) do
		local quest = table.remove(pool, math.random(1, #pool))
		local goal = quest.Goal
		if quest.Stat == "Earn" then
			goal = math.max(1000, math.floor(PlotService.IncomeOf(player) * (quest.GoalIncomeSeconds or 0)))
		end
		table.insert(list, { Id = quest.Id, Goal = goal, Progress = 0, Claimed = false })
	end
	table.clear(data)
	data.Day = currentDay()
	data.List = list
	data.AllClaimed = false
end

local function sync(player: Player)
	local data = DataService.GetTable(player, "Quests")
	local secondsLeft = SECONDS_PER_DAY - os.time() % SECONDS_PER_DAY
	player:SetAttribute("QuestsJson", HttpService:JSONEncode({
		List = data.List,
		AllClaimed = data.AllClaimed == true,
		ResetAt = workspace:GetServerTimeNow() + secondsLeft,
	}))
end

-- Квесты актуальны на сегодня; иначе перевыбираем. Возвращает таблицу квестов или nil, если данных нет.
local function ensure(player: Player): { [string]: any }?
	if not DataService.IsLoaded(player) then
		return nil
	end
	local data = DataService.GetTable(player, "Quests")
	if not isValid(data) or data.Day ~= currentDay() then
		roll(player, data)
		sync(player)
	end
	return data
end

local function onStat(player: Player, stat: string, amount: number)
	if not isReady(player) or type(amount) ~= "number" or amount <= 0 then
		return
	end
	local data = ensure(player)
	if not data then
		return
	end
	local changed = false
	for _, quest in data.List do
		local config = Config.GetQuest(quest.Id)
		if config and config.Stat == stat and not quest.Claimed and quest.Progress < quest.Goal then
			quest.Progress = math.min(quest.Goal, quest.Progress + amount)
			changed = true
			if quest.Progress >= quest.Goal then
				Remotes.Notify:FireClient(player, "QuestDone", nil, "success")
			end
		end
	end
	if changed then
		sync(player)
	end
end

local function claim(player: Player, index: any): (boolean, string)
	if not isReady(player) then
		return false, "QuestNotReady"
	end
	local data = ensure(player)
	if not data then
		return false, "QuestNotReady"
	end

	if index == "All" then
		if data.AllClaimed then
			return false, "QuestAlreadyClaimed"
		end
		for _, quest in data.List do
			if not quest.Claimed then
				return false, "QuestAllNotReady"
			end
		end
		data.AllClaimed = true
		local coins = math.max(Config.Quests.AllDoneMinCoins,
			math.floor(PlotService.IncomeOf(player) * Config.Quests.AllDoneIncomeSeconds))
		PlotService.AddCoins(player, coins)
		sync(player)
		Remotes.Notify:FireClient(player, "QuestAllReward", { Coins = coins }, "success")
		return true, "QuestAllClaimed"
	end

	-- Номер квеста: только целое число в пределах списка
	if type(index) ~= "number" or index ~= index or index % 1 ~= 0 then
		return false, "QuestNotReady"
	end
	local quest = data.List[index]
	if not quest then
		return false, "QuestNotReady"
	end
	if quest.Claimed then
		return false, "QuestAlreadyClaimed"
	end
	if quest.Progress < quest.Goal then
		return false, "QuestNotReady"
	end
	local config = Config.GetQuest(quest.Id)
	if not config then
		return false, "QuestNotReady"
	end
	quest.Claimed = true
	local coins = math.max(config.MinCoins, math.floor(PlotService.IncomeOf(player) * config.IncomeSeconds))
	PlotService.AddCoins(player, coins)
	sync(player)
	Remotes.Notify:FireClient(player, "QuestReward", { Coins = coins }, "success")
	return true, "QuestClaimed"
end

-- Вызывается из init.server после загрузки базы (доход уже известен — нужен для цели Earn)
function QuestService.OnLoaded(player: Player)
	if ensure(player) then
		sync(player)
	end
end

function QuestService.Start()
	Hooks.Connect(onStat)

	Remotes.ClaimQuest.OnServerInvoke = function(player: Player, index: any)
		local ok, result, key = pcall(claim, player, index)
		if not ok then
			warn("[QuestService] Ошибка выдачи награды квеста:", result)
			return false, "QuestNotReady"
		end
		return result, key
	end

	-- Время в игре (квесты Play) — через Hooks, чтобы его видели и другие подписчики
	task.spawn(function()
		while true do
			task.wait(PLAY_TICK)
			for _, player in Players:GetPlayers() do
				if isReady(player) then
					Hooks.Fire(player, "Play", PLAY_TICK)
				end
			end
		end
	end)

	-- Полночь UTC: новые квесты тем, кто в игре
	task.spawn(function()
		while true do
			task.wait(DAY_CHECK)
			for _, player in Players:GetPlayers() do
				if isReady(player) then
					ensure(player)
				end
			end
		end
	end)
end

return QuestService
