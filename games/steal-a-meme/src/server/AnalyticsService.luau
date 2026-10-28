-- Аналитика Roblox (Creator Hub → Analytics): воронка новичка, экономика монет, свои события.
-- Все вызовы обёрнуты в pcall: сбой аналитики не должен ломать игру.
-- Зависит только от DataService/Hooks/Config — его можно подключать из любого сервиса без циклов.
--   AnalyticsService.Economy(player, "Sink", price, "Shop", memeId)  -- после списания/начисления монет
--   AnalyticsService.Custom(player, "RobuxPurchase", 1, productKey)
local Players = game:GetService("Players")
local RobloxAnalytics = game:GetService("AnalyticsService")

local DataService = require(script.Parent.DataService)
local Hooks = require(script.Parent.Hooks)

local AnalyticsService = {}

-- Игровые события из Hooks, которые копим и отправляем пачкой (Earn/Play — слишком частые, не шлём)
local COUNTED = { Steal = true, Merge = true, Defend = true }
local FLUSH_INTERVAL = 60

-- Шаги воронки новичка
local STEPS = {
	Joined = 1,
	FirstBuy = 2,
	FirstSteal = 3,
	TutorialDone = 4,
	FirstRebirth = 5,
}

local counts: { [Player]: { [string]: number } } = {}
local onboarding: { [Player]: { [string]: boolean } } = {} -- только у новых игроков: какие шаги уже отправлены
local connections: { [Player]: { RBXScriptConnection } } = {}

local function warnFail(what: string, err: any)
	warn("[AnalyticsService]", what, err)
end

local function customFields(field: string?): { [string]: string }?
	if field == nil then
		return nil
	end
	return { [Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = field }
end

-- Своё событие (value — число, field — необязательная метка, например ключ продукта)
function AnalyticsService.Custom(player: Player, eventName: string, value: number?, field: string?)
	local ok, err = pcall(function()
		RobloxAnalytics:LogCustomEvent(player, eventName, value or 1, customFields(field))
	end)
	if not ok then
		warnFail("LogCustomEvent", err)
	end
end

-- Движение монет. flowType: "Source" | "Sink"; transactionType: имя Enum.AnalyticsEconomyTransactionType
-- ("Shop", "Gameplay", "IAP", "Onboarding", "TimedReward", "ContextualPurchase") или своё.
-- Вызывать ПОСЛЕ изменения баланса: конечный баланс берётся из DataService.
function AnalyticsService.Economy(player: Player, flowType: string, amount: number, transactionType: string, itemSku: string?)
	if not DataService.IsLoaded(player) or type(amount) ~= "number" or amount <= 0 or amount ~= amount then
		return
	end
	local flow = if flowType == "Source"
		then Enum.AnalyticsEconomyFlowType.Source
		else Enum.AnalyticsEconomyFlowType.Sink
	local ok, err = pcall(function()
		RobloxAnalytics:LogEconomyEvent(
			player,
			flow,
			"Coins",
			math.floor(amount),
			math.floor(DataService.Get(player, "Coins")),
			transactionType,
			itemSku
		)
	end)
	if not ok then
		warnFail("LogEconomyEvent", err)
	end
end

-- Шаг воронки новичка: только для новых игроков и только один раз за сессию
local function step(player: Player, name: string)
	local done = onboarding[player]
	if not done or done[name] then
		return
	end
	done[name] = true
	local ok, err = pcall(function()
		RobloxAnalytics:LogOnboardingStepEvent(player, STEPS[name], name)
	end)
	if not ok then
		warnFail("LogOnboardingStepEvent", err)
	end
end

local function flush(player: Player)
	local pending = counts[player]
	if not pending then
		return
	end
	counts[player] = {}
	for stat, amount in pending do
		if amount > 0 then
			AnalyticsService.Custom(player, stat, amount)
		end
	end
end

function AnalyticsService.OnLoaded(player: Player)
	counts[player] = {}
	if not DataService.IsNew(player) then
		return
	end
	onboarding[player] = {}
	step(player, "Joined")

	local list = {}
	local function onTutorial()
		if (player:GetAttribute("TutorialDone") or 0) >= 1 then
			step(player, "TutorialDone")
		end
	end
	local function onRebirths()
		if (player:GetAttribute("Rebirths") or 0) >= 1 then
			step(player, "FirstRebirth")
		end
	end
	table.insert(list, player:GetAttributeChangedSignal("TutorialDone"):Connect(onTutorial))
	table.insert(list, player:GetAttributeChangedSignal("Rebirths"):Connect(onRebirths))
	connections[player] = list
end

function AnalyticsService.OnPlayerRemoving(player: Player)
	flush(player)
	counts[player] = nil
	onboarding[player] = nil
	for _, connection in connections[player] or {} do
		connection:Disconnect()
	end
	connections[player] = nil
end

function AnalyticsService.Start()
	Hooks.Connect(function(player, stat, amount)
		if stat == "Buy" then
			step(player, "FirstBuy")
		elseif stat == "Steal" then
			step(player, "FirstSteal")
		end
		local pending = counts[player]
		if COUNTED[stat] and pending then
			pending[stat] = (pending[stat] or 0) + amount
		end
	end)
	task.spawn(function()
		while true do
			task.wait(FLUSH_INTERVAL)
			for _, player in Players:GetPlayers() do
				flush(player)
			end
		end
	end)
end

return AnalyticsService
