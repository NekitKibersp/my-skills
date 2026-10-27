-- Строит всю карту кодом при запуске сервера: зоны, ворота, кристаллы, спавн и точку продажи.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local MapBuilder = {}

local SIZE = Config.ZoneSize
local ZONE_COUNT = #Config.Zones
local SPAWN_Z = -SIZE / 2 + 18

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		if key ~= "Parent" then
			(p :: any)[key] = value
		end
	end
	p.Parent = props.Parent
	return p
end

local function billboard(parent: Instance, text: string, color: Color3, offset: Vector3, size: UDim2)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = size
	gui.StudsOffset = offset
	gui.MaxDistance = 150
	gui.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.Text = text
	label.Parent = gui
	return gui
end

local function zoneCenterZ(index: number): number
	return (index - 1) * SIZE
end

local function setupLighting()
	Lighting.ClockTime = 14
	Lighting.Brightness = 2
	Lighting.GlobalShadows = true
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 140, 150)

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.3
	atmosphere.Haze = 1
	atmosphere.Parent = Lighting
end

local function buildBounds(parent: Instance)
	local length = ZONE_COUNT * SIZE
	local middleZ = (length - SIZE) / 2
	local wall = { Transparency = 1, Parent = parent }

	for _, side in { -1, 1 } do
		local w = part(table.clone(wall))
		w.Size = Vector3.new(2, 200, length)
		w.Position = Vector3.new(side * (SIZE / 2 + 1), 100, middleZ)
	end

	local back = part(table.clone(wall))
	back.Size = Vector3.new(SIZE, 200, 2)
	back.Position = Vector3.new(0, 100, -SIZE / 2 - 1)

	local front = part(table.clone(wall))
	front.Size = Vector3.new(SIZE, 200, 2)
	front.Position = Vector3.new(0, 100, length - SIZE / 2 + 1)
end

local function buildDecor(zoneIndex: number, random: Random, parent: Instance)
	local zone = Config.Zones[zoneIndex]
	local centerZ = zoneCenterZ(zoneIndex)

	local function randomEdgePosition(): Vector3
		-- Декор ставим ближе к краям, чтобы он не мешал добыче.
		local x = random:NextNumber(SIZE / 2 - 18, SIZE / 2 - 4) * (if random:NextNumber() < 0.5 then -1 else 1)
		local z = centerZ + random:NextNumber(-SIZE / 2 + 6, SIZE / 2 - 6)
		return Vector3.new(x, 0, z)
	end

	for _ = 1, 14 do
		local pos = randomEdgePosition()
		if zone.Decor == "Trees" then
			local trunkHeight = random:NextNumber(8, 12)
			part({
				Size = Vector3.new(2, trunkHeight, 2),
				Position = pos + Vector3.new(0, trunkHeight / 2, 0),
				Color = Color3.fromRGB(105, 70, 40),
				Material = Enum.Material.Wood,
				Parent = parent,
			})
			part({
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * random:NextNumber(8, 11),
				Position = pos + Vector3.new(0, trunkHeight + 2, 0),
				Color = Color3.fromRGB(60, 140, 55),
				Material = Enum.Material.Grass,
				Parent = parent,
			})
		elseif zone.Decor == "Rocks" then
			local size = random:NextNumber(5, 12)
			part({
				Size = Vector3.new(size, size * 0.8, size),
				CFrame = CFrame.new(pos + Vector3.new(0, size * 0.3, 0))
					* CFrame.Angles(random:NextNumber(0, 1), random:NextNumber(0, 3), random:NextNumber(0, 1)),
				Color = Color3.fromRGB(65, 60, 70),
				Material = Enum.Material.Rock,
				Parent = parent,
			})
		elseif zone.Decor == "Lava" then
			local size = random:NextNumber(10, 18)
			part({
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.4, size, size),
				CFrame = CFrame.new(pos + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90)),
				Color = Color3.fromRGB(255, 100, 20),
				Material = Enum.Material.Neon,
				CanCollide = false,
				Parent = parent,
			})
		elseif zone.Decor == "Stars" then
			part({
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * random:NextNumber(1, 3),
				Position = pos + Vector3.new(0, random:NextNumber(15, 45), 0),
				Color = Color3.fromRGB(255, 255, 220),
				Material = Enum.Material.Neon,
				CanCollide = false,
				Parent = parent,
			})
		end
	end
end

local function buildCrystals(zoneIndex: number, random: Random, parent: Instance, createCrystal)
	local zone = Config.Zones[zoneIndex]
	local centerZ = zoneCenterZ(zoneIndex)
	local placed: { Vector3 } = {}
	local half = SIZE / 2 - 22

	local attempts = 0
	while #placed < zone.CrystalCount and attempts < 500 do
		attempts += 1
		local pos = Vector3.new(random:NextNumber(-half, half), 0, centerZ + random:NextNumber(-half, half))

		-- Не ставим кристаллы на спавн, точку продажи и вплотную друг к другу.
		local tooClose = zoneIndex == 1 and pos.Z < SPAWN_Z + 25
		for _, other in placed do
			if (other - pos).Magnitude < 12 then
				tooClose = true
				break
			end
		end

		if not tooClose then
			table.insert(placed, pos)
			createCrystal(zoneIndex, pos, random, parent)
		end
	end
end

local function buildGate(zoneIndex: number, parent: Instance, onGate)
	local zone = Config.Zones[zoneIndex]
	local gate = part({
		Name = "Gate" .. zoneIndex,
		Size = Vector3.new(SIZE, 30, 2),
		Position = Vector3.new(0, 15, zoneCenterZ(zoneIndex) - SIZE / 2),
		Color = zone.CrystalColor,
		Material = Enum.Material.ForceField,
		Transparency = 0.2,
		Parent = parent,
	})
	gate:SetAttribute("Zone", zoneIndex)

	billboard(
		gate,
		("🔒 %s ×%d\n%s монет"):format(zone.Name, zone.Multiplier, Format.Number(zone.Price)),
		Color3.new(1, 1, 1),
		Vector3.new(0, 4, 0),
		UDim2.fromScale(30, 9)
	)

	local attachment = Instance.new("Attachment")
	attachment.Position = Vector3.new(0, -12, -1.5)
	attachment.Parent = gate

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Открыть за " .. Format.Number(zone.Price)
	prompt.ObjectText = zone.Name
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = attachment

	prompt.Triggered:Connect(function(player)
		onGate(player, zoneIndex)
	end)
end

local function buildSellPad(parent: Instance, onSell)
	local pad = part({
		Name = "SellPad",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, 14, 14),
		CFrame = CFrame.new(-28, 0.5, SPAWN_Z + 6) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(60, 220, 100),
		Material = Enum.Material.Neon,
		Parent = parent,
	})
	billboard(pad, "💰 ПРОДАТЬ", Color3.fromRGB(120, 255, 150), Vector3.new(0, 6, 0), UDim2.fromScale(14, 4))

	pad.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if player then
			onSell(player)
		end
	end)
end

local function buildSpawn(parent: Instance)
	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.Position = Vector3.new(0, 0.5, SPAWN_Z)
	spawn.Color = Color3.fromRGB(240, 240, 240)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = parent

	local sign = part({
		Size = Vector3.new(1, 1, 1),
		Position = Vector3.new(0, 0.5, SPAWN_Z - 5),
		Transparency = 1,
		CanCollide = false,
		Parent = parent,
	})
	billboard(
		sign,
		"⛏ СИМУЛЯТОР КРИСТАЛЛОВ\nБей кристаллы → продавай руду → прокачивайся",
		Color3.fromRGB(255, 230, 120),
		Vector3.new(0, 9, 0),
		UDim2.fromScale(36, 8)
	)
end

-- callbacks: { createCrystal = fn(zoneIndex, position, random, parent), onSell = fn(player), onGate = fn(player, zoneIndex) }
function MapBuilder.Build(callbacks)
	setupLighting()

	local map = Instance.new("Folder")
	map.Name = "Map"

	local crystalsFolder = Instance.new("Folder")
	crystalsFolder.Name = "Crystals"
	crystalsFolder.Parent = map

	local gatesFolder = Instance.new("Folder")
	gatesFolder.Name = "Gates"
	gatesFolder.Parent = map

	local decorFolder = Instance.new("Folder")
	decorFolder.Name = "Decor"
	decorFolder.Parent = map

	local random = Random.new(2026)

	for index, zone in Config.Zones do
		part({
			Name = "Ground" .. index,
			Size = Vector3.new(SIZE, 2, SIZE),
			Position = Vector3.new(0, -1, zoneCenterZ(index)),
			Color = zone.GroundColor,
			Material = zone.GroundMaterial,
			Parent = map,
		})

		buildDecor(index, random, decorFolder)
		buildCrystals(index, random, crystalsFolder, callbacks.createCrystal)
		if index > 1 then
			buildGate(index, gatesFolder, callbacks.onGate)
		end
	end

	buildBounds(map)
	buildSpawn(map)
	buildSellPad(map, callbacks.onSell)

	map.Parent = workspace
end

return MapBuilder
