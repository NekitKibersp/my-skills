-- Строит карту кодом: земля, «красная дорожка» мемов, 8 баз игроков, сезонный декор,
-- точка появления и стены-границы. Зоны (башня, площадь, парк, пещера, хаб телепортов) строит ZoneBuilder.
-- В режиме редактирования Studio мир пустой — он появляется по Play.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local ZoneBuilder = require(script.Parent.ZoneBuilder)

local MapBuilder = {}

MapBuilder.CARPET_LENGTH = 360
MapBuilder.CARPET_WIDTH = 16
MapBuilder.CarpetStart = Vector3.new(-MapBuilder.CARPET_LENGTH / 2, 1, 0)
MapBuilder.CarpetEnd = Vector3.new(MapBuilder.CARPET_LENGTH / 2, 1, 0)
MapBuilder.PLOT_SIZE = Vector3.new(80, 1, 72)
MapBuilder.HALF_X = 420 -- граница карты по X (дорожка и базы — в центре, зоны — по краям)
MapBuilder.HALF_Z = 160

local PLOT_X = { -135, -45, 45, 135 }
local PLOT_Z = 64

-- Этажи базы (координаты в системе базы: -Z — вход со стороны дорожки, +Z — задняя стена).
-- Этажи 2–3 — платформы над задними 2/3 базы (z от UPPER_FRONT_Z до задней стены), спереди
-- остаётся открытый двор с входом. Пандус на 2-й этаж — во дворе вдоль правой (+X) стены,
-- пандус на 3-й — на 2-м этаже вдоль левой (-X) стены (над ним в полу 3-го этажа проём).
local UPPER_FRONT_Z = -12
local LANE_X = 33 -- от |x| = 33 до стены (40) — полосы пандусов
local RAMP_WIDTH = 6.2
local RAMP_LENGTH = 24 -- подъём 14 на 24 studs ≈ 30°
local RAMP2_START_Z = -6 -- низ пандуса на 3-й этаж (перед ним площадка 6 studs)
local RAIL_HEIGHT = 3

-- Слоты: на каждом этаже сетка 4 × 3, слоты геймпасса — ряд из 6 на 1-м этаже перед сеткой
local SLOT_COLUMNS = 4
local SLOT_SPACING_X = 14
local SLOT_ROWS_Z = { 30, 19.5, 9 } -- от задней стены к входу
local PASS_ROW_Z = -2
local PASS_SPACING_X = 11
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
	snow.Rate = 150 -- частиц на всю (большую) карту; больше — тяжело для телефонов
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

-- Высота верха пола этажа в системе базы (верх пола 1-го этажа = 0.5)
local function floorTop(floor: number): number
	return MapBuilder.PLOT_SIZE.Y / 2 + Config.Plot.Floors[floor].Height
end

-- Центр слота в системе базы (номера — см. Config.Plot)
local function slotLocalPosition(index: number): Vector3
	local perFloor = Config.Plot.FloorSlots
	local floorSlots = #Config.Plot.Floors * perFloor
	if index > floorSlots then
		local k = index - floorSlots - 1
		return Vector3.new((k - (Config.Plot.PassSlots - 1) / 2) * PASS_SPACING_X, floorTop(1) + 0.1, PASS_ROW_Z)
	end
	local floor = Config.FloorOfSlot(index)
	local i = (index - 1) % perFloor
	local column = i % SLOT_COLUMNS
	local row = i // SLOT_COLUMNS + 1
	return Vector3.new((column - (SLOT_COLUMNS - 1) / 2) * SLOT_SPACING_X, floorTop(floor) + 0.1, SLOT_ROWS_Z[row] or SLOT_ROWS_Z[#SLOT_ROWS_Z])
end

-- Наклонная плита (пандус/перила): верхняя грань идёт от from до to (в системе базы)
local function slope(origin: CFrame, from: Vector3, to: Vector3, thickness: number, lift: number): CFrame
	local mid = (from + to) / 2
	return origin * CFrame.lookAt(mid, to) * CFrame.new(0, lift - thickness / 2, 0)
end

-- Барьер закрытого этажа: полупрозрачный блок над пандусом с табличкой «🔒 Rebirth N».
-- Включает/выключает PlotService (по перерождениям хозяина базы).
local function buildFloorLock(floor: number, cframe: CFrame, size: Vector3, parent: Instance)
	local barrier = part({
		Name = "FloorLock" .. floor,
		Size = size,
		CFrame = cframe,
		Color = Color3.fromRGB(255, 80, 120),
		Material = Enum.Material.ForceField,
		Transparency = 0.3,
		CanCollide = true,
		Parent = parent,
	})
	barrier:SetAttribute("Floor", floor)
	barrier:SetAttribute("UnlockRebirth", Config.Plot.Floors[floor].UnlockRebirth)
	local gui = Instance.new("BillboardGui")
	gui.Name = "LockGui"
	gui.Size = UDim2.fromScale(12, 3)
	gui.StudsOffset = Vector3.new(0, size.Y / 2 + 2, 0)
	gui.MaxDistance = 140
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.2
	label.Text = "🔒 Rebirth " .. Config.Plot.Floors[floor].UnlockRebirth
	label.Parent = gui
	gui.Parent = barrier
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
	plot:SetAttribute("FloorsUnlocked", 1)

	-- lookAt: LookVector смотрит на дорожку, значит «вперёд» в локальных координатах — это -Z.
	local origin = CFrame.lookAt(center, center + front)
	local size = MapBuilder.PLOT_SIZE
	local hue = (index - 1) / 8
	local floors = Config.Plot.Floors
	local topHeight = floors[#floors].Height

	local floor = part({
		Name = "Floor",
		Size = size,
		CFrame = origin,
		Color = Color3.fromHSV(hue, 0.35, 0.45),
		Material = Enum.Material.WoodPlanks,
		Parent = plot,
	})
	plot.PrimaryPart = floor
	local upperColor = Color3.fromHSV(hue, 0.3, 0.5)
	local railColor = Color3.fromHSV(hue, 0.25, 0.85)

	local wallColor = Color3.fromHSV(hue, 0.5, 0.3)
	local wallHeight = size.Y / 2 + topHeight + 8 -- до верхнего этажа + высота перил с запасом
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

	-- ===== Этажи 2..N: платформы над задней частью базы =====
	local upperDepth = size.Z / 2 - UPPER_FRONT_Z
	local upperCenterZ = (UPPER_FRONT_Z + size.Z / 2) / 2
	local railZ = UPPER_FRONT_Z + 0.2
	for floorIndex = 2, #floors do
		local top = floorTop(floorIndex)
		local holeLeft = floorIndex >= 3 -- в полу 3-го этажа проём над пандусом со 2-го
		local leftX = if holeLeft then -LANE_X else -size.X / 2
		local platform = part({
			Name = "Floor" .. floorIndex,
			Size = Vector3.new(size.X / 2 - leftX, 1, upperDepth),
			CFrame = origin * CFrame.new((leftX + size.X / 2) / 2, top - 0.5, upperCenterZ),
			Color = upperColor,
			Material = Enum.Material.WoodPlanks,
			Parent = plot,
		})
		platform:SetAttribute("SkinFloor", true)
		platform:SetAttribute("Floor", floorIndex)
		if holeLeft then
			-- Кусок пола за проёмом: сюда выходит пандус
			local landingStart = RAMP2_START_Z + RAMP_LENGTH
			local landing = part({
				Name = "Floor" .. floorIndex .. "Landing",
				Size = Vector3.new(size.X / 2 - LANE_X, 1, size.Z / 2 - landingStart),
				CFrame = origin * CFrame.new(-(size.X / 2 + LANE_X) / 2, top - 0.5, (landingStart + size.Z / 2) / 2),
				Color = upperColor,
				Material = Enum.Material.WoodPlanks,
				Parent = plot,
			})
			landing:SetAttribute("SkinFloor", true)
			landing:SetAttribute("Floor", floorIndex)
			-- Перила вдоль проёма
			part({
				Name = "Railing",
				Size = Vector3.new(0.4, RAIL_HEIGHT, landingStart - UPPER_FRONT_Z),
				CFrame = origin * CFrame.new(-LANE_X + 0.2, top + RAIL_HEIGHT / 2, (UPPER_FRONT_Z + landingStart) / 2),
				Color = railColor,
				Parent = plot,
			})
		end
		-- Перила по переднему краю: на 2-м этаже — кроме места, куда выходит пандус (+X),
		-- на 3-м — кроме проёма (-X)
		local railFrom = if holeLeft then -LANE_X else -size.X / 2
		local railTo = if holeLeft then size.X / 2 else LANE_X - 0.3
		part({
			Name = "Railing",
			Size = Vector3.new(railTo - railFrom, RAIL_HEIGHT, 0.4),
			CFrame = origin * CFrame.new((railFrom + railTo) / 2, top + RAIL_HEIGHT / 2, railZ),
			Color = railColor,
			Parent = plot,
		})
	end

	-- ===== Пандусы =====
	local laneCenter = (LANE_X + size.X / 2 - 0.75) / 2 -- середина между перилами и внутренней гранью стены
	local ramps = {
		-- на 2-й этаж: во дворе вдоль +X стены, от входа до края 2-го этажа
		{ X = laneCenter, FromZ = UPPER_FRONT_Z - RAMP_LENGTH, Floor = 2 },
		-- на 3-й этаж: на 2-м этаже вдоль -X стены
		{ X = -laneCenter, FromZ = RAMP2_START_Z, Floor = 3 },
	}
	for _, ramp in ramps do
		if not floors[ramp.Floor] then
			continue
		end
		local bottom = floorTop(ramp.Floor - 1)
		local top = floorTop(ramp.Floor)
		local from = Vector3.new(ramp.X, bottom, ramp.FromZ)
		local to = Vector3.new(ramp.X, top, ramp.FromZ + RAMP_LENGTH)
		local length = (to - from).Magnitude
		local stairs = part({
			Name = "Stairs",
			Size = Vector3.new(RAMP_WIDTH, 1, length),
			CFrame = slope(origin, from, to, 1, 0),
			Color = upperColor,
			Material = Enum.Material.DiamondPlate,
			Parent = plot,
		})
		stairs:SetAttribute("SkinFloor", true)
		stairs:SetAttribute("Floor", ramp.Floor)
		-- Перила со стороны базы (у стены их заменяет стена). Нижняя треть открыта:
		-- на пандус можно зайти и сбоку, не обходя перила
		local inner = if ramp.X > 0 then LANE_X - 0.2 else -LANE_X + 0.2
		local railFrom = from:Lerp(to, 0.3)
		part({
			Name = "Railing",
			Size = Vector3.new(0.4, RAIL_HEIGHT, length * 0.7),
			CFrame = slope(origin, Vector3.new(inner, railFrom.Y, railFrom.Z), Vector3.new(inner, top, to.Z), RAIL_HEIGHT, RAIL_HEIGHT),
			Color = railColor,
			Parent = plot,
		})
		-- Барьер закрытого этажа: накрывает весь пандус (обойти сбоку или перепрыгнуть нельзя)
		local lockBottom = bottom
		local lockTop = top + 7.5
		buildFloorLock(
			ramp.Floor,
			origin * CFrame.new(ramp.X, (lockBottom + lockTop) / 2, ramp.FromZ + RAMP_LENGTH / 2),
			Vector3.new(size.X / 2 - LANE_X + 0.3, lockTop - lockBottom, RAMP_LENGTH),
			plot
		)
	end

	-- Табличка над входом (SurfaceGui рисует клиент, Face = Front смотрит на дорожку)
	part({
		Name = "Sign",
		Size = Vector3.new(31, 6, 1),
		CFrame = origin * CFrame.new(0, 16, -size.Z / 2),
		Color = Color3.fromRGB(25, 20, 35),
		Parent = plot,
	})

	-- Силовой щит на входе: виден, когда база закрыта (во всю ширину и высоту базы)
	part({
		Name = "Shield",
		Size = Vector3.new(size.X - 1.5, wallHeight, 0.4),
		CFrame = origin * CFrame.new(0, wallHeight / 2, -size.Z / 2 + 0.3),
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
		slot:SetAttribute("Floor", Config.FloorOfSlot(slotIndex))
		slot:SetAttribute("Unlocked", false)
	end

	-- Кнопка замка: во дворе у входа, левее пандуса на 2-й этаж
	local lockButton = part({
		Name = "LockButton",
		Size = Vector3.new(4, 3, 4),
		CFrame = origin * CFrame.new(LANE_X - 9, 1.5, -size.Z / 2 + 6),
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
	-- Страж — во дворе между спавном и пандусом на 2-й этаж: воры с верхних этажей
	-- спускаются только по этому пандусу (x > 33), иначе страж в -X углу их не достаёт
	guardSpot.Position = Vector3.new(14, size.Y / 2, -size.Z / 2 + 10)
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

-- Строит мир. Возвращает { Plots = { Model }, Leaderboards = { Earned = Part, Stolen = Part }, Zones = (см. ZoneBuilder.Build) }.
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
	for _ = 1, 40 do
		local x = random:NextNumber(-halfX, halfX)
		local z = random:NextNumber(halfZ - 25, halfZ) * (if random:NextNumber() < 0.5 then -1 else 1)
		local position = Vector3.new(x, 0.5, z)
		if ZoneBuilder.IsFree(position) then
			seasonal(position, random:NextNumber(2, 5))
		end
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

	local zones = ZoneBuilder.Build(map, season, spawnLocation.Position)

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

	return { Plots = plots, Leaderboards = { Earned = earned, Stolen = stolen }, Zones = zones }
end

return MapBuilder
