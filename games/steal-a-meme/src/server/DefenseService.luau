-- Защита базы: турель и лазерные ворота (Config.Defense), покупаются за монеты, уровни навсегда.
-- Уровни — числа TurretLevel / LaserLevel в DataService (зеркалятся в атрибуты игрока).
-- Турель стреляет в воров с мемами хозяина и в чужаков, которые стоят на базе; лазер на входе
-- сбивает вора с мемом хозяина. Сбитый вор роняет мема (StealService.Knock).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local StealService = require(script.Parent.StealService)
local Remotes = require(script.Parent.Remotes)

local DefenseService = {}

local TICK = 0.2
local INTRUDER_DELAY = 2 -- сколько секунд чужак должен простоять на базе, чтобы турель выстрелила
local LASER_DISTANCE = 4 -- насколько близко к линии входа вор задевает лазер
local TURRET_POWER = 60
local LASER_POWER = 50

-- kind -> поле данных
local LEVEL_FIELD = {
	Turret = "TurretLevel",
	LaserGate = "LaserLevel",
}

local lastTurretShot: { [Model]: number } = {} -- база -> время последнего выстрела (os.clock)
local lastLaserHit: { [Model]: number } = {}
local intruderSince: { [Model]: { [Player]: number } } = {}

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return (character :: Model):FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function floorOf(plot: Model): BasePart
	return plot:FindFirstChild("Floor") :: BasePart
end

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	return p
end

-- ===== Визуал =====

local function destroyVisuals(plot: Model)
	for _, name in { "Turret", "LaserGate" } do
		local existing = plot:FindFirstChild(name)
		if existing then
			existing:Destroy()
		end
	end
	lastTurretShot[plot] = nil
	lastLaserHit[plot] = nil
	intruderSince[plot] = nil
end

-- Турель: угол базы у входа, напротив стража (страж стоит в -X углу)
local function buildTurret(plot: Model, level: number)
	local floor = floorOf(plot)
	local size = floor.Size
	local base = floor.CFrame * CFrame.new(size.X / 2 - 8, size.Y / 2, -size.Z / 2 + 16)

	local model = Instance.new("Model")
	model.Name = "Turret"
	model:SetAttribute("Level", level)

	local stand = part({
		Name = "Stand",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(3, 3.5, 3.5),
		CFrame = base * CFrame.new(0, 1.5, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(60, 60, 70),
		Material = Enum.Material.Metal,
		CanCollide = true,
		Parent = model,
	})
	model.PrimaryPart = stand
	local headCFrame = base * CFrame.new(0, 4, 0)
	part({
		Name = "Head",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(3, 3, 3),
		CFrame = headCFrame,
		Color = Color3.fromRGB(90, 95, 110),
		Material = Enum.Material.DiamondPlate,
		Parent = model,
	})
	part({
		Name = "Barrel",
		Size = Vector3.new(0.7, 0.7, 3),
		CFrame = headCFrame * CFrame.new(0, 0, -2),
		Color = Color3.fromRGB(35, 35, 40),
		Material = Enum.Material.Metal,
		Parent = model,
	})
	-- Огонёк уровня: чем выше уровень, тем «горячее» цвет
	local lightColors = { Color3.fromRGB(90, 255, 120), Color3.fromRGB(255, 200, 60), Color3.fromRGB(255, 70, 70) }
	part({
		Name = "Light",
		Size = Vector3.new(0.6, 0.6, 0.6),
		CFrame = headCFrame * CFrame.new(0, 1.5, 0),
		Color = lightColors[level] or lightColors[#lightColors],
		Material = Enum.Material.Neon,
		Parent = model,
	})
	model.Parent = plot
end

local LASER_TRANSPARENCY = 0.55

-- Лазер: тонкая красная полоса по линии входа, чуть внутри базы
local function buildLaser(plot: Model, level: number)
	local floor = floorOf(plot)
	local size = floor.Size
	local laser = part({
		Name = "LaserGate",
		Size = Vector3.new(size.X - 2, 0.3 + level * 0.1, 0.3),
		CFrame = floor.CFrame * CFrame.new(0, size.Y / 2 + 3, -size.Z / 2 + 1.5),
		Color = Color3.fromRGB(255, 40, 40),
		Material = Enum.Material.Neon,
		Transparency = LASER_TRANSPARENCY,
	})
	laser:SetAttribute("Level", level)
	laser.Parent = plot
end

-- Перерисовать защиту базы игрока по его уровням
function DefenseService.Refresh(player: Player)
	local plot = PlotService.GetPlot(player)
	if not plot then
		return
	end
	destroyVisuals(plot)
	if not DataService.IsLoaded(player) then
		return
	end
	local turretLevel = DataService.Get(player, "TurretLevel")
	if turretLevel > 0 then
		buildTurret(plot, turretLevel)
	end
	local laserLevel = DataService.Get(player, "LaserLevel")
	if laserLevel > 0 then
		buildLaser(plot, laserLevel)
	end
end

-- ===== Покупка =====

function DefenseService.Upgrade(player: Player, kind: unknown): (boolean, string)
	if typeof(kind) ~= "string" or not LEVEL_FIELD[kind] then
		return false, "BadRequest"
	end
	if not DataService.IsLoaded(player) or not PlotService.GetPlot(player) then
		return false, "NotLoaded"
	end
	local field = LEVEL_FIELD[kind]
	local level = DataService.Get(player, field)
	local nextLevel = Config.Defense[kind][level + 1]
	if not nextLevel then
		Remotes.Notify:FireClient(player, "DefenseMax", nil, "error")
		return false, "DefenseMax"
	end
	if DataService.Get(player, "Coins") < nextLevel.Price then
		Remotes.Notify:FireClient(player, "NotEnoughCash", { Price = nextLevel.Price }, "error")
		return false, "NotEnoughCash"
	end
	DataService.Increment(player, "Coins", -nextLevel.Price)
	DataService.Set(player, field, level + 1)
	DefenseService.Refresh(player)
	local key = if kind == "Turret" then "TurretUpgraded" else "LaserUpgraded"
	Remotes.Notify:FireClient(player, key, { Level = level + 1 }, "success")
	return true, key
end

-- ===== Логика =====

local function aimTurret(turret: Model, target: Vector3): Vector3
	local head = turret:FindFirstChild("Head") :: BasePart
	local barrel = turret:FindFirstChild("Barrel") :: BasePart
	local from = head.Position
	local look = CFrame.lookAt(from, target)
	head.CFrame = look
	barrel.CFrame = look * CFrame.new(0, 0, -2)
	return (look * CFrame.new(0, 0, -3.5)).Position
end

local function turretStep(plot: Model, owner: Player, t: number)
	local turret = plot:FindFirstChild("Turret") :: Model?
	local intruders = intruderSince[plot]
	if not intruders then
		intruders = {}
		intruderSince[plot] = intruders
	end
	-- Чужаки на базе: запоминаем, с какого момента стоят (нужно и без турели — чтобы не стрелять сразу после покупки)
	local clock = os.clock()
	for _, other in Players:GetPlayers() do
		local root = if other ~= owner then rootOf(other) else nil
		if root and PlotService.InPlot(plot, root.Position) then
			intruders[other] = intruders[other] or clock
		else
			intruders[other] = nil
		end
	end
	for other in intruders do
		if not other.Parent then
			intruders[other] = nil
		end
	end

	if not turret then
		return
	end
	local stats = Config.Defense.Turret[DataService.Get(owner, "TurretLevel")]
	if not stats or t - (lastTurretShot[plot] or -math.huge) < stats.Cooldown then
		return
	end
	local head = turret:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end
	local origin = head.Position

	local best: Player? = nil
	local bestDistance = stats.Range
	local function consider(candidate: Player)
		local root = rootOf(candidate)
		if not root then
			return
		end
		local distance = (root.Position - origin).Magnitude
		if distance <= bestDistance then
			best = candidate
			bestDistance = distance
		end
	end
	for thief, carry in StealService.GetCarries() do
		if carry.Owner == owner and thief ~= owner then
			consider(thief)
		end
	end
	for other, since in intruders do
		if clock - since >= INTRUDER_DELAY then
			consider(other)
		end
	end
	if not best then
		return
	end
	local targetRoot = rootOf(best :: Player)
	if not targetRoot then
		return
	end
	lastTurretShot[plot] = t
	local barrelEnd = aimTurret(turret, targetRoot.Position)
	Remotes.Fx:FireAllClients("Turret", { From = barrelEnd, To = targetRoot.Position })
	StealService.Knock(best :: Player, origin, TURRET_POWER, stats.Stun)
	Remotes.Notify:FireClient(best :: Player, "TurretHit", nil, "error")
	-- Чужак получает заряд и заново «копит» время на базе
	intruders[best :: Player] = clock
end

local function flashLaser(laser: BasePart)
	laser.Transparency = 0
	laser.Color = Color3.fromRGB(255, 160, 160)
	task.delay(0.35, function()
		if laser.Parent then
			laser.Transparency = LASER_TRANSPARENCY
			laser.Color = Color3.fromRGB(255, 40, 40)
		end
	end)
end

local function laserStep(plot: Model, owner: Player, t: number)
	local laser = plot:FindFirstChild("LaserGate") :: BasePart?
	if not laser then
		return
	end
	local stats = Config.Defense.LaserGate[DataService.Get(owner, "LaserLevel")]
	if not stats or t - (lastLaserHit[plot] or -math.huge) < stats.Cooldown then
		return
	end
	local floor = floorOf(plot)
	local size = floor.Size
	for thief, carry in StealService.GetCarries() do
		if carry.Owner ~= owner or thief == owner then
			continue
		end
		local root = rootOf(thief)
		if not root then
			continue
		end
		-- Координаты относительно пола: вход — край -Z
		local localPos = floor.CFrame:PointToObjectSpace(root.Position)
		local nearGate = math.abs(localPos.Z + size.Z / 2) <= LASER_DISTANCE
		if nearGate and math.abs(localPos.X) <= size.X / 2 and localPos.Y > -5 and localPos.Y < 20 then
			lastLaserHit[plot] = t
			flashLaser(laser)
			Remotes.Fx:FireAllClients("Laser", { Position = root.Position })
			StealService.Knock(thief, laser.Position, LASER_POWER, stats.Stun)
			Remotes.Notify:FireClient(thief, "LaserHit", nil, "error")
			break
		end
	end
end

local function step()
	local t = os.clock()
	for _, plot in PlotService.AllPlots() do
		local owner = PlotService.GetOwner(plot)
		if not owner or not DataService.IsLoaded(owner) then
			continue
		end
		turretStep(plot, owner, t)
		laserStep(plot, owner, t)
	end
end

-- ===== Жизненный цикл =====

function DefenseService.OnLoaded(player: Player)
	DefenseService.Refresh(player)
end

-- Вызывать ДО PlotService.Release: убирает турель и лазер с базы уходящего игрока
function DefenseService.OnPlayerRemoving(player: Player)
	local plot = PlotService.GetPlot(player)
	if plot then
		destroyVisuals(plot)
	end
	for _, intruders in intruderSince do
		intruders[player] = nil
	end
end

function DefenseService.Start()
	Remotes.UpgradeDefense.OnServerInvoke = function(player, kind)
		return DefenseService.Upgrade(player, kind)
	end

	task.spawn(function()
		while true do
			task.wait(TICK)
			local ok, err = pcall(step)
			if not ok then
				warn("[DefenseService]", err)
			end
		end
	end)
end

return DefenseService
