-- Клиентская часть зон большой карты: всплывающее «+$X» над собранным пикапом Конфетного парка
-- (Fx "Pickup" {Position, Coins, UserId}), перевод промптов зон и столы Торговой площади
-- (промпт "TradePrompt" открывает окно выбора игрока для обмена). Сами зоны могут быть
-- выгружены стримингом — клиент на них не ждёт, а слушает события промптов.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Format"))
local Locale = require(Shared:WaitForChild("Locale"))
local Effects = require(script.Parent:WaitForChild("Effects"))
local UiKit = require(script.Parent:WaitForChild("UiKit"))

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local MAX_DISTANCE = 150

local Zones = {}

-- Промпты зон, которые сервер создаёт с английским текстом: имя -> ключ перевода
local PROMPT_TEXT = {
	TradePrompt = "ZoneTradePrompt",
	ChestPrompt = "ZoneChestPrompt",
}

local function onPickup(data: any)
	if data.UserId ~= player.UserId then
		return
	end
	local position = data.Position
	local coins = data.Coins
	if typeof(position) ~= "Vector3" or position ~= position or type(coins) ~= "number" or coins ~= coins then
		return
	end
	local camera = workspace.CurrentCamera
	if camera and (camera.CFrame.Position - position).Magnitude > MAX_DISTANCE then
		return
	end
	Effects.FloatText(position, "+$" .. Format.Number(coins), UiKit.Colors.Gold)
end

function Zones.Start(ctx)
	Remotes:WaitForChild("Fx").OnClientEvent:Connect(function(kind, data)
		if kind == "Pickup" and type(data) == "table" then
			onPickup(data)
		end
	end)

	ProximityPromptService.PromptShown:Connect(function(prompt)
		local key = PROMPT_TEXT[prompt.Name]
		if key then
			prompt.ActionText = Locale.T(key)
		end
	end)

	-- Стол обмена: открываем выбор игрока (запрос, проверки и сам обмен — на сервере, TradeService)
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt.Name == "TradePrompt" then
			ctx.Open("TradePick", true)
		end
	end)
end

return Zones
