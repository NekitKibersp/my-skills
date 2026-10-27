-- Точка входа сервера: строит карту и запускает сервисы.
local Players = game:GetService("Players")

local DataService = require(script.DataService)
local MapBuilder = require(script.MapBuilder)
local MiningService = require(script.MiningService)
local ShopService = require(script.ShopService)

DataService.Start()
MiningService.Start()
ShopService.Start()

MapBuilder.Build({
	createCrystal = MiningService.CreateCrystal,
	onSell = ShopService.Sell,
	onGate = ShopService.UnlockZone,
})

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function()
		MiningService.GiveTool(player)
	end)

	DataService.Load(player)

	-- Персонаж мог появиться раньше, чем загрузились данные.
	if player.Character then
		MiningService.GiveTool(player)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end
