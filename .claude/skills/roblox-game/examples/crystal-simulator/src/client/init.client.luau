-- Точка входа клиента: интерфейс, всплывающие цифры добычи и открытые ворота.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Format = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Format"))
local Ui = require(script:WaitForChild("Ui"))

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

Ui.Start()

-- «+N» над кристаллом после удара
Remotes.Mined.OnClientEvent:Connect(function(amount: number, position: Vector3)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one * 0.2
	anchor.Position = position + Vector3.new(math.random(-10, 10) / 10, 0, math.random(-10, 10) / 10)
	anchor.Parent = workspace

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(120, 40)
	gui.AlwaysOnTop = true
	gui.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = "+" .. Format.Number(amount) .. " 💎"
	label.TextColor3 = Color3.fromRGB(120, 210, 255)
	label.TextStrokeTransparency = 0
	label.Parent = gui

	local info = TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(anchor, info, { Position = anchor.Position + Vector3.new(0, 4, 0) }):Play()
	TweenService:Create(label, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(0.9, anchor.Destroy, anchor)
end)

-- Открытые зоны: делаем ворота проходимыми только для этого игрока.
local gates = workspace:WaitForChild("Map"):WaitForChild("Gates")

local function refreshGate(gate: Instance)
	if not gate:IsA("BasePart") then
		return
	end
	local unlocked = (gate:GetAttribute("Zone") or math.huge) <= (player:GetAttribute("MaxZone") or 1)
	gate.CanCollide = not unlocked
	gate.Transparency = if unlocked then 1 else 0.2

	local label = gate:FindFirstChild("Label")
	if label then
		label.Enabled = not unlocked
	end
	local prompt = gate:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt then
		prompt.Enabled = not unlocked
	end
end

local function refreshGates()
	for _, gate in gates:GetChildren() do
		refreshGate(gate)
	end
end

gates.ChildAdded:Connect(refreshGate) -- при StreamingEnabled ворота подгружаются позже
player:GetAttributeChangedSignal("MaxZone"):Connect(refreshGates)
refreshGates()
