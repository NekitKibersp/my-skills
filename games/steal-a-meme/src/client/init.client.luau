-- Точка входа клиента: строит UI и подписывается на атрибуты игрока.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Format"))
local UiKit = require(script:WaitForChild("UiKit"))

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local gui = UiKit.screen("GameUi")
local toast = UiKit.toaster(gui)
Remotes:WaitForChild("Notify").OnClientEvent:Connect(toast)

local coinsLabel = UiKit.text({
	Position = UDim2.new(0, 12, 0, 12),
	Size = UDim2.new(0, 220, 0, 40),
	BackgroundTransparency = 0.15,
	BackgroundColor3 = UiKit.Colors.Panel,
	TextSize = 24,
	TextColor3 = UiKit.Colors.Gold,
	Parent = gui,
})
UiKit.corner(12).Parent = coinsLabel
UiKit.padding(8).Parent = coinsLabel

local function render()
	coinsLabel.Text = "💰 " .. Format.Number(player:GetAttribute("Coins") or 0)
end

player:GetAttributeChangedSignal("Coins"):Connect(render)
render()
