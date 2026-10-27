-- Кирки, кристаллы и добыча руды. Вся проверка ударов идёт на сервере.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local DataService = require(script.Parent.DataService)
local Remotes = require(script.Parent.Remotes)

local MiningService = {}

local crystals: { BasePart } = {}
local lastSwing: { [Player]: number } = {}
local lastFullWarning: { [Player]: number } = {}

local function updateHealthBar(crystal: BasePart)
	local gui = crystal:FindFirstChild("HealthGui") :: BillboardGui
	local hp = crystal:GetAttribute("HP")
	local maxHp = crystal:GetAttribute("MaxHP")
	gui.Bar.Fill.Size = UDim2.fromScale(math.clamp(hp / maxHp, 0, 1), 1)
	gui.Bar.Label.Text = Format.Number(hp) .. " / " .. Format.Number(maxHp)
end

local function setBroken(crystal: BasePart, broken: boolean)
	crystal:SetAttribute("Broken", broken)
	crystal.Transparency = if broken then 1 else 0.15
	crystal.CanCollide = not broken
	crystal.CanQuery = not broken
	crystal.PointLight.Enabled = not broken
	crystal.HealthGui.Enabled = not broken
end

function MiningService.CreateCrystal(zoneIndex: number, position: Vector3, random: Random, parent: Instance)
	local zone = Config.Zones[zoneIndex]
	local height = random:NextNumber(4, 7)

	local crystal = Instance.new("Part")
	crystal.Name = "Crystal"
	crystal.Anchored = true
	crystal.Size = Vector3.new(height * 0.55, height, height * 0.55)
	crystal.CFrame = CFrame.new(position + Vector3.new(0, height / 2 - 0.5, 0))
		* CFrame.Angles(0, random:NextNumber(0, math.pi), math.rad(random:NextNumber(-12, 12)))
	crystal.Color = zone.CrystalColor
	crystal.Material = Enum.Material.Neon
	crystal.Transparency = 0.15
	crystal:SetAttribute("Zone", zoneIndex)
	crystal:SetAttribute("MaxHP", zone.CrystalHP)
	crystal:SetAttribute("HP", zone.CrystalHP)
	crystal:SetAttribute("Broken", false)
	crystal:SetAttribute("BaseSize", crystal.Size)

	local light = Instance.new("PointLight")
	light.Color = zone.CrystalColor
	light.Range = 10
	light.Brightness = 1.5
	light.Parent = crystal

	local particles = Instance.new("ParticleEmitter")
	particles.Name = "Shards"
	particles.Enabled = false
	particles.Color = ColorSequence.new(zone.CrystalColor)
	particles.LightEmission = 1
	particles.Size = NumberSequence.new(0.6, 0)
	particles.Lifetime = NumberRange.new(0.5, 0.9)
	particles.Speed = NumberRange.new(15, 25)
	particles.SpreadAngle = Vector2.new(180, 180)
	particles.Acceleration = Vector3.new(0, -40, 0)
	particles.Parent = crystal

	local gui = Instance.new("BillboardGui")
	gui.Name = "HealthGui"
	gui.Size = UDim2.fromOffset(110, 18)
	gui.StudsOffset = Vector3.new(0, height / 2 + 1.5, 0)
	gui.MaxDistance = 40
	gui.Parent = crystal

	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.Size = UDim2.fromScale(1, 1)
	bar.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
	bar.Parent = gui
	Instance.new("UICorner").Parent = bar

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = zone.CrystalColor
	fill.Parent = bar
	Instance.new("UICorner").Parent = fill

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.ZIndex = 2
	label.Parent = bar

	updateHealthBar(crystal)
	crystal.Parent = parent
	table.insert(crystals, crystal)
	return crystal
end

local function findNearestCrystal(position: Vector3, maxZone: number): BasePart?
	local nearest, nearestDistance = nil, math.huge
	for _, crystal in crystals do
		if crystal:GetAttribute("Broken") or crystal:GetAttribute("Zone") > maxZone then
			continue
		end
		local reach = Config.MineRange + crystal.Size.Magnitude / 2
		local distance = (crystal.Position - position).Magnitude
		if distance <= reach and distance < nearestDistance then
			nearest, nearestDistance = crystal, distance
		end
	end
	return nearest
end

local function breakCrystal(crystal: BasePart)
	crystal.Shards:Emit(30)
	setBroken(crystal, true)
	task.delay(Config.CrystalRespawn, function()
		crystal:SetAttribute("HP", crystal:GetAttribute("MaxHP"))
		updateHealthBar(crystal)
		setBroken(crystal, false)
	end)
end

local function pulse(crystal: BasePart)
	local baseSize = crystal:GetAttribute("BaseSize")
	crystal.Size = baseSize * 0.85
	TweenService:Create(crystal, TweenInfo.new(0.15, Enum.EasingStyle.Back), { Size = baseSize }):Play()
end

local function hitCrystal(player: Player, crystal: BasePart, power: number)
	local capacity = Config.Backpacks[DataService.Get(player, "BackpackTier")].Capacity
	local space = capacity - DataService.Get(player, "Ore")
	if space <= 0 then
		local now = os.clock()
		if now - (lastFullWarning[player] or 0) > 2 then
			lastFullWarning[player] = now
			Remotes.Notify:FireClient(player, "Рюкзак полон! Продай руду на зелёной площадке у спавна.", "error")
		end
		return
	end

	local zone = Config.Zones[crystal:GetAttribute("Zone")]
	local multiplier = Config.Multiplier(DataService.Get(player, "Rebirths")) * zone.Multiplier
	local hp = crystal:GetAttribute("HP") - power
	local gain = power * multiplier

	if hp <= 0 then
		gain += crystal:GetAttribute("MaxHP") * multiplier
		breakCrystal(crystal)
	else
		crystal:SetAttribute("HP", hp)
		updateHealthBar(crystal)
		pulse(crystal)
	end

	local added = math.min(math.floor(gain), space)
	DataService.Increment(player, "Ore", added)
	DataService.Increment(player, "TotalOre", added)
	Remotes.Mined:FireClient(player, added, crystal.Position + Vector3.new(0, crystal.Size.Y / 2, 0))
end

local function onActivated(player: Player, tool: Tool)
	if not DataService.IsLoaded(player) then
		return
	end

	local info = Config.Tools[DataService.Get(player, "ToolTier")]
	local now = os.clock()
	if now - (lastSwing[player] or 0) < info.Cooldown then
		return
	end
	lastSwing[player] = now

	-- Стандартный Animate-скрипт проигрывает взмах, когда в инструменте появляется toolanim.
	local anim = Instance.new("StringValue")
	anim.Name = "toolanim"
	anim.Value = "Slash"
	anim.Parent = tool
	Debris:AddItem(anim, 1)

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end

	local crystal = findNearestCrystal(root.Position, DataService.Get(player, "MaxZone"))
	if crystal then
		hitCrystal(player, crystal, info.Power)
	end
end

local function makeTool(player: Player, tier: number): Tool
	local info = Config.Tools[tier]

	local tool = Instance.new("Tool")
	tool.Name = info.Name
	tool.ToolTip = "Сила " .. info.Power
	tool.CanBeDropped = false
	tool.Grip = CFrame.new(0, 0, -1.2)
	tool:SetAttribute("Pickaxe", true)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.3, 0.3, 3.2)
	handle.Color = Color3.fromRGB(110, 75, 45)
	handle.Material = Enum.Material.Wood
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(0.45, 2.6, 0.45)
	head.Color = info.Color
	head.Material = info.Material
	head.CanCollide = false
	head.Massless = true
	head.Parent = tool

	local weld = Instance.new("Weld")
	weld.Part0 = handle
	weld.Part1 = head
	weld.C0 = CFrame.new(0, 0, 1.5)
	weld.Parent = handle

	tool.Activated:Connect(function()
		onActivated(player, tool)
	end)

	return tool
end

function MiningService.GiveTool(player: Player)
	if not DataService.IsLoaded(player) then
		return
	end

	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end

	for _, container in { backpack, player.Character } do
		if not container then
			continue
		end
		for _, item in container:GetChildren() do
			if item:IsA("Tool") and item:GetAttribute("Pickaxe") then
				item:Destroy()
			end
		end
	end

	local tool = makeTool(player, DataService.Get(player, "ToolTier"))
	tool.Parent = backpack

	-- Сразу берём кирку в руки, если персонаж уже есть.
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:EquipTool(tool)
	end
end

function MiningService.Start()
	DataService.Changed:Connect(function(player, key)
		if key == "ToolTier" then
			MiningService.GiveTool(player)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastSwing[player] = nil
		lastFullWarning[player] = nil
	end)
end

return MiningService
