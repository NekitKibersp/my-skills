-- Зоны большой карты кодом (вызывается из MapBuilder.Build): Башня мемов (обби) к востоку от спавна,
-- скалы по восточному краю с секретной пещерой, Торговая площадь (безопасная зона) и Конфетный парк
-- к западу от портала, хаб телепортов у спавна, дорожки между зонами, фонари, скамейки, клумбы
-- и большие таблички с названиями зон. Логика (лава, чекпоинты, призы, пикапы, телепорты) — в ZoneService.
-- Только примитивы, без ID ассетов. Деталей — несколько сотен (телефоны).
local ZoneBuilder = {}

local GROUND_TOP = 0.5 -- верх земли из MapBuilder

-- ===== Раскладка (studs) =====
local TOWER_CENTER = Vector3.new(320, GROUND_TOP, 0)
local TOWER_START = Vector3.new(282, GROUND_TOP, 0) -- стартовая площадка (чекпоинт 1)
local LAVA_HALF = 38 -- лава вокруг башни: квадрат 76×76
local PLAZA_CENTER = Vector3.new(-300, GROUND_TOP, -60)
local PLAZA_SIZE = Vector2.new(80, 70) -- X × Z
local PARK_CENTER = Vector3.new(-300, GROUND_TOP, 75)
local PARK_SIZE = Vector2.new(90, 80)
local CLIFF_X = 396 -- передняя грань скал восточного края
local CLIFF_BACK = 432
local CLIFF_SEGMENT = 8
local CLIFF_FROM_Z = -172
local CAVE_SEGMENTS = { 12, 13, 14 } -- сегменты скалы над пещерой (z от -76 до -52)
local CAVE_FAKE_SEGMENT = 13 -- «фальшивый» кусок стены: проходим насквозь
local CAVE_HEIGHT = 16
local CAVE_DEPTH_END = 428 -- задняя стена пещеры

-- Ярусы башни: радиус спирали, размер платформы, подъём и угол на прыжок
local TIERS = {
	{ Radius = 26, Size = 8, Rise = 2.5, Step = 28, Color = Color3.fromRGB(90, 200, 255) },
	{ Radius = 26, Size = 6, Rise = 2.7, Step = 28, Color = Color3.fromRGB(255, 200, 60) },
	{ Radius = 24, Size = 5, Rise = 2.5, Step = 26, Color = Color3.fromRGB(255, 90, 200) },
}
local JUMPS_PER_TIER = 10
local LANDING_SIZE = 14
local SUMMIT_RADIUS = 18

local LAVA_COLOR = Color3.fromRGB(255, 60, 20)

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

-- Невидимая деталь-якорь для табличек и точек
local function anchorPart(name: string, position: Vector3, parent: Instance): Part
	return part({
		Name = name,
		Size = Vector3.one,
		CFrame = CFrame.new(position),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = parent,
	})
end

-- Табличка над деталью. sizeStuds — размер в studs (Scale у BillboardGui = studs),
-- поэтому надпись уменьшается с расстоянием, как настоящая табличка.
local function billboard(adornee: BasePart, title: string, subtitle: string?, color: Color3, sizeStuds: Vector2, maxDistance: number)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Sign"
	gui.Size = UDim2.fromScale(sizeStuds.X, sizeStuds.Y)
	gui.LightInfluence = 0
	gui.MaxDistance = maxDistance
	gui.AlwaysOnTop = false
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.BackgroundTransparency = 1
	titleLabel.Size = UDim2.fromScale(1, if subtitle then 0.62 else 1)
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.TextScaled = true
	titleLabel.TextColor3 = color
	titleLabel.TextStrokeTransparency = 0
	titleLabel.Text = title
	titleLabel.Parent = gui
	if subtitle then
		local sub = Instance.new("TextLabel")
		sub.Name = "Subtitle"
		sub.BackgroundTransparency = 1
		sub.Position = UDim2.fromScale(0, 0.62)
		sub.Size = UDim2.fromScale(1, 0.38)
		sub.Font = Enum.Font.GothamBold
		sub.TextScaled = true
		sub.TextColor3 = Color3.new(1, 1, 1)
		sub.TextStrokeTransparency = 0
		sub.Text = subtitle
		sub.Parent = gui
	end
	gui.Parent = adornee
	return gui
end

local function light(parent: BasePart, color: Color3, range: number, brightness: number)
	local pointLight = Instance.new("PointLight")
	pointLight.Color = color
	pointLight.Range = range
	pointLight.Brightness = brightness
	pointLight.Parent = parent
end

-- Вертикальный цилиндр (у Cylinder ось — X, поворачиваем на 90° вокруг Z)
local function disc(props: { [string]: any }, position: Vector3, diameter: number, height: number): Part
	props.Shape = Enum.PartType.Cylinder
	props.Size = Vector3.new(height, diameter, diameter)
	props.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	return part(props)
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
	light(bulb, Color3.fromRGB(255, 180, 90), 24, 1.4)
end

-- Скамейка: сиденье + спинка (yaw — поворот вокруг Y в градусах)
local function buildBench(position: Vector3, yaw: number, parent: Instance)
	local origin = CFrame.new(position) * CFrame.Angles(0, math.rad(yaw), 0)
	part({
		Name = "BenchSeat",
		Size = Vector3.new(6, 1, 2),
		CFrame = origin * CFrame.new(0, 1.5, 0),
		Color = Color3.fromRGB(150, 100, 60),
		Material = Enum.Material.WoodPlanks,
		Parent = parent,
	})
	part({
		Name = "BenchBack",
		Size = Vector3.new(6, 2, 0.5),
		CFrame = origin * CFrame.new(0, 2.8, 0.9),
		Color = Color3.fromRGB(130, 85, 50),
		Material = Enum.Material.WoodPlanks,
		Parent = parent,
	})
end

-- Клумба: земля + 4 цветка-шарика
local function buildFlowerBed(position: Vector3, random: Random, parent: Instance)
	part({
		Name = "FlowerBed",
		Size = Vector3.new(6, 0.8, 6),
		CFrame = CFrame.new(position + Vector3.new(0, 0.4, 0)),
		Color = Color3.fromRGB(90, 60, 40),
		Material = Enum.Material.Ground,
		Parent = parent,
	})
	for i = 1, 4 do
		local angle = math.rad(i * 90 + 45)
		part({
			Name = "Flower",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 1.4,
			Color = Color3.fromHSV(random:NextNumber(), 0.6, 1),
			CFrame = CFrame.new(position + Vector3.new(math.cos(angle) * 1.6, 1.3, math.sin(angle) * 1.6)),
			CanCollide = false,
			Parent = parent,
		})
	end
end

-- Простое дерево: ствол + крона-шар
local function buildTree(position: Vector3, size: number, color: Color3, parent: Instance)
	part({
		Name = "TreeTrunk",
		Size = Vector3.new(1.4, size, 1.4),
		CFrame = CFrame.new(position + Vector3.new(0, size / 2, 0)),
		Color = Color3.fromRGB(95, 65, 40),
		Material = Enum.Material.Wood,
		Parent = parent,
	})
	part({
		Name = "TreeCrown",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * size * 0.9,
		CFrame = CFrame.new(position + Vector3.new(0, size * 1.1, 0)),
		Color = color,
		Material = Enum.Material.Grass,
		CanCollide = false,
		Parent = parent,
	})
end

-- Телепорт-площадка: светящийся диск + табличка. Target — куда ведёт (см. ZoneService)
local function buildPad(position: Vector3, target: string, label: string, color: Color3, parent: Instance): Part
	disc({
		Name = "PadBase",
		Color = Color3.fromRGB(35, 30, 45),
		Material = Enum.Material.Slate,
		Parent = parent,
	}, position + Vector3.new(0, 0.3, 0), 9, 0.6)
	local pad = disc({
		Name = "TeleportPad",
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = 0.15,
		Parent = parent,
	}, position + Vector3.new(0, 0.7, 0), 7, 0.4)
	pad:SetAttribute("Target", target)
	light(pad, color, 12, 1.2)
	local sign = anchorPart("PadSign", position + Vector3.new(0, 6, 0), parent)
	billboard(sign, label, nil, color, Vector2.new(10, 2.6), 140)
	return pad
end

-- ===== Башня мемов =====

local function spiralPosition(angleDeg: number, radius: number, top: number): Vector3
	local a = math.rad(angleDeg)
	return Vector3.new(TOWER_CENTER.X + math.cos(a) * radius, top, TOWER_CENTER.Z + math.sin(a) * radius)
end

-- Платформа: верх на высоте top, лицом к центру башни
local function platform(name: string, center: Vector3, size: Vector3, color: Color3, parent: Instance): Part
	local flat = Vector3.new(TOWER_CENTER.X, center.Y, TOWER_CENTER.Z)
	local cframe = if (flat - center).Magnitude > 0.1 then CFrame.lookAt(center, flat) else CFrame.new(center)
	return part({
		Name = name,
		Size = size,
		CFrame = cframe * CFrame.new(0, -size.Y / 2, 0),
		Color = color,
		Material = Enum.Material.SmoothPlastic,
		Parent = parent,
	})
end

local function buildTower(map: Instance, result: any)
	local tower = Instance.new("Model")
	tower.Name = "MemeTower"
	tower.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

	local lava: { BasePart } = {}
	local vanishing: { { Part: BasePart, Offset: number } } = {}
	local spinners: { { Part: BasePart, Center: Vector3, Length: number, Phase: number } } = {}
	local checkpoints: { { Part: BasePart, Spawn: CFrame } } = {}
	local prizes: { BasePart } = {}

	-- Лава под башней: упал — вернулся на чекпоинт
	table.insert(lava, part({
		Name = "Lava",
		Size = Vector3.new(LAVA_HALF * 2, 0.4, LAVA_HALF * 2),
		CFrame = CFrame.new(TOWER_CENTER.X, 0.6, TOWER_CENTER.Z),
		Color = LAVA_COLOR,
		Material = Enum.Material.Neon,
		Parent = tower,
	}))

	-- Чекпоинт 1: стартовая площадка
	local startPad = part({
		Name = "StartPad",
		Size = Vector3.new(12, 1, 12),
		CFrame = CFrame.new(TOWER_START),
		Color = Color3.fromRGB(80, 220, 120),
		Material = Enum.Material.Neon,
		Parent = tower,
	})
	startPad:SetAttribute("Checkpoint", 1)
	table.insert(checkpoints, { Part = startPad, Spawn = CFrame.lookAt(TOWER_START + Vector3.new(0, 4, 0), TOWER_START + Vector3.new(10, 4, 0)) })

	local angle = 180
	local top = TOWER_START.Y + 0.5 -- верх стартовой площадки
	local summitTop = 0
	for tierIndex, tier in TIERS do
		for jump = 1, JUMPS_PER_TIER do
			if not (tierIndex == 1 and jump == 1) then
				angle += tier.Step
			end
			top += tier.Rise
			local size = tier.Size
			local height = 1
			local color = tier.Color
			-- Ярус 3: прыжок 5 — лазанье по ферме на 7 studs выше
			local truss = tierIndex == 3 and jump == 5
			if truss then
				top += 7
			end
			local center = spiralPosition(angle, tier.Radius, top)
			local platformSize = Vector3.new(size, height, size)
			-- Ярус 3, прыжок 2: узкая балка
			if tierIndex == 3 and jump == 2 then
				platformSize = Vector3.new(size + 2, height, 2.2)
			end
			local p = platform("Platform", center, platformSize, color, tower)

			-- Исчезающие платформы: ярус 2 (2, 4, 6, 8) и ярус 3 (8, 9); две фазы вразнобой
			if (tierIndex == 2 and jump % 2 == 0 and jump <= 8) or (tierIndex == 3 and (jump == 8 or jump == 9)) then
				p.Name = "VanishPlatform"
				p.Material = Enum.Material.Glass
				p.Color = Color3.fromRGB(170, 240, 255)
				table.insert(vanishing, { Part = p, Offset = if jump % 4 == 0 then 2 else 0 })
			end
			-- Ярус 2, прыжок 9: полоса лавы посередине — приземляйся сбоку от неё
			if tierIndex == 2 and jump == 9 then
				table.insert(lava, part({
					Name = "Lava",
					Size = Vector3.new(size, 0.3, 1.6),
					CFrame = p.CFrame * CFrame.new(0, height / 2 + 0.15, 0),
					Color = LAVA_COLOR,
					Material = Enum.Material.Neon,
					Parent = tower,
				}))
			end
			-- Ярус 3, прыжки 3 и 7: вращающаяся лава-перекладина (крутит ZoneService)
			if tierIndex == 3 and (jump == 3 or jump == 7) then
				local barCenter = center + Vector3.new(0, 1.5, 0)
				local length = size + 6
				local bar = part({
					Name = "Lava",
					Size = Vector3.new(length, 1, 1),
					CFrame = CFrame.new(barCenter),
					Color = LAVA_COLOR,
					Material = Enum.Material.Neon,
					CanCollide = false,
					Parent = tower,
				})
				table.insert(spinners, { Part = bar, Center = barCenter, Length = length, Phase = jump })
				part({
					Name = "SpinnerHub",
					Size = Vector3.new(1.2, 1.6, 1.2),
					CFrame = CFrame.new(center + Vector3.new(0, 0.8, 0)),
					Color = Color3.fromRGB(40, 35, 50),
					Material = Enum.Material.Metal,
					Parent = tower,
				})
			end
			if truss then
				-- Ферма с внешней стороны платформы, со стороны предыдущего прыжка
				local a = math.rad(angle)
				local tangent = Vector3.new(-math.sin(a), 0, math.cos(a))
				local trussHeight = 12 -- у TrussPart размеры кратны 2
				local trussPart = Instance.new("TrussPart")
				trussPart.Name = "Truss"
				trussPart.Anchored = true
				trussPart.Size = Vector3.new(2, trussHeight, 2)
				trussPart.Color = Color3.fromRGB(200, 200, 210)
				trussPart.CFrame = CFrame.new(center - tangent * (size / 2 + 1) - Vector3.new(0, trussHeight / 2 - 1, 0))
				trussPart.Parent = tower
			end
			-- Номер яруса над первым прыжком
			if jump == 1 then
				local sign = anchorPart("TierSign", center + Vector3.new(0, 6, 0), tower)
				billboard(sign, "TIER " .. tierIndex, "ЯРУС " .. tierIndex, tier.Color, Vector2.new(8, 3.4), 160)
			end
		end

		top += tier.Rise
		if tierIndex < #TIERS then
			-- Площадка конца яруса: чекпоинт следующего яруса + приз
			angle += tier.Step
			local center = spiralPosition(angle, tier.Radius, top)
			local landing = platform("Landing", center, Vector3.new(LANDING_SIZE, 1.4, LANDING_SIZE), Color3.fromRGB(120, 255, 160), tower)
			landing.Material = Enum.Material.Neon
			landing:SetAttribute("Checkpoint", tierIndex + 1)
			local flat = Vector3.new(TOWER_CENTER.X, top + 3, TOWER_CENTER.Z)
			table.insert(checkpoints, { Part = landing, Spawn = CFrame.lookAt(center + Vector3.new(0, 3, 0), flat) })
			local prize = part({
				Name = "PrizePad",
				Size = Vector3.new(5, 0.4, 5),
				CFrame = landing.CFrame * CFrame.new(0, 0.9, 3.5),
				Color = Color3.fromRGB(255, 200, 40),
				Material = Enum.Material.Neon,
				Parent = tower,
			})
			prize:SetAttribute("PrizeTier", tierIndex)
			table.insert(prizes, prize)
			local sign = anchorPart("PrizeSign", prize.Position + Vector3.new(0, 5, 0), tower)
			billboard(sign, "🎁 TIER " .. tierIndex .. " PRIZE", "приз яруса " .. tierIndex .. " (раз в день)", Color3.fromRGB(255, 220, 80), Vector2.new(9, 3.2), 120)
		else
			summitTop = top
		end
	end

	-- Ствол башни и вершина
	local coreTop = summitTop - 1
	part({
		Name = "Core",
		Size = Vector3.new(16, coreTop - GROUND_TOP, 16),
		CFrame = CFrame.new(TOWER_CENTER.X, (coreTop + GROUND_TOP) / 2, TOWER_CENTER.Z),
		Color = Color3.fromRGB(60, 40, 90),
		Material = Enum.Material.Slate,
		Parent = tower,
	})
	for tierIndex, tier in TIERS do
		local y = GROUND_TOP + (coreTop - GROUND_TOP) * tierIndex / #TIERS - 2
		part({
			Name = "CoreRing",
			Size = Vector3.new(16.6, 1.2, 16.6),
			CFrame = CFrame.new(TOWER_CENTER.X, y, TOWER_CENTER.Z),
			Color = tier.Color,
			Material = Enum.Material.Neon,
			CanCollide = false,
			Parent = tower,
		})
	end
	local summitCenter = Vector3.new(TOWER_CENTER.X, summitTop - 0.5, TOWER_CENTER.Z)
	local summit = disc({
		Name = "Summit",
		Color = Color3.fromRGB(255, 220, 90),
		Material = Enum.Material.Marble,
		Parent = tower,
	}, summitCenter, SUMMIT_RADIUS * 2, 1)
	summit:SetAttribute("Checkpoint", #TIERS + 1)
	table.insert(checkpoints, { Part = summit, Spawn = CFrame.new(summitCenter + Vector3.new(-5, 3.5, 6)) })

	-- Сундук на вершине: касание = приз яруса 3
	local chest = part({
		Name = "SummitChest",
		Size = Vector3.new(5, 3, 3.5),
		CFrame = CFrame.new(summitCenter + Vector3.new(0, 2, 0)),
		Color = Color3.fromRGB(150, 90, 40),
		Material = Enum.Material.WoodPlanks,
		Parent = tower,
	})
	chest:SetAttribute("PrizeTier", #TIERS)
	table.insert(prizes, chest)
	part({
		Name = "ChestTrim",
		Size = Vector3.new(5.2, 0.6, 3.7),
		CFrame = chest.CFrame * CFrame.new(0, 0.6, 0),
		Color = Color3.fromRGB(255, 200, 40),
		Material = Enum.Material.Neon,
		CanCollide = false,
		CanTouch = false,
		Parent = tower,
	})
	local chestSign = anchorPart("ChestSign", chest.Position + Vector3.new(0, 5, 0), tower)
	billboard(chestSign, "🏆 SUMMIT CHEST", "сундук вершины (раз в день)", Color3.fromRGB(255, 220, 80), Vector2.new(10, 3.4), 150)
	-- Флаг на вершине
	part({
		Name = "FlagPole",
		Size = Vector3.new(0.6, 14, 0.6),
		CFrame = CFrame.new(summitCenter + Vector3.new(-12, 7, 0)),
		Color = Color3.fromRGB(230, 230, 240),
		Material = Enum.Material.Metal,
		Parent = tower,
	})
	part({
		Name = "Flag",
		Size = Vector3.new(0.2, 4, 6),
		CFrame = CFrame.new(summitCenter + Vector3.new(-12, 12, 3)),
		Color = Color3.fromRGB(150, 60, 255),
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = tower,
	})

	-- Вниз с вершины и домой; у подножия — домой и к дорожке
	local pads = result.Pads
	table.insert(pads, buildPad(summitCenter + Vector3.new(9, 0.5, -7), "TowerDown", "⬇️ Back down", Color3.fromRGB(120, 255, 160), tower))
	table.insert(pads, buildPad(summitCenter + Vector3.new(9, 0.5, 7), "Base", "🏠 Base", Color3.fromRGB(90, 200, 255), tower))
	table.insert(pads, buildPad(Vector3.new(TOWER_START.X - 14, GROUND_TOP, -16), "Base", "🏠 Base", Color3.fromRGB(90, 200, 255), tower))
	table.insert(pads, buildPad(Vector3.new(TOWER_START.X - 14, GROUND_TOP, 16), "Carpet", "🏪 Carpet", Color3.fromRGB(255, 120, 120), tower))

	local sign = anchorPart("TowerSign", TOWER_START + Vector3.new(-8, 14, 0), tower)
	billboard(sign, "🗼 MEME TOWER", "prizes at the top! • призы на вершине!", Color3.fromRGB(255, 220, 80), Vector2.new(22, 7), 400)

	tower.Parent = map

	result.Tower = {
		Model = tower,
		Lava = lava,
		Vanishing = vanishing,
		Spinners = spinners,
		Checkpoints = checkpoints,
		Prizes = prizes,
		Center = TOWER_CENTER,
		Radius = LAVA_HALF + 8,
	}
	result.Destinations.Tower = checkpoints[1].Spawn
	result.SignSpots.Tower = Vector3.new(TOWER_CENTER.X, summitTop + 22, TOWER_CENTER.Z)
end

-- ===== Скалы восточного края и секретная пещера =====

local function buildCliffAndCave(map: Instance, random: Random, result: any)
	local cliffs = Instance.new("Model")
	cliffs.Name = "EastCliffs"
	cliffs.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local rockColor = Color3.fromRGB(95, 85, 100)
	local depth = CLIFF_BACK - CLIFF_X
	local count = math.ceil(-CLIFF_FROM_Z * 2 / CLIFF_SEGMENT)
	for k = 0, count - 1 do
		local z = CLIFF_FROM_Z + k * CLIFF_SEGMENT + CLIFF_SEGMENT / 2
		local height = random:NextNumber(26, 40)
		if table.find(CAVE_SEGMENTS, k) then
			-- Передняя «стена» пещеры (у фальшивого сегмента — без коллизии), крыша и задняя стена
			local front = part({
				Name = "Cliff",
				Size = Vector3.new(10, height, CLIFF_SEGMENT),
				CFrame = CFrame.new(CLIFF_X + 5, GROUND_TOP + height / 2, z),
				Color = rockColor,
				Material = Enum.Material.Slate,
				Parent = cliffs,
			})
			if k == CAVE_FAKE_SEGMENT then
				front.CanCollide = false
			end
			part({
				Name = "Cliff",
				Size = Vector3.new(CLIFF_BACK - CLIFF_X - 10, height - CAVE_HEIGHT, CLIFF_SEGMENT),
				CFrame = CFrame.new((CLIFF_X + 10 + CLIFF_BACK) / 2, GROUND_TOP + CAVE_HEIGHT + (height - CAVE_HEIGHT) / 2, z),
				Color = rockColor,
				Material = Enum.Material.Slate,
				Parent = cliffs,
			})
			part({
				Name = "CaveWall",
				Size = Vector3.new(CLIFF_BACK - CAVE_DEPTH_END, CAVE_HEIGHT, CLIFF_SEGMENT),
				CFrame = CFrame.new((CAVE_DEPTH_END + CLIFF_BACK) / 2, GROUND_TOP + CAVE_HEIGHT / 2, z),
				Color = rockColor,
				Material = Enum.Material.Slate,
				Parent = cliffs,
			})
		else
			part({
				Name = "Cliff",
				Size = Vector3.new(depth, height, CLIFF_SEGMENT),
				CFrame = CFrame.new((CLIFF_X + CLIFF_BACK) / 2, GROUND_TOP + height / 2, z),
				Color = rockColor,
				Material = Enum.Material.Slate,
				Parent = cliffs,
			})
		end
	end
	-- Валуны у подножия (вход в пещеру не загораживаем и не выделяем)
	local caveZ = CLIFF_FROM_Z + CAVE_FAKE_SEGMENT * CLIFF_SEGMENT + CLIFF_SEGMENT / 2
	for _ = 1, 16 do
		local z = random:NextNumber(-165, 165)
		if math.abs(z - caveZ) < 14 then
			continue
		end
		local size = random:NextNumber(4, 9)
		part({
			Name = "Boulder",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * size,
			CFrame = CFrame.new(CLIFF_X - size * 0.3, GROUND_TOP + size * 0.3, z),
			Color = rockColor,
			Material = Enum.Material.Slate,
			Parent = cliffs,
		})
	end
	cliffs.Parent = map

	-- Пещера: тёмная, светятся только кристаллы
	local cave = Instance.new("Model")
	cave.Name = "Cave"
	cave.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local caveFromZ = CLIFF_FROM_Z + CAVE_SEGMENTS[1] * CLIFF_SEGMENT
	local caveToZ = CLIFF_FROM_Z + (CAVE_SEGMENTS[#CAVE_SEGMENTS] + 1) * CLIFF_SEGMENT
	part({
		Name = "CaveFloor",
		Size = Vector3.new(CAVE_DEPTH_END - CLIFF_X - 10, 0.4, caveToZ - caveFromZ),
		CFrame = CFrame.new((CLIFF_X + 10 + CAVE_DEPTH_END) / 2, GROUND_TOP + 0.1, (caveFromZ + caveToZ) / 2),
		Color = Color3.fromRGB(40, 35, 45),
		Material = Enum.Material.Slate,
		Parent = cave,
	})
	local crystalColors = { Color3.fromRGB(150, 80, 255), Color3.fromRGB(80, 230, 255), Color3.fromRGB(255, 90, 220) }
	for i = 1, 7 do
		local x = random:NextNumber(CLIFF_X + 13, CAVE_DEPTH_END - 2)
		local z = if i % 2 == 0 then caveFromZ + random:NextNumber(1, 3) else caveToZ - random:NextNumber(1, 3)
		local height = random:NextNumber(3, 6)
		local color = crystalColors[(i - 1) % #crystalColors + 1]
		local crystal = part({
			Name = "Crystal",
			Size = Vector3.new(1.4, height, 1.4),
			CFrame = CFrame.new(x, GROUND_TOP + height / 2, z) * CFrame.Angles(math.rad(random:NextNumber(-20, 20)), math.rad(random:NextNumber(0, 90)), math.rad(random:NextNumber(-20, 20))),
			Color = color,
			Material = Enum.Material.Neon,
			Transparency = 0.15,
			Parent = cave,
		})
		light(crystal, color, 10, 1)
	end
	local chest = part({
		Name = "SecretChest",
		Size = Vector3.new(4, 2.6, 3),
		CFrame = CFrame.lookAt(Vector3.new(CAVE_DEPTH_END - 4, GROUND_TOP + 1.3, (caveFromZ + caveToZ) / 2), Vector3.new(CLIFF_X, GROUND_TOP + 1.3, (caveFromZ + caveToZ) / 2)),
		Color = Color3.fromRGB(120, 70, 35),
		Material = Enum.Material.WoodPlanks,
		Parent = cave,
	})
	part({
		Name = "ChestLid",
		Size = Vector3.new(4.2, 0.8, 3.2),
		CFrame = chest.CFrame * CFrame.new(0, 1.6, 0),
		Color = Color3.fromRGB(255, 200, 40),
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = cave,
	})
	light(chest, Color3.fromRGB(255, 200, 80), 12, 1.2)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ChestPrompt"
	prompt.ActionText = "Open"
	prompt.ObjectText = "🧰"
	prompt.HoldDuration = 0.6
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 10
	prompt.Parent = chest
	cave.Parent = map

	result.Cave = { Chest = chest, Prompt = prompt }
end

-- ===== Торговая площадь (безопасная зона) =====

local function buildPlaza(map: Instance, result: any)
	local plaza = Instance.new("Model")
	plaza.Name = "TradePlaza"
	plaza.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local c = PLAZA_CENTER
	local sx, sz = PLAZA_SIZE.X, PLAZA_SIZE.Y
	part({
		Name = "PlazaFloor",
		Size = Vector3.new(sx, 0.4, sz),
		CFrame = CFrame.new(c.X, GROUND_TOP + 0.1, c.Z),
		Color = Color3.fromRGB(200, 190, 175),
		Material = Enum.Material.Cobblestone,
		Parent = plaza,
	})
	-- Зелёный бордюр — граница безопасной зоны
	for _, data in {
		{ Vector3.new(0, 0, sz / 2), Vector3.new(sx, 0.6, 1) },
		{ Vector3.new(0, 0, -sz / 2), Vector3.new(sx, 0.6, 1) },
		{ Vector3.new(sx / 2, 0, 0), Vector3.new(1, 0.6, sz) },
		{ Vector3.new(-sx / 2, 0, 0), Vector3.new(1, 0.6, sz) },
	} do
		part({
			Name = "SafeBorder",
			Size = data[2],
			CFrame = CFrame.new(c + data[1] + Vector3.new(0, 0.4, 0)),
			Color = Color3.fromRGB(90, 255, 140),
			Material = Enum.Material.Neon,
			CanCollide = false,
			Parent = plaza,
		})
	end

	-- Фонтан
	disc({ Name = "FountainBasin", Color = Color3.fromRGB(170, 165, 160), Material = Enum.Material.Marble, Parent = plaza }, c + Vector3.new(0, 1, 0), 16, 2)
	disc({
		Name = "FountainWater",
		Color = Color3.fromRGB(70, 160, 255),
		Material = Enum.Material.Glass,
		Transparency = 0.3,
		CanCollide = false,
		Parent = plaza,
	}, c + Vector3.new(0, 2.05, 0), 14, 0.2)
	part({
		Name = "FountainPillar",
		Size = Vector3.new(2, 6, 2),
		CFrame = CFrame.new(c + Vector3.new(0, 4, 0)),
		Color = Color3.fromRGB(190, 185, 180),
		Material = Enum.Material.Marble,
		Parent = plaza,
	})
	local spout = part({
		Name = "FountainTop",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 3,
		CFrame = CFrame.new(c + Vector3.new(0, 7.5, 0)),
		Color = Color3.fromRGB(120, 200, 255),
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = plaza,
	})
	local spray = Instance.new("ParticleEmitter")
	spray.Color = ColorSequence.new(Color3.fromRGB(200, 235, 255))
	spray.LightEmission = 0.4
	spray.Transparency = NumberSequence.new(0.2, 1)
	spray.Size = NumberSequence.new(0.6, 0.2)
	spray.Rate = 25
	spray.Lifetime = NumberRange.new(1, 1.4)
	spray.Speed = NumberRange.new(8, 11)
	spray.SpreadAngle = Vector2.new(25, 25)
	spray.Acceleration = Vector3.new(0, -30, 0)
	spray.EmissionDirection = Enum.NormalId.Top
	spray.Parent = spout

	-- 4 стола для обмена
	for _, offset in { Vector3.new(-22, 0, -18), Vector3.new(22, 0, -18), Vector3.new(-22, 0, 18), Vector3.new(22, 0, 18) } do
		local base = c + offset
		local tableTop = part({
			Name = "TradeTable",
			Size = Vector3.new(8, 0.6, 4),
			CFrame = CFrame.new(base + Vector3.new(0, 3.3, 0)),
			Color = Color3.fromRGB(150, 100, 60),
			Material = Enum.Material.WoodPlanks,
			Parent = plaza,
		})
		part({
			Name = "TableLeg",
			Size = Vector3.new(1.2, 3, 1.2),
			CFrame = CFrame.new(base + Vector3.new(0, 1.5, 0)),
			Color = Color3.fromRGB(60, 45, 35),
			Material = Enum.Material.Wood,
			Parent = plaza,
		})
		for _, side in { -1, 1 } do
			disc({ Name = "Stool", Color = Color3.fromRGB(110, 75, 45), Material = Enum.Material.Wood, Parent = plaza }, base + Vector3.new(0, 1, side * 4), 2.4, 2)
		end
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "TradePrompt"
		prompt.ActionText = "Trade"
		prompt.ObjectText = "🤝"
		prompt.RequiresLineOfSight = false
		prompt.MaxActivationDistance = 10
		prompt.Parent = tableTop
	end

	-- Фонари по углам и скамейки у фонтана
	for _, sx2 in { -1, 1 } do
		for _, sz2 in { -1, 1 } do
			buildLamp(c + Vector3.new(sx2 * (sx / 2 - 3), 0, sz2 * (sz / 2 - 3)), plaza)
		end
		buildBench(c + Vector3.new(sx2 * 12, 0, 0), sx2 * 90, plaza)
	end

	-- Большая вывеска у восточного входа (лицом к порталу)
	local signPos = c + Vector3.new(sx / 2 + 2, 0, 0)
	for _, side in { -1, 1 } do
		part({
			Name = "SignPost",
			Size = Vector3.new(1.2, 14, 1.2),
			CFrame = CFrame.new(signPos + Vector3.new(0, 7, side * 13)),
			Color = Color3.fromRGB(60, 45, 35),
			Material = Enum.Material.Wood,
			Parent = plaza,
		})
	end
	local board = part({
		Name = "PlazaSign",
		Size = Vector3.new(28, 6, 0.6),
		CFrame = CFrame.lookAt(signPos + Vector3.new(0, 11, 0), signPos + Vector3.new(10, 11, 0)),
		Color = Color3.fromRGB(30, 25, 40),
		Parent = plaza,
	})
	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front
	surface.CanvasSize = Vector2.new(560, 120)
	surface.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(90, 255, 140)
	label.TextStrokeTransparency = 0
	label.Text = "🤝 TRADE PLAZA • SAFE ZONE\nТОРГОВАЯ ПЛОЩАДЬ • БЕЗ ДРАК"
	label.Parent = surface
	surface.Parent = board

	-- Возвраты
	local pads = result.Pads
	table.insert(pads, buildPad(c + Vector3.new(-sx / 2 + 8, 0, -sz / 2 + 8), "Base", "🏠 Base", Color3.fromRGB(90, 200, 255), plaza))
	table.insert(pads, buildPad(c + Vector3.new(-sx / 2 + 8, 0, sz / 2 - 8), "Carpet", "🏪 Carpet", Color3.fromRGB(255, 120, 120), plaza))

	plaza.Parent = map
	result.Plaza = { Center = c, Size = PLAZA_SIZE }
	result.Destinations.Plaza = CFrame.lookAt(c + Vector3.new(sx / 2 - 8, 3.5, 0), c + Vector3.new(0, 3.5, 0))
	result.SignSpots.Plaza = c + Vector3.new(0, 26, 0)
end

-- ===== Конфетный парк =====

local function buildPark(map: Instance, random: Random, season: string, result: any)
	local park = Instance.new("Model")
	park.Name = "CandyPark"
	park.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local c = PARK_CENTER
	local sx, sz = PARK_SIZE.X, PARK_SIZE.Y
	local winter = season == "Winter"
	part({
		Name = "ParkLawn",
		Size = Vector3.new(sx, 0.3, sz),
		CFrame = CFrame.new(c.X, GROUND_TOP + 0.05, c.Z),
		Color = if winter then Color3.fromRGB(245, 235, 250) else Color3.fromRGB(110, 200, 110),
		Material = if winter then Enum.Material.Snow else Enum.Material.Grass,
		Parent = park,
	})
	-- Розовая дорожка-кольцо
	for _, data in {
		{ Vector3.new(0, 0, sz / 2 - 6), Vector3.new(sx - 8, 0.2, 4) },
		{ Vector3.new(0, 0, -sz / 2 + 6), Vector3.new(sx - 8, 0.2, 4) },
		{ Vector3.new(sx / 2 - 6, 0, 0), Vector3.new(4, 0.2, sz - 8) },
		{ Vector3.new(-sx / 2 + 6, 0, 0), Vector3.new(4, 0.2, sz - 8) },
	} do
		part({
			Name = "CandyPath",
			Size = data[2],
			CFrame = CFrame.new(c + data[1] + Vector3.new(0, 0.3, 0)),
			Color = Color3.fromRGB(255, 160, 210),
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
			Parent = park,
		})
	end

	-- Батуты
	local trampolines: { BasePart } = {}
	local trampolineSpots = { Vector3.new(-20, 0, -14), Vector3.new(18, 0, -16), Vector3.new(0, 0, 4), Vector3.new(-22, 0, 20), Vector3.new(22, 0, 18) }
	for i, offset in trampolineSpots do
		local base = c + offset
		disc({ Name = "TrampolineFrame", Color = Color3.fromRGB(40, 40, 60), Material = Enum.Material.Metal, Parent = park }, base + Vector3.new(0, 0.75, 0), 11, 1.5)
		local top = disc({
			Name = "Trampoline",
			Color = Color3.fromHSV((i - 1) / #trampolineSpots, 0.55, 1),
			Material = Enum.Material.Neon,
			Parent = park,
		}, base + Vector3.new(0, 1.6, 0), 9, 0.3)
		table.insert(trampolines, top)
	end

	-- Леденцы-гиганты, деревья, скамейки, фонари
	for i = 1, 6 do
		local angle = math.rad(i * 60 - 30)
		local pos = c + Vector3.new(math.cos(angle) * 40, 0, math.sin(angle) * 30)
		part({
			Name = "LollipopStick",
			Size = Vector3.new(0.8, 10, 0.8),
			CFrame = CFrame.new(pos + Vector3.new(0, 5, 0)),
			Color = Color3.fromRGB(250, 250, 250),
			Parent = park,
		})
		-- Конфета-диск стоит вертикально (ось цилиндра — X, повёрнута вокруг Y)
		part({
			Name = "Lollipop",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.8, 5, 5),
			CFrame = CFrame.new(pos + Vector3.new(0, 11.5, 0)) * CFrame.Angles(0, math.rad(i * 60), 0),
			Color = Color3.fromHSV(random:NextNumber(), 0.6, 1),
			Material = Enum.Material.Neon,
			CanCollide = false,
			Parent = park,
		})
	end
	local crownColor = if winter then Color3.fromRGB(230, 240, 255) else Color3.fromRGB(255, 150, 200)
	for _, offset in { Vector3.new(-40, 0, -34), Vector3.new(40, 0, -34), Vector3.new(-40, 0, 34), Vector3.new(40, 0, 34), Vector3.new(-25, 0, 36), Vector3.new(25, 0, 36) } do
		buildTree(c + offset, random:NextNumber(7, 10), crownColor, park)
	end
	buildBench(c + Vector3.new(-8, 0, -30), 0, park)
	buildBench(c + Vector3.new(8, 0, -30), 0, park)
	buildBench(c + Vector3.new(-8, 0, 30), 180, park)
	buildBench(c + Vector3.new(8, 0, 30), 180, park)
	buildLamp(c + Vector3.new(sx / 2 - 2, 0, -sz / 2 + 2), park)
	buildLamp(c + Vector3.new(-sx / 2 + 2, 0, -sz / 2 + 2), park)
	buildLamp(c + Vector3.new(sx / 2 - 2, 0, sz / 2 - 2), park)
	buildLamp(c + Vector3.new(-sx / 2 + 2, 0, sz / 2 - 2), park)

	local pads = result.Pads
	table.insert(pads, buildPad(c + Vector3.new(-sx / 2 + 12, 0, -sz / 2 + 14), "Base", "🏠 Base", Color3.fromRGB(90, 200, 255), park))
	table.insert(pads, buildPad(c + Vector3.new(sx / 2 - 12, 0, -sz / 2 + 14), "Carpet", "🏪 Carpet", Color3.fromRGB(255, 120, 120), park))

	park.Parent = map

	-- Пикапы — отдельная папка (стримятся по одному, ZoneService создаёт/удаляет)
	local pickups = Instance.new("Folder")
	pickups.Name = "Pickups"
	pickups.Parent = map

	result.Park = {
		Center = c,
		Size = PARK_SIZE,
		Trampolines = trampolines,
		TrampolineSpots = trampolineSpots,
		Pickups = pickups,
	}
	result.Destinations.Park = CFrame.lookAt(c + Vector3.new(-14, 3.5, -sz / 2 + 4), c + Vector3.new(0, 3.5, 0))
	result.SignSpots.Park = c + Vector3.new(0, 26, 0)
end

-- ===== Хаб телепортов у спавна, дорожки и декор =====

local function buildHub(map: Instance, spawnPosition: Vector3, result: any)
	local hub = Instance.new("Model")
	hub.Name = "TeleportHub"
	hub.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local x = spawnPosition.X
	local pads = result.Pads
	table.insert(pads, buildPad(Vector3.new(x - 12, GROUND_TOP, -22), "Tower", "🗼 Tower", Color3.fromRGB(255, 200, 60), hub))
	table.insert(pads, buildPad(Vector3.new(x + 2, GROUND_TOP, -22), "Plaza", "🤝 Trade Plaza", Color3.fromRGB(90, 255, 140), hub))
	table.insert(pads, buildPad(Vector3.new(x - 12, GROUND_TOP, 22), "Park", "🍬 Candy Park", Color3.fromRGB(255, 120, 200), hub))
	table.insert(pads, buildPad(Vector3.new(x + 2, GROUND_TOP, 22), "Base", "🏠 My Base", Color3.fromRGB(90, 200, 255), hub))
	hub.Parent = map
	-- «К дорожке»: рядом со спавном, лицом к дорожке (не на площадках)
	result.Destinations.Carpet = CFrame.lookAt(Vector3.new(x - 14, 4, 0), Vector3.new(0, 4, 0))
end

local function buildPaths(map: Instance, random: Random)
	local decor = Instance.new("Folder")
	decor.Name = "ZoneDecor"
	local tileColor = Color3.fromRGB(205, 185, 150)
	local function tiles(from: Vector3, to: Vector3)
		local delta = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
		local count = math.max(1, math.floor(delta.Magnitude / 9))
		for i = 0, count do
			local pos = from + delta * (i / count)
			part({
				Name = "PathTile",
				Size = Vector3.new(7, 0.2, 7),
				CFrame = CFrame.new(pos.X, GROUND_TOP + 0.1, pos.Z) * CFrame.Angles(0, math.rad(random:NextNumber(-6, 6)), 0),
				Color = tileColor,
				Material = Enum.Material.Slate,
				CanCollide = false,
				Parent = decor,
			})
		end
	end
	-- Спавн → башня; портал → развилка → площадь и парк
	tiles(Vector3.new(222, 0, 0), Vector3.new(268, 0, 0))
	tiles(Vector3.new(-196, 0, 0), Vector3.new(-300, 0, 0))
	tiles(Vector3.new(-300, 0, -9), Vector3.new(-300, 0, -22))
	tiles(Vector3.new(-300, 0, 9), Vector3.new(-300, 0, 30))

	-- Фонари вдоль дорожек
	for _, x in { 236, 258 } do
		buildLamp(Vector3.new(x, GROUND_TOP, -7), decor)
		buildLamp(Vector3.new(x, GROUND_TOP, 7), decor)
	end
	for _, x in { -215, -245, -275 } do
		buildLamp(Vector3.new(x, GROUND_TOP, -7), decor)
		buildLamp(Vector3.new(x, GROUND_TOP, 7), decor)
	end
	-- Скамейки и клумбы
	buildBench(Vector3.new(-230, GROUND_TOP, -10), 0, decor)
	buildBench(Vector3.new(-260, GROUND_TOP, 10), 180, decor)
	buildBench(Vector3.new(246, GROUND_TOP, -10), 0, decor)
	for _, pos in {
		Vector3.new(222, GROUND_TOP, -12),
		Vector3.new(222, GROUND_TOP, 12),
		Vector3.new(-208, GROUND_TOP, -12),
		Vector3.new(-208, GROUND_TOP, 12),
		Vector3.new(-290, GROUND_TOP, -14),
		Vector3.new(-310, GROUND_TOP, -14),
		Vector3.new(-290, GROUND_TOP, 14),
		Vector3.new(-310, GROUND_TOP, 14),
		Vector3.new(0, GROUND_TOP, 120),
		Vector3.new(0, GROUND_TOP, -120),
	} do
		buildFlowerBed(pos, random, decor)
	end
	-- Ряд деревьев по западному краю
	for z = -140, 140, 35 do
		buildTree(Vector3.new(-405 + random:NextNumber(-6, 6), GROUND_TOP, z + random:NextNumber(-5, 5)), random:NextNumber(8, 12), Color3.fromRGB(60, 140, 70), decor)
	end
	decor.Parent = map
end

-- Большие таблички с названиями зон: видны издалека, поэтому модель Persistent
local function buildZoneSigns(map: Instance, result: any)
	local signs = Instance.new("Model")
	signs.Name = "ZoneSigns"
	signs.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	local data = {
		{ result.SignSpots.Tower, "🗼 MEME TOWER", "БАШНЯ МЕМОВ", Color3.fromRGB(255, 200, 60) },
		{ result.SignSpots.Plaza, "🤝 TRADE PLAZA", "ТОРГОВАЯ ПЛОЩАДЬ • SAFE ZONE", Color3.fromRGB(90, 255, 140) },
		{ result.SignSpots.Park, "🍬 CANDY PARK", "КОНФЕТНЫЙ ПАРК", Color3.fromRGB(255, 120, 200) },
	}
	for _, entry in data do
		local anchor = anchorPart("ZoneSign", entry[1], signs)
		billboard(anchor, entry[2], entry[3], entry[4], Vector2.new(46, 13), 900)
	end
	signs.Parent = map
end

-- Строит все зоны внутри map (Folder workspace.Map, ещё не в workspace).
-- spawnPosition — центр точки появления. Возвращает описание для ZoneService.Start.
function ZoneBuilder.Build(map: Instance, season: string, spawnPosition: Vector3)
	local random = Random.new(420)
	local result = {
		Pads = {} :: { BasePart },
		Destinations = {} :: { [string]: CFrame },
		SignSpots = {} :: { [string]: Vector3 },
		Tower = nil :: any,
		Plaza = nil :: any,
		Park = nil :: any,
		Cave = nil :: any,
	}
	buildHub(map, spawnPosition, result)
	buildTower(map, result)
	buildCliffAndCave(map, random, result)
	buildPlaza(map, result)
	buildPark(map, random, season, result)
	buildPaths(map, random)
	buildZoneSigns(map, result)
	return result
end

-- Не ставить сезонный декор внутрь зон (MapBuilder разбрасывает его по краям карты)
function ZoneBuilder.IsFree(position: Vector3): boolean
	if position.X > CLIFF_X - 10 then
		return false
	end
	if math.abs(position.X - TOWER_CENTER.X) < LAVA_HALF + 10 and math.abs(position.Z - TOWER_CENTER.Z) < LAVA_HALF + 10 then
		return false
	end
	if math.abs(position.X - PLAZA_CENTER.X) < PLAZA_SIZE.X / 2 + 6 and math.abs(position.Z - PLAZA_CENTER.Z) < PLAZA_SIZE.Y / 2 + 6 then
		return false
	end
	if math.abs(position.X - PARK_CENTER.X) < PARK_SIZE.X / 2 + 6 and math.abs(position.Z - PARK_CENTER.Z) < PARK_SIZE.Y / 2 + 6 then
		return false
	end
	return true
end

return ZoneBuilder
