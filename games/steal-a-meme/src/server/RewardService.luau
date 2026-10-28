-- Награды за возвращение: оффлайн-доход, ежедневная награда со стриком, подарки за время в игре.
-- Время для подарков копится за день и сохраняется, поэтому перезаход не даёт получить их заново.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local Remotes = require(script.Parent.Remotes)

local RewardService = {}

local SECONDS_PER_DAY = 86400
local GIFT_TICK = 5

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

	local income = PlotService.IncomeOf(player)

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

	-- Ежедневная награда
	local today = os.time() // SECONDS_PER_DAY
	local lastDay = DataService.Get(player, "LastDailyDay")
	if lastDay ~= today then
		local streak = DataService.Get(player, "DailyStreak")
		streak = if lastDay == today - 1 then streak % Config.Daily.MaxDay + 1 else 1
		local coins = math.max(Config.Daily.MinCoins * streak, math.floor(income * Config.Daily.IncomeSeconds * streak))
		DataService.Set(player, "DailyStreak", streak)
		DataService.Set(player, "LastDailyDay", today)
		PlotService.AddCoins(player, coins)
		-- Небольшая задержка, чтобы окно не накрыло окно оффлайн-дохода сразу
		task.delay(1.5, function()
			if player.Parent then
				Remotes.Popup:FireClient(player, "Daily", { Coins = coins, Day = streak })
			end
		end)
	end
end

function RewardService.Start()
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
