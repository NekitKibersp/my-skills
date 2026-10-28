-- Награды за возвращение: оффлайн-доход, календарь ежедневных наград (игрок забирает сам), подарки за время в игре.
-- Время для подарков копится за день и сохраняется, поэтому перезаход не даёт получить их заново.
-- Календарь: DailyStreak — последний забранный день (1..#Config.DailyCalendar), LastDailyDay — UTC-день забора.
-- Пропустил день — календарь начинается заново с первого дня.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local Remotes = require(script.Parent.Remotes)

local RewardService = {}

-- Выдан предмет из календаря (init.server связывает с ItemService, чтобы обновить инструменты и ItemsJson)
RewardService.OnItemGranted = nil :: ((Player) -> ())?

local SECONDS_PER_DAY = 86400
local GIFT_TICK = 5
local DAILY_TICK = 60

local function currentDay(): number
	return os.time() // SECONDS_PER_DAY
end

-- Какой день календаря выдадим следующим (стрик продолжается, только если забирал вчера)
local function nextDailyDay(player: Player): number
	if DataService.Get(player, "LastDailyDay") == currentDay() - 1 then
		return DataService.Get(player, "DailyStreak") % #Config.DailyCalendar + 1
	end
	return 1
end

-- Атрибуты DailyReady / DailyDay для кнопки календаря на клиенте
local function syncDaily(player: Player)
	if not DataService.IsLoaded(player) then
		return
	end
	local ready = DataService.Get(player, "LastDailyDay") ~= currentDay()
	player:SetAttribute("DailyReady", ready)
	player:SetAttribute("DailyDay", if ready then nextDailyDay(player) else DataService.Get(player, "DailyStreak"))
end

local function incomeCoins(player: Player, incomeSeconds: number, minCoins: number): number
	return math.max(minCoins, math.floor(PlotService.IncomeOf(player) * incomeSeconds))
end

-- Случайный обычный (не сезонный) мем нужной редкости
local function randomMemeOf(rarity: string): string?
	local pool = {}
	for _, creature in Config.Creatures do
		if creature.Rarity == rarity and not creature.Event then
			table.insert(pool, creature.Id)
		end
	end
	if #pool == 0 then
		return nil
	end
	return pool[math.random(1, #pool)]
end

local function claimDaily(player: Player): (boolean, string)
	if not player:GetAttribute("DataLoaded") or not DataService.IsLoaded(player) then
		return false, "DailyNotReady"
	end
	if DataService.Get(player, "LastDailyDay") == currentDay() then
		return false, "DailyNotReady"
	end
	local day = nextDailyDay(player)
	local reward = Config.DailyCalendar[day]
	-- Сначала отмечаем забор (до любых выдач), чтобы повторный вызов не выдал награду дважды
	DataService.Set(player, "DailyStreak", day)
	DataService.Set(player, "LastDailyDay", currentDay())
	syncDaily(player)

	local popup: { [string]: any } = { Day = day }
	if reward.Kind == "Meme" then
		local id = randomMemeOf(reward.Rarity)
		if id and PlotService.AddMeme(player, id, "None", false) then
			popup.Meme = id
		elseif id then
			-- База заполнена — половина цены мема деньгами
			local coins = math.max(1, math.floor(Config.PriceOf(id, "None") * 0.5))
			PlotService.AddCoins(player, coins)
			popup.Coins = coins
			Remotes.Notify:FireClient(player, "DailyMemeToCoins", { Meme = id, Coins = coins }, "info")
		else
			warn("[RewardService] Нет мемов редкости", reward.Rarity)
			popup.Coins = incomeCoins(player, 300, 1000)
			PlotService.AddCoins(player, popup.Coins)
		end
	elseif reward.Kind == "Item" then
		local items = DataService.GetTable(player, "Items")
		if Config.GetItem(reward.ItemId) and not items[reward.ItemId] then
			items[reward.ItemId] = true
			popup.Item = reward.ItemId
			if RewardService.OnItemGranted then
				task.spawn(RewardService.OnItemGranted, player)
			end
		else
			local fallback = reward.Fallback
			popup.Coins = incomeCoins(player, fallback.IncomeSeconds, fallback.MinCoins)
			PlotService.AddCoins(player, popup.Coins)
		end
	else
		popup.Coins = incomeCoins(player, reward.IncomeSeconds, reward.MinCoins)
		PlotService.AddCoins(player, popup.Coins)
	end

	Remotes.Popup:FireClient(player, "Daily", popup)
	return true, "DailyClaimed"
end

-- Новый день — обнуляем время и подарки. SessionStart для клиента = «сейчас минус сыграно сегодня».
local function syncPlaytime(player: Player)
	local today = os.time() // SECONDS_PER_DAY
	if DataService.Get(player, "GiftDay") ~= today then
		DataService.Set(player, "GiftDay", today)
		DataService.Set(player, "PlayedToday", 0)
		DataService.Set(player, "GiftsClaimed", 0)
	end
	player:SetAttribute("SessionStart", workspace:GetServerTimeNow() - DataService.Get(player, "PlayedToday"))
end

-- Вызывается после PlotService.LoadPlayer, когда доход игрока уже известен
function RewardService.OnLoaded(player: Player)
	syncPlaytime(player)

	-- Оффлайн-доход считаем без множителя админ-ивента: «Двойные деньги» не должны удваивать
	-- до 12 часов отсутствия только потому, что игрок зашёл во время ивента
	local income = PlotService.IncomeOf(player) / math.max(ReplicatedStorage:GetAttribute("EventIncomeMult") or 1, 1)

	-- Оффлайн-доход
	local lastSeen = DataService.Get(player, "LastSeen")
	if lastSeen > 0 then
		local plus = player:GetAttribute("Pass_OfflinePlus") == true
		local maxSeconds = if plus then Config.Offline.PassMaxSeconds else Config.Offline.MaxSeconds
		local rate = if plus then Config.Offline.PassRate else Config.Offline.Rate
		local seconds = math.clamp(os.time() - lastSeen, 0, maxSeconds)
		local coins = math.floor(income * rate * seconds)
		if seconds >= 60 and coins > 0 then
			PlotService.AddCoins(player, coins)
			Remotes.Popup:FireClient(player, "Offline", { Coins = coins, Seconds = seconds })
		end
	end

	syncDaily(player)
end

function RewardService.Start()
	Remotes.ClaimDaily.OnServerInvoke = function(player: Player)
		local ok, result, key = pcall(claimDaily, player)
		if not ok then
			warn("[RewardService] Ошибка выдачи ежедневной награды:", result)
			return false, "DailyNotReady"
		end
		return result, key
	end

	-- Смена UTC-дня у тех, кто в игре: календарь снова доступен
	task.spawn(function()
		while true do
			task.wait(DAILY_TICK)
			for _, player in Players:GetPlayers() do
				syncDaily(player)
			end
		end
	end)

	-- Подарки за время в игре
	task.spawn(function()
		while true do
			task.wait(GIFT_TICK)
			for _, player in Players:GetPlayers() do
				if not player:GetAttribute("DataLoaded") or not DataService.IsLoaded(player) then
					continue
				end
				DataService.Increment(player, "PlayedToday", GIFT_TICK)
				syncPlaytime(player)
				local played = DataService.Get(player, "PlayedToday")
				local claimed = DataService.Get(player, "GiftsClaimed")
				local gift = Config.PlaytimeGifts[claimed + 1]
				if gift and played >= gift.Minutes * 60 then
					local coins = math.max(gift.MinCoins, math.floor(PlotService.IncomeOf(player) * gift.IncomeSeconds))
					DataService.Set(player, "GiftsClaimed", claimed + 1)
					PlotService.AddCoins(player, coins)
					Remotes.Notify:FireClient(player, "Gift", { Coins = coins }, "success")
				end
			end
		end
	end)
end

return RewardService
