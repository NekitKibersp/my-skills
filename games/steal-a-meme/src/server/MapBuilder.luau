-- Строит карту кодом: земля, «красная дорожка» мемов, 8 баз игроков, декор Хэллоуина,
-- точка появления и стены-границы. В режиме редактирования Studio мир пустой — он появляется по Play.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local MapBuilder = {}

MapBuilder.CARPET_LENGTH = 360
MapBuilder.CARPET_WIDTH = 16
MapBuilder.CarpetStart = Vector3.new(-MapBuilder.CARPET_LENGTH / 2, 1, 0)
MapBuilder.CarpetEnd = Vector3.new(MapBuilder.CARPET_LENGTH / 2, 1, 0)
MapBuilder.PLOT_SIZE = Vector3.new(80, 1, 72)
MapBuilder.HALF_X = 230 -- граница карты по X
MapBuilder.HALF_Z = 130

local PLOT_X = { -135, -45, 45, 135 }
local PLOT_Z = 64
local SLOT_COLUMNS = 5
local SLOT_SPACING_X = 14
local SLOT_SPACING_Z = 10.5

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		if key ~= "Parent" then
			(p :: any)[key] = value
		end
	end
	p.Parent = props.Parent
	return p
end

local function setupLighting(winter: boolean)
	Lighting.ClockTime = if winter then 15.5 else 17.2
	Lighting.Brightness = 2.2
	Lighting.Ambient = if winter then Color3.fromRGB(90, 100, 130) else Color3.fromRGB(90, 70, 100)
	Lighting.OutdoorAmbient = if winter then Color3.fromRGB(150, 165, 200) else Color3.fromRGB(150, 120, 140)
	Lighting.GlobalShadows = true
	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local atmosphere = Instance.new("Atmosphere")
		atmosphere.Density = 0.3
		atmosphere.Color = if winter then Color3.fromRGB(200, 220, 255) else Color3.fromRGB(255, 190, 150)
		atmosphere.Decay = if winter then Color3.fromRGB(110, 130, 170) else Color3.fromRGB(120, 70, 110)
		atmosphere.Glare = 0.3
		atmosphere.Haze = 1.2
		atmosphere.Parent = Lighting
	end
	if not Lighting:FindFirstChildOfClass("BloomEffect") then
		local bloom = Instance.new("BloomEffect")
		bloom.Intensity = 0.6
		bloom.Size = 30
		bloom.Threshold = 1.6
		bloom.Parent = Lighting
	end
end

local function buildPumpkin(position: Vector3, size: number, parent: Instance)
	local pumpkin = part({
		Name = "Pumpkin",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(size, size * 0.8, size),
		Color = Color3.fromRGB(255, 125, 20),
		CFrame = CFrame.new(position + Vector3.new(0, size * 0.4, 0)),
		CanCollide = false,
		Parent = parent,
	})
	part({
		Name = "Stem",
		Size = Vector3.new(size * 0.15, size * 0.3, size * 0.15),
		Color = Color3.fromRGB(70, 110, 40),
		CFrame = CFrame.new(position + Vector3.new(0, size * 0.85, 0)),
		CanCollide = false,
		Parent = parent,
	})
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 150, 40)
	light.Range = size * 3
	light.Brightness = 1.2
	light.Parent = pumpkin
end

local function buildSnowman(position: Vector3, size: number, parent: Instance)
	local radii = { size, size * 0.75, size * 0.5 }
	local y = position.Y
	local head: Part? = nil
	for _, radius in radii do
		y += radius * 0.85
		head = part({
			Name = "Snowman",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * radius * 2,
			Color = Color3.fromRGB(245, 250, 255),
			Material = Enum.Material.Snow,
			CFrame = CFrame.new(position.X, y, position.Z),
			CanCollide = false,
			Parent = parent,
		})
		y += radius * 0.85
	end
	if head then
		part({
			Name = "Nose",
			Size = Vector3.new(size * 0.15, size * 0.15, size * 0.6),
			Color = Color3.fromRGB(255, 130, 30),
			CFrame = head.CFrame * CFrame.new(0, 0, -size * 0.6),
			CanCollide = false,
			Parent = parent,
		})
	end
end

local function buildTree(position: Vector3, height: number, random: Random, parent: Instance)
	part({
		Name = "TreeTrunk",
		Size = Vector3.new(1.5, height * 0.25, 1.5),
		Color = Color3.fromRGB(90, 60, 40),
		Material = Enum.Material.Wood,
		CFrame = CFrame.new(position + Vector3.new(0, height * 0.125, 0)),
		Parent = parent,
	})
	for layer = 0, 2 do
		local width = height * (0.7 - layer * 0.18)
		local cone = part({
			Name = "TreeLayer",
			Size = Vector3.new(width, height * 0.3, width),
			Color = Color3.fromRGB(30, 110, 60),
			Material = Enum.Material.Grass,
			CFrame = CFrame.new(position + Vector3.new(0, height * (0.35 + layer * 0.22), 0)) * CFrame.Angles(0, math.rad(layer * 30), 0),
			CanCollide = false,
			Parent = parent,
		})
		local light = Instance.new("PointLight")
		light.Color = Color3.fromHSV(random:NextNumber(), 0.6, 1)
		light.Range = 8
		light.Brightness = 0.8
		light.Parent = cone
	end
	part({
		Name = "TreeStar",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 1.4,
		Color = Color3.fromRGB(255, 220, 60),
		Material = Enum.Material.Neon,
		CFrame = CFrame.new(position + Vector3.new(0, height * 0.95, 0)),
		CanCollide = false,
		Parent = parent,
	})
end

-- Снегопад: большой невидимый «потолок» с частицами
local function buildSnowfall(parent: Instance)
	local sky = part({
		Name = "Snowfall",
		Size = Vector3.new(MapBuilder.HALF_X * 2, 1, MapBuilder.HALF_Z * 2),
		CFrame = CFrame.new(0, 70, 0),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = parent,
	})
	local snow = Instance.new("ParticleEmitter")
	snow.Color = ColorSequence.new(Color3.new(1, 1, 1))
	snow.LightEmission = 0.3
	snow.Size = NumberSequence.new(0.35)
	snow.Rate = 220
	snow.Lifetime = NumberRange.new(9, 12)
	snow.Speed = NumberRange.new(6, 9)
	snow.SpreadAngle = Vector2.new(15, 15)
	snow.EmissionDirection = Enum.NormalId.Bottom
	snow.Parent = sky
end

local function buildLamp(position: Vector3, parent: Instance)
	part({
		Name = "LampPost",
		Size = Vector3.new(0.8, 12, 0.8),
		Color = Color3.fromRGB(40, 35, 50),
		Material = Enum.Material.Metal,
		CFrame = CFrame.new(position + Vector3.new(0, 6, 0)),
		Parent = parent,
	})
	local bulb = part({
		Name = "Bulb",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 2,
		Color = Color3.fromRGB(255, 190, 90),
		Material = Enum.Material.Neon,
		CFrame = CFrame.new(position + Vector3.new(0, 12.5, 0)),
		CanCollide = false,
		Parent = parent,
	})
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 180, 90)
	light.Range = 26
	light.Brightness = 1.6
	light.Parent = bulb
end

local function buildCarpet(map: Instance)
	local length = MapBuilder.CARPET_LENGTH
	part({
		Name = "Carpet",
		Size = Vector3.new(length, 0.4, MapBuilder.CARPET_WIDTH),
		CFrame = CFrame.new(0, 0.7, 0),
		Color = Color3.fromRGB(170, 25, 40),
		Material = Enum.Material.Fabric,
		Parent = map,
	})
	for _, side in { -1, 1 } do
		part({
			Name = "CarpetEdge",
			Size = Vector3.new(length, 0.6, 1),
			CFrame = CFrame.new(0, 0.8, side * (MapBuilder.CARPET_WIDTH / 2 + 0.5)),
			Color = Color3.fromRGB(255, 200, 60),
			Material = Enum.Material.Neon,
			Parent = map,
		})
	end

	-- Портал, из которого выходят мемы
	local portal = part({
		Name = "MemePortal",
		Size = Vector3.new(2, 20, 22),
		CFrame = CFrame.new(MapBuilder.CarpetStart + Vector3.new(-2, 10, 0)),
		Color = Color3.fromRGB(150, 60, 255),
		Material = Enum.Material.Neon,
		Transparency = 0.25,
		CanCollide = false,
		Parent = map,
	})
	local portalParticles = Instance.new("ParticleEmitter")
	portalParticles.Color = ColorSequence.new(Color3.fromRGB(200, 120, 255), Color3.fromRGB(255, 140, 40))
	portalParticles.LightEmission = 1
	portalParticles.Size = NumberSequence.new(1.2, 0)
	portalParticles.Rate = 30
	portalParticles.Lifetime = NumberRange.new(1, 2)
	portalParticles.Speed = NumberRange.new(4, 8)
	portalParticles.EmissionDirection = Enum.NormalId.Right
	portalParticles.Parent = portal
	for _, side in { -1, 1 } do
		part({
			Name = "PortalPillar",
			Size = Vector3.new(4, 24, 4),
			CFrame = CFrame.new(MapBuilder.CarpetStart + Vector3.new(-2, 12, side * 13)),
			Color = Color3.fromRGB(40, 30, 60),
			Material = Enum.Material.Slate,
			Parent = map,
		})
	end
	-- Ворота на выходе дорожки
	part({
		Name = "ExitGate",
		Size = Vector3.new(2, 20, 22),
		CFrame = CFrame.new(MapBuilder.CarpetEnd + Vector3.new(2, 10, 0)),
		Color = Color3.fromRGB(20, 20, 30),
		Material = Enum.Material.Neon,
		Transparency = 0.5,
		CanCollide = false,
		Parent = map,
	})
end

-- Слоты одной базы: 5 колонок × 5 рядов, от задней стены к входу.
local function slotLocalPosition(index: number): Vector3
	local column = (index - 1) % SLOT_COLUMNS
	local row = (index - 1) // SLOT_COLUMNS
	return Vector3.new((column - (SLOT_COLUMNS - 1) / 2) * SLOT_SPACING_X, 0.6, 28 - row * SLOT_SPACING_Z)
end

local function buildPlot(index: number, center: Vector3, front: Vector3, parent: Instance): Model
	local plot = Instance.new("Model")
	plot.Name = "Plot" .. index
	plot.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	plot:SetAttribute("Index", index)
	plot:SetAttribute("OwnerUserId", 0)
	plot:SetAttribute("OwnerName", "")
	plot:SetAttribute("LockedUntil", 0)
	plot:SetAttribute("LockCooldownUntil", 0)

	-- lookAt: LookVector смотрит на дорожку, значит «вперёд» в локальных координатах — это -Z.
	local origin = CFrame.lookAt(center, center + front)
	local size = MapBuilder.PLOT_SIZE
	local hue = (index - 1) / 8

	local floor = part({
		Name = "Floor",
		Size = size,
		CFrame = origin,
		Color = Color3.fromHSV(hue, 0.35, 0.45),
		Material = Enum.Material.WoodPlanks,
		Parent = plot,
	})
	plot.PrimaryPart = floor

	local wallColor = Color3.fromHSV(hue, 0.5, 0.3)
	local wallHeight = 7
	-- Задняя и боковые стены (вход со стороны дорожки открыт)
	part({
		Name = "Wall",
		Size = Vector3.new(size.X, wallHeight, 1.5),
		CFrame = origin * CFrame.new(0, wallHeight / 2, size.Z / 2),
		Color = wallColor,
		Material = Enum.Material.Brick,
		Parent = plot,
	})
	for _, side in { -1, 1 } do
		part({
			Name = "Wall",
			Size = Vector3.new(1.5, wallHeight, size.Z),
			CFrame = origin * CFrame.new(side * size.X / 2, wallHeight / 2, 0),
			Color = wallColor,
			Material = Enum.Material.Brick,
			Parent = plot,
		})
		-- столбы ворот
		part({
			Name = "GatePillar",
			Size = Vector3.new(3, 18, 3),
			CFrame = origin * CFrame.new(side * 17, 9, -size.Z / 2),
			Color = wallColor,
			Material = Enum.Material.Brick,
			Parent = plot,
		})
	end

	-- Табличка над входом (SurfaceGui рисует клиент, Face = Front смотрит на дорожку)
	part({
		Name = "Sign",
		Size = Vector3.new(31, 6, 1),
		CFrame = origin * CFrame.new(0, 16, -size.Z / 2),
		Color = Color3.fromRGB(25, 20, 35),
		Parent = plot,
	})

	-- Силовой щит на входе: виден, когда база закрыта
	part({
		Name = "Shield",
		Size = Vector3.new(31, 14, 0.4),
		CFrame = origin * CFrame.new(0, 7, -size.Z / 2),
		Color = Color3.fromRGB(80, 200, 255),
		Material = Enum.Material.ForceField,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Parent = plot,
	})

	local slots = Instance.new("Folder")
	slots.Name = "Slots"
	slots.Parent = plot
	for slotIndex = 1, Config.AbsoluteMaxSlots do
		local slot = part({
			Name = "Slot" .. slotIndex,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.4, 8, 8),
			CFrame = origin * CFrame.new(slotLocalPosition(slotIndex)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(60, 60, 70),
			Material = Enum.Material.Slate,
			Transparency = 0.6,
			CanCollide = false,
			Parent = slots,
		})
		slot:SetAttribute("Index", slotIndex)
		slot:SetAttribute("Unlocked", false)
	end

	local lockButton = part({
		Name = "LockButton",
		Size = Vector3.new(4, 3, 4),
		CFrame = origin * CFrame.new(size.X / 2 - 8, 1.5, -size.Z / 2 + 8),
		Color = Color3.fromRGB(80, 200, 255),
		Material = Enum.Material.Neon,
		Parent = plot,
	})
	local lockPrompt = Instance.new("ProximityPrompt")
	lockPrompt.Name = "LockPrompt"
	lockPrompt.ActionText = "Lock base"
	lockPrompt.ObjectText = "🔒"
	lockPrompt.RequiresLineOfSight = false
	lockPrompt.MaxActivationDistance = 10
	lockPrompt.Parent = lockButton

	local spawnPoint = part({
		Name = "Spawn",
		Size = Vector3.new(6, 0.2, 6),
		CFrame = origin * CFrame.new(0, 0.6, -size.Z / 2 + 8),
		Color = Color3.fromRGB(255, 255, 255),
		Transparency = 0.7,
		CanCollide = false,
		Parent = plot,
	})
	spawnPoint:SetAttribute("Spawn", true)

	local guardSpot = Instance.new("Attachment")
	guardSpot.Name = "GuardSpot"
	guardSpot.Position = Vector3.new(-(size.X / 2 - 8), size.Y / 2, -size.Z / 2 + 10)
	guardSpot.Parent = floor

	local memes = Instance.new("Folder")
	memes.Name = "Memes"
	memes.Parent = plot

	plot.Parent = parent
	return plot
end

local function buildLeaderboard(name: string, title: string, cframe: CFrame, parent: Instance): Part
	local board = part({
		Name = name,
		Size = Vector3.new(24, 30, 1),
		CFrame = cframe,
		Color = Color3.fromRGB(20, 18, 30),
		Parent = parent,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Board"
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(480, 600)
	gui.LightInfluence = 0
	gui.Parent = board
	local header = Instance.new("TextLabel")
	header.Name = "Title"
	header.Size = UDim2.new(1, 0, 0, 70)
	header.BackgroundColor3 = Color3.fromRGB(150, 60, 255)
	header.TextColor3 = Color3.new(1, 1, 1)
	header.Font = Enum.Font.GothamBlack
	header.TextScaled = true
	header.Text = title
	header.Parent = gui
	local list = Instance.new("TextLabel")
	list.Name = "List"
	list.Position = UDim2.new(0, 16, 0, 80)
	list.Size = UDim2.new(1, -32, 1, -90)
	list.BackgroundTransparency = 1
	list.TextColor3 = Color3.fromRGB(240, 240, 255)
	list.Font = Enum.Font.GothamBold
	list.TextSize = 30
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.Text = "..."
	list.Parent = gui
	return board
end

-- Строит мир. Возвращает { Plots = { Model }, Leaderboards = { Earned = Part, Stolen = Part } }.
-- season: "Halloween" | "Winter" | "None" — от него зависит декор и освещение
function MapBuilder.Build(season: string)
	local winter = season == "Winter"
	setupLighting(winter)

	local map = Instance.new("Folder")
	map.Name = "Map"

	local random = Random.new(67)
	local halfX, halfZ = MapBuilder.HALF_X, MapBuilder.HALF_Z

	part({
		Name = "Ground",
		Size = Vector3.new(halfX * 2 + 40, 2, halfZ * 2 + 40),
		CFrame = CFrame.new(0, -0.5, 0),
		Color = if winter then Color3.fromRGB(235, 240, 250) else Color3.fromRGB(55, 70, 45),
		Material = if winter then Enum.Material.Snow else Enum.Material.Grass,
		Parent = map,
	})

	-- Невидимые стены по краю
	for _, data in {
		{ Vector3.new(0, 50, halfZ + 10), Vector3.new(halfX * 2 + 40, 100, 2) },
		{ Vector3.new(0, 50, -halfZ - 10), Vector3.new(halfX * 2 + 40, 100, 2) },
		{ Vector3.new(halfX + 10, 50, 0), Vector3.new(2, 100, halfZ * 2 + 40) },
		{ Vector3.new(-halfX - 10, 50, 0), Vector3.new(2, 100, halfZ * 2 + 40) },
	} do
		part({ Name = "Boundary", Position = data[1], Size = data[2], Transparency = 1, Parent = map })
	end

	buildCarpet(map)

	-- Центральная точка появления (игрока сразу переносит на его базу)
	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "Spawn"
	spawnLocation.Anchored = true
	spawnLocation.Size = Vector3.new(12, 1, 12)
	spawnLocation.CFrame = CFrame.new(MapBuilder.CarpetEnd.X + 30, 0.5, 0)
	spawnLocation.Duration = 0
	spawnLocation.Color = Color3.fromRGB(150, 60, 255)
	spawnLocation.Material = Enum.Material.Neon
	spawnLocation.Parent = map

	-- Декор по сезону: тыквы (Хэллоуин) или снеговики и ёлки (Зима), фонари вдоль дорожки всегда
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = map
	local function seasonal(position: Vector3, size: number)
		if season == "Halloween" then
			buildPumpkin(position, size, decor)
		elseif winter then
			if random:NextNumber() < 0.5 then
				buildSnowman(position, size * 0.6, decor)
			else
				buildTree(position, size * 3, random, decor)
			end
		end
	end
	for x = -MapBuilder.CARPET_LENGTH / 2 + 10, MapBuilder.CARPET_LENGTH / 2, 30 do
		for _, side in { -1, 1 } do
			buildLamp(Vector3.new(x, 0.5, side * 14), decor)
			seasonal(Vector3.new(x + random:NextNumber(6, 14), 0.5, side * random:NextNumber(12, 18)), random:NextNumber(1.6, 3))
		end
	end
	for _ = 1, 30 do
		local x = random:NextNumber(-halfX, halfX)
		local z = random:NextNumber(halfZ - 25, halfZ) * (if random:NextNumber() < 0.5 then -1 else 1)
		seasonal(Vector3.new(x, 0.5, z), random:NextNumber(2, 5))
	end
	if winter then
		buildSnowfall(decor)
	end

	local leaderboards = Instance.new("Folder")
	leaderboards.Name = "Leaderboards"
	leaderboards.Parent = map
	local boardX = MapBuilder.CarpetEnd.X + 50
	local earned = buildLeaderboard("TopEarned", "💰 Richest / Богачи", CFrame.lookAt(Vector3.new(boardX, 15, -22), Vector3.new(0, 15, -22)), leaderboards)
	local stolen = buildLeaderboard("TopStolen", "🦹 Top Thieves / Воры", CFrame.lookAt(Vector3.new(boardX, 15, 22), Vector3.new(0, 15, 22)), leaderboards)

	map.Parent = workspace

	local plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	local plots = {}
	local index = 0
	for _, side in { 1, -1 } do
		for _, x in PLOT_X do
			index += 1
			-- y = 0.1: верх пола базы чуть выше верха земли (0.5), иначе грани совпадают и мерцают
			local center = Vector3.new(x, 0.1, side * PLOT_Z)
			table.insert(plots, buildPlot(index, center, Vector3.new(0, 0, -side), plotsFolder))
		end
	end
	plotsFolder.Parent = workspace

	return { Plots = plots, Leaderboards = { Earned = earned, Stolen = stolen } }
end

return MapBuilder
