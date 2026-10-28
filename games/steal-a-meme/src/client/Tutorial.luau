-- Обучение новичка (атрибут игрока TutorialDone == 0): карточка с шагом внизу по центру и
-- локальный луч от персонажа к цели. Шаги: купить мема -> доход -> украсть -> защитить базу.
-- Прогресс читается из атрибутов (SlotsUsed, Stolen, LockedUntil базы). В конце или по «Пропустить»
-- клиент сообщает серверу Remotes.TutorialDone — награды/сохранение решает сервер.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Locale = require(Shared:WaitForChild("Locale"))
local UiKit = require(script.Parent:WaitForChild("UiKit"))
local Util = require(script.Parent:WaitForChild("Util"))

local COLORS = UiKit.Colors
local create = UiKit.create
local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local TOTAL_STEPS = 4
local INCOME_STEP_TIME = 7
local STEAL_SKIP_HINT = 90 -- через столько секунд кнопка «Пропустить» на шаге кражи становится заметной
local PROTECT_STEP_TIME = 15
local CARD_BOTTOM = 128 -- над панелью состояния и стандартной панелью предметов
local BEAM_COLOR = Color3.fromRGB(255, 220, 60)
local POLL = 0.2

local Tutorial = {}

-- Ближайший пол чужой занятой базы (или nil)
local function nearestOtherFloor(from: Vector3): BasePart?
	local folder = workspace:FindFirstChild("Plots")
	if not folder then
		return nil
	end
	local best: BasePart? = nil
	local bestDistance = math.huge
	for _, plot in folder:GetChildren() do
		local owner = Util.num(plot, "OwnerUserId")
		local floor = plot:FindFirstChild("Floor")
		if owner ~= 0 and owner ~= player.UserId and floor and floor:IsA("BasePart") then
			local distance = (floor.Position - from).Magnitude
			if distance < bestDistance then
				best, bestDistance = floor, distance
			end
		end
	end
	return best
end

local function run(ctx)
	-- Ждём загрузки данных: до неё TutorialDone ещё не известен
	while not Util.bool(player, "DataLoaded") do
		player:GetAttributeChangedSignal("DataLoaded"):Wait()
	end
	if player:GetAttribute("TutorialDone") == nil then
		task.wait(3) -- атрибут мог прийти чуть позже DataLoaded
	end
	if player:GetAttribute("TutorialDone") ~= 0 then
		return
	end

	-- ===== Карточка шага =====
	local card = create("Frame", {
		Name = "Tutorial",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -CARD_BOTTOM),
		Size = UDim2.fromOffset(440, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = COLORS.Panel,
		BackgroundTransparency = 0.1,
		Parent = ctx.Gui,
	}, {
		UiKit.corner(12),
		UiKit.padding(10),
		create("UIStroke", { Color = COLORS.Gold, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	})
	ctx.Scale(card)

	local header = UiKit.text({
		Text = "",
		TextSize = 14,
		TextColor3 = COLORS.Gold,
		Size = UDim2.new(1, -110, 0, 18),
		Parent = card,
	})
	local message = UiKit.text({
		Text = "",
		TextSize = 18,
		TextWrapped = true,
		Position = UDim2.fromOffset(0, 22),
		Size = UDim2.new(1, -110, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = card,
	})
	local pop = create("UIScale", { Parent = message })
	local skip = UiKit.button({
		Text = Locale.T("TutorialSkip"),
		TextSize = 15,
		TextColor3 = COLORS.Muted,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(100, 34),
		BackgroundColor3 = COLORS.PanelLight,
		Parent = card,
	})
	local skipStroke = create("UIStroke", {
		Color = COLORS.Gold,
		Thickness = 2,
		Enabled = false,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = skip,
	})

	-- ===== Луч к цели (виден только этому игроку) =====
	local beam: Beam? = nil
	local fromAttachment: Attachment? = nil
	local toAttachment = create("Attachment", { Name = "TutorialTarget", Parent = workspace.Terrain })

	local function clearBeam()
		if beam then
			beam:Destroy()
		end
		if fromAttachment then
			fromAttachment:Destroy()
		end
		beam, fromAttachment = nil, nil
	end

	local function pointBeam(target: Vector3?)
		local _, root = Util.character()
		if not target or not root then
			clearBeam()
			return
		end
		toAttachment.WorldPosition = target
		if beam and fromAttachment and fromAttachment.Parent == root then
			return
		end
		clearBeam()
		local a0 = create("Attachment", { Name = "TutorialFrom", Parent = root })
		beam = create("Beam", {
			Name = "TutorialBeam",
			Attachment0 = a0,
			Attachment1 = toAttachment,
			Color = ColorSequence.new(BEAM_COLOR),
			Transparency = NumberSequence.new(0.2, 0.5),
			Width0 = 0.8,
			Width1 = 0.8,
			CurveSize0 = 6,
			CurveSize1 = -6,
			Segments = 20,
			FaceCamera = true,
			LightEmission = 1,
			Parent = root,
		})
		fromAttachment = a0
	end

	-- ===== Завершение =====
	local finished = false
	local function finish(completed: boolean)
		if finished then
			return
		end
		finished = true
		clearBeam()
		toAttachment:Destroy()
		card:Destroy()
		Remotes:WaitForChild("TutorialDone"):FireServer()
		if completed then
			ctx.Toast(Locale.T("TutorialFinished"), "success")
		end
	end
	skip.Activated:Connect(function()
		finish(false)
	end)
	player.CharacterRemoving:Connect(clearBeam)

	local function emphasizeSkip(on: boolean)
		skip.BackgroundColor3 = if on then COLORS.Gold else COLORS.PanelLight
		skip.TextColor3 = if on then COLORS.Panel else COLORS.Muted
		skipStroke.Enabled = on
	end

	local function setStep(step: number, key: string)
		header.Text = Locale.T("TutorialStep", { Step = step, Total = TOTAL_STEPS })
		message.Text = Locale.T(key)
		emphasizeSkip(false)
		pop.Scale = 1.15
		TweenService:Create(pop, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end

	-- Опрос условия шага; target() — куда вести луч (nil — без луча). Пока игрок несёт мема,
	-- карточку прячем: по центру уже баннер кражи.
	local function waitStep(done: () -> boolean, target: (() -> Vector3?)?, timeout: number?)
		local started = os.clock()
		while not finished do
			if done() or (timeout and os.clock() - started >= timeout) then
				return
			end
			card.Visible = Util.str(player, "Carrying") == ""
			pointBeam(if target then target() else nil)
			task.wait(POLL)
		end
	end

	-- Ковёр ищем в фоне (при StreamingEnabled может подгрузиться позже)
	local carpet: BasePart? = nil
	-- Ждём без предела по времени (пока туториал идёт): игрок мог заспавниться далеко от дорожки,
	-- и ковёр придёт только когда он подойдёт ближе. Позицию запоминаем — после выгрузки она та же.
	task.spawn(function()
		while not finished and not carpet do
			local map = workspace:FindFirstChild("Map")
			local found = map and map:FindFirstChild("Carpet")
			if found and found:IsA("BasePart") then
				carpet = found
			else
				task.wait(1)
			end
		end
	end)

	-- Шаг 1: купить мема на дорожке
	setStep(1, "TutorialBuy")
	local slots = Util.num(player, "SlotsUsed")
	waitStep(function()
		local now = Util.num(player, "SlotsUsed")
		if now < slots then
			slots = now -- продал мема — считаем от нового значения
		end
		return now > slots
	end, function()
		return if carpet then carpet.Position + Vector3.new(0, carpet.Size.Y / 2 + 2, 0) else nil
	end)

	-- Шаг 2: доход
	if not finished then
		setStep(2, "TutorialIncome")
		waitStep(function()
			return false
		end, nil, INCOME_STEP_TIME)
	end

	-- Шаг 3: украсть и донести домой
	if not finished then
		setStep(3, "TutorialSteal")
		local stolen = Util.num(player, "Stolen")
		local started = os.clock()
		waitStep(function()
			return Util.num(player, "Stolen") > stolen
		end, function()
			local _, root = Util.character()
			local floor = if root then nearestOtherFloor(root.Position) else nil
			emphasizeSkip(floor == nil or os.clock() - started >= STEAL_SKIP_HINT)
			return if floor then floor.Position + Vector3.new(0, floor.Size.Y / 2 + 3, 0) else nil
		end)
	end

	-- Шаг 4: защита базы
	if not finished then
		setStep(4, "TutorialProtect")
		waitStep(function()
			return Util.num(Util.myPlot(), "LockedUntil") > Util.now()
		end, nil, PROTECT_STEP_TIME)
	end

	finish(true)
end

function Tutorial.Start(ctx)
	task.spawn(run, ctx)
end

return Tutorial
