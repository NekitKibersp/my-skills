-- «Фундамент» v5: прокачка скорости за монеты, кнопка «Домой», настройки игрока и награды перерождений.
-- Награды перерождения выдаются здесь, а не в PlotService: Grant сам требует PlotService
-- (PlotService зовёт нас через колбэк PlotService.OnRebirthRewards).
-- Всё решает сервер: цены уровней скорости, перезарядка «Домой», допустимые ключи и значения настроек.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local StealService = require(script.Parent.StealService)
local ZoneService = require(script.Parent.ZoneService)
local Grant = require(script.Parent.Grant)
local Remotes = require(script.Parent.Remotes)
local AnalyticsService = require(script.Parent.AnalyticsService)

local FoundationService = {}

-- Настройки: ключ -> тип и значение по умолчанию (UiScale ограничивается диапазоном)
local SETTINGS: { [string]: { Kind: string, Default: any, Min: number?, Max: number? } } = {
	Sound = { Kind = "boolean", Default = true },
	LowGraphics = { Kind = "boolean", Default = false },
	HideBillboards = { Kind = "boolean", Default = false },
	UiScale = { Kind = "number", Default = 1, Min = 0.7, Max = 1.3 },
}
local SETTINGS_WINDOW = 10 -- сек: окно лимита изменений настроек
local SETTINGS_MAX_PER_WINDOW = 30
local SPEED_MIN_INTERVAL = 0.3 -- сек между покупками скорости (защита от спама RF)

local settingsTimes: { [Player]: { number } } = {}
local lastSpeedBuy: { [Player]: number } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function alive(player: Player): boolean
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then
		return false
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

-- ===== Скорость =====

local function buySpeed(player: Player): (boolean, string)
	if not DataService.IsLoaded(player) then
		return false, "NotLoaded"
	end
	local t = os.clock()
	if t - (lastSpeedBuy[player] or -math.huge) < SPEED_MIN_INTERVAL then
		return false, "TooFast"
	end
	lastSpeedBuy[player] = t
	local level = DataService.Get(player, "SpeedLevel")
	local nextLevel = Config.Speed[level + 1]
	if not nextLevel then
		Remotes.Notify:FireClient(player, "SpeedMax", nil, "error")
		return false, "SpeedMax"
	end
	if DataService.Get(player, "Coins") < nextLevel.Price then
		Remotes.Notify:FireClient(player, "NotEnoughCash", { Price = nextLevel.Price }, "error")
		return false, "NotEnoughCash"
	end
	DataService.Increment(player, "Coins", -nextLevel.Price)
	AnalyticsService.Economy(player, "Sink", nextLevel.Price, "Gameplay", "Speed" .. (level + 1))
	DataService.Set(player, "SpeedLevel", level + 1)
	StealService.UpdateSpeed(player)
	Remotes.Notify:FireClient(player, "SpeedUpgraded", { Level = level + 1, Bonus = nextLevel.Bonus }, "success")
	return true, "SpeedUpgraded"
end

-- ===== «Домой» =====

local function goHome(player: Player)
	if not DataService.IsLoaded(player) or not alive(player) then
		return
	end
	local plot = PlotService.GetPlot(player)
	if not plot then
		return
	end
	if StealService.IsCarrying(player) then
		Remotes.Notify:FireClient(player, "HomeCarrying", nil, "error")
		return
	end
	local t = now()
	local readyAt = player:GetAttribute("HomeReadyAt") or 0
	if readyAt > t then
		Remotes.Notify:FireClient(player, "HomeCooldown", { Seconds = math.ceil(readyAt - t) }, "error")
		return
	end
	player:SetAttribute("HomeReadyAt", t + Config.HomeCooldown)
	-- Перенос с подгрузкой места (StreamingEnabled) и отметкой ServerMovedAt для анти-чита переноски;
	-- если за время подгрузки игрок взял мема — перенос отменяется
	ZoneService.Teleport(player, PlotService.SpawnPoint(plot))
end

-- ===== Настройки =====

-- Сохранённые настройки: только известные ключи нужного типа, остальное — по умолчанию
local function cleanSettings(player: Player): { [string]: any }
	local data = DataService.GetTable(player, "Settings")
	for key in data do
		if not SETTINGS[key] then
			data[key] = nil
		end
	end
	for key, spec in SETTINGS do
		local value = data[key]
		if type(value) ~= spec.Kind or (spec.Kind == "number" and value ~= value) then
			data[key] = spec.Default
		elseif spec.Kind == "number" then
			data[key] = math.clamp(value, spec.Min :: number, spec.Max :: number)
		end
	end
	return data
end

local function syncSettings(player: Player)
	player:SetAttribute("SettingsJson", HttpService:JSONEncode(cleanSettings(player)))
end

-- Лимит частоты: не больше SETTINGS_MAX_PER_WINDOW изменений за SETTINGS_WINDOW сек
local function allowSetting(player: Player): boolean
	local t = os.clock()
	local times = settingsTimes[player]
	if not times then
		times = {}
		settingsTimes[player] = times
	end
	while #times > 0 and t - times[1] > SETTINGS_WINDOW do
		table.remove(times, 1)
	end
	if #times >= SETTINGS_MAX_PER_WINDOW then
		return false
	end
	table.insert(times, t)
	return true
end

local function setSetting(player: Player, key: unknown, value: unknown)
	if typeof(key) ~= "string" or not DataService.IsLoaded(player) then
		return
	end
	local spec = SETTINGS[key]
	if not spec or typeof(value) ~= spec.Kind then
		return
	end
	if not allowSetting(player) then
		return
	end
	local data = cleanSettings(player)
	if spec.Kind == "number" then
		local number = value :: number
		if number ~= number or number == math.huge or number == -math.huge then
			return
		end
		data[key] = math.clamp(number, spec.Min :: number, spec.Max :: number)
	else
		data[key] = value
	end
	syncSettings(player)
end

-- ===== Награды перерождения =====

-- rewards = Config.Rebirth.Tiers[n].Rewards: { Spins?, Item?, Floor? } (этаж открывает сам PlotService)
local function giveRebirthRewards(player: Player, rewards: any)
	if type(rewards) ~= "table" or not DataService.IsLoaded(player) then
		return
	end
	if type(rewards.Spins) == "number" and rewards.Spins >= 1 then
		DataService.Increment(player, "Spins", math.floor(rewards.Spins))
		Remotes.Notify:FireClient(player, "RebirthSpins", { Count = math.floor(rewards.Spins) }, "success")
	end
	if type(rewards.Item) == "string" then
		-- Уже есть предмет — Grant выдаст монеты
		local result = Grant.Give(player, { Kind = "Item", ItemId = rewards.Item })
		if result.Item then
			Remotes.Notify:FireClient(player, "RebirthItem", { Item = result.Item }, "success")
		elseif result.Coins then
			Remotes.Notify:FireClient(player, "CashBought", { Coins = result.Coins }, "success")
		end
	end
end

-- ===== Жизненный цикл =====

-- Вызывается из init.server после загрузки данных
function FoundationService.OnLoaded(player: Player)
	player:SetAttribute("HomeReadyAt", 0)
	syncSettings(player)
end

function FoundationService.OnPlayerRemoving(player: Player)
	settingsTimes[player] = nil
	lastSpeedBuy[player] = nil
end

function FoundationService.Start()
	PlotService.OnRebirthRewards = giveRebirthRewards

	Remotes.BuySpeed.OnServerInvoke = function(player: Player)
		local ok, result, key = pcall(buySpeed, player)
		if not ok then
			warn("[FoundationService] BuySpeed:", result)
			return false, "NotLoaded"
		end
		return result, key
	end
	Remotes.GoHome.OnServerEvent:Connect(function(player: Player)
		local ok, err = pcall(goHome, player)
		if not ok then
			warn("[FoundationService] GoHome:", err)
		end
	end)
	Remotes.SetSetting.OnServerEvent:Connect(function(player: Player, key: unknown, value: unknown)
		local ok, err = pcall(setSetting, player, key, value)
		if not ok then
			warn("[FoundationService] SetSetting:", err)
		end
	end)
end

return FoundationService
