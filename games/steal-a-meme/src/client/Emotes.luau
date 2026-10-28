-- Эмоции: окно-сетка из Config.Emotes (закрытые геймпассом — с замком и покупкой) и процедурная
-- анимация персонажа по Fx "Emote" { UserId, Emote } — у любого игрока, включая себя.
--
-- Анимация двигает суставы (Motor6D.Transform): R15 — RightShoulder/LeftShoulder (+ локти),
-- Waist, Root, Neck; R6 — "Right Shoulder"/"Left Shoulder", RootJoint, Neck в Torso/HumanoidRootPart.
-- Почему RunService.PreSimulation: Animator записывает Transform из играющих треков (бег, idle)
-- до PreSimulation, а рендер идёт после — значение, поставленное здесь, перекрывает анимацию на
-- этот кадр и не «дерётся» с ней (в RenderStepped Animator затёр бы его на следующем шаге,
-- а в Heartbeat кадр уже отрисован с позой Animator). Мы полностью заменяем Transform своих
-- суставов, а не умножаем: так значение не копится на суставах, которые Animator не трогает.
-- В конце Transform сбрасывается в identity (Animator перезапишет своё со следующего кадра).
--
-- Поза задаётся поворотом D в пространстве Part0 (торса): ось X — вправо, Y — вверх, -Z — вперёд.
-- Для любого рига T = rot(C0)⁻¹ · D · rot(C0), поэтому одни и те же позы работают на R6 и R15.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Locale = require(Shared:WaitForChild("Locale"))
local UiKit = require(script.Parent:WaitForChild("UiKit"))
local Util = require(script.Parent:WaitForChild("Util"))

local COLORS = UiKit.Colors
local create = UiKit.create
local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local MAX_DISTANCE = 200 -- дальше эмоции не анимируем
local FADE_IN = 0.2
local FADE_OUT = 0.3
local TEAR_COLOR = Color3.fromRGB(90, 180, 255)

local Emotes = {}

local function rx(deg: number): CFrame
	return CFrame.Angles(math.rad(deg), 0, 0)
end
local function ry(deg: number): CFrame
	return CFrame.Angles(0, math.rad(deg), 0)
end
local function rz(deg: number): CFrame
	return CFrame.Angles(0, 0, math.rad(deg))
end

-- Позы: (t — секунды с начала, w — 0..1 плавный вход/выход, duration) -> { сустав = D }.
-- Суставы: R, L (плечи), RE, LE (локти, только R15), Waist (только R15), Root, Neck.
type Pose = { [string]: CFrame }
local PROCS: { [string]: (number, number, number) -> Pose } = {
	Wave = function(t, w)
		local s = math.sin(t * 12)
		return { R = rz(w * (155 + 18 * s)), RE = rz(w * (20 * s)) }
	end,
	Clap = function(t, w)
		local s = math.abs(math.sin(t * 9))
		local inward = 12 + 26 * s
		return {
			R = ry(w * inward) * rx(w * 85),
			L = ry(-w * inward) * rx(w * 85),
		}
	end,
	SixSeven = function(t, w)
		local s = math.sin(t * 7)
		return {
			R = rx(w * (55 + 22 * s)),
			L = rx(w * (55 - 22 * s)),
			RE = rx(w * 45),
			LE = rx(w * 45),
			Neck = rz(w * 6 * s),
		}
	end,
	Spin = function(t, w, duration)
		-- Целое число оборотов за эмоцию, чтобы в конце не было рывка
		local turns = math.max(1, math.floor(duration * 1.5 + 0.5))
		local angle = 360 * turns * math.clamp(t / duration, 0, 1)
		return { Root = ry(angle), R = rz(w * 60), L = rz(-w * 60) }
	end,
	Flex = function(t, w)
		local pump = 8 * math.sin(t * 6)
		return {
			R = rz(w * (95 + pump)),
			L = rz(-w * (95 + pump)),
			RE = rz(w * 100),
			LE = rz(-w * 100),
			Neck = rx(w * 12),
		}
	end,
	Floss = function(t, w)
		local s = math.sin(t * 8)
		local c = math.cos(t * 8)
		return {
			R = rz(w * 35 * s) * rx(w * 25 * c),
			L = rz(w * 35 * s) * rx(-w * 25 * c),
			Root = CFrame.new(-0.35 * s * w, 0, 0) * rz(-w * 6 * s),
		}
	end,
	Dab = function(_, w)
		return {
			R = rz(w * 130) * rx(w * 20),
			L = ry(-w * 55) * rx(w * 105),
			LE = rx(w * 70),
			Neck = rz(-w * 15) * rx(-w * 30),
		}
	end,
	Cry = function(t, w)
		local shake = 4 * math.sin(t * 25)
		return {
			R = rz(w * shake) * ry(w * 30) * rx(w * 125),
			L = rz(w * shake) * ry(-w * 30) * rx(w * 125),
			RE = rx(w * 80),
			LE = rx(w * 80),
			Neck = rx(w * (-20 + 5 * math.sin(t * 25))),
		}
	end,
}

-- Суставы персонажа по ключам поз (R15 или R6)
local function findJoints(character: Model): { [string]: Motor6D }
	local found: { [string]: Motor6D } = {}
	local function take(key: string, partName: string, jointName: string)
		local part = character:FindFirstChild(partName)
		local joint = part and part:FindFirstChild(jointName)
		if joint and joint:IsA("Motor6D") then
			found[key] = joint
		end
	end
	if character:FindFirstChild("UpperTorso") then
		take("R", "RightUpperArm", "RightShoulder")
		take("L", "LeftUpperArm", "LeftShoulder")
		take("RE", "RightLowerArm", "RightElbow")
		take("LE", "LeftLowerArm", "LeftElbow")
		take("Waist", "UpperTorso", "Waist")
		take("Root", "LowerTorso", "Root")
		take("Neck", "Head", "Neck")
	else
		take("R", "Torso", "Right Shoulder")
		take("L", "Torso", "Left Shoulder")
		take("Root", "HumanoidRootPart", "RootJoint")
		take("Neck", "Torso", "Neck")
	end
	return found
end

-- Поворот в пространстве Part0 -> Transform в системе сустава (C0)
local function toTransform(joint: Motor6D, pose: CFrame): CFrame
	local basis = joint.C0.Rotation
	return basis:Inverse() * pose * basis
end

type Active = {
	Character: Model,
	Humanoid: Humanoid,
	Joints: { [string]: Motor6D },
	Touched: { [Motor6D]: boolean },
	Proc: (number, number, number) -> Pose,
	Started: number,
	Duration: number,
	Gui: BillboardGui?,
	Tears: boolean,
	NextTear: number,
}

local active: { [Model]: Active } = {}
local stepConnection: RBXScriptConnection? = nil

local function stop(character: Model)
	local entry = active[character]
	if not entry then
		return
	end
	active[character] = nil
	for joint in entry.Touched do
		if joint.Parent then
			joint.Transform = CFrame.identity
		end
	end
	if entry.Gui then
		entry.Gui:Destroy()
	end
	if next(active) == nil and stepConnection then
		stepConnection:Disconnect()
		stepConnection = nil
	end
end

local function tear(head: BasePart)
	local side = if math.random() < 0.5 then -0.35 else 0.35
	local start = (head.CFrame * CFrame.new(side, 0.1, -0.55)).Position
	local drop = create("Part", {
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Material = Enum.Material.Neon,
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 0.25,
		Color = TEAR_COLOR,
		CFrame = CFrame.new(start),
		Parent = workspace.CurrentCamera or workspace,
	})
	TweenService:Create(drop, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		CFrame = CFrame.new(start + Vector3.new(side * 0.8, -2.5, 0)),
		Transparency = 1,
	}):Play()
	Debris:AddItem(drop, 0.7)
end

local function step()
	local now = os.clock()
	for character, entry in active do
		local t = now - entry.Started
		if t >= entry.Duration or entry.Humanoid.Health <= 0 or not character.Parent then
			stop(character)
			continue
		end
		local fade = math.min(t / FADE_IN, (entry.Duration - t) / FADE_OUT, 1)
		local w = fade * fade * (3 - 2 * fade) -- smoothstep
		local ok, pose = pcall(entry.Proc, t, w, entry.Duration)
		if not ok then
			stop(character)
			continue
		end
		for key, cframe in pose do
			local joint = entry.Joints[key]
			if joint and joint.Parent then
				joint.Transform = toTransform(joint, cframe)
				entry.Touched[joint] = true
			end
		end
		if entry.Tears and now >= entry.NextTear then
			entry.NextTear = now + 0.12
			local head = character:FindFirstChild("Head")
			if head and head:IsA("BasePart") then
				tear(head)
			end
		end
	end
end

-- Крупный эмодзи над головой на время эмоции
local function headEmoji(character: Model, face: string, duration: number): BillboardGui?
	local head = character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return nil
	end
	local gui = create("BillboardGui", {
		Name = "Emote",
		Adornee = head,
		Size = UDim2.fromOffset(80, 80),
		StudsOffsetWorldSpace = Vector3.new(0, 3, 0),
		AlwaysOnTop = true,
		LightInfluence = 0,
		MaxDistance = 120,
		ResetOnSpawn = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local label = UiKit.text({
		Text = face,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		Parent = gui,
	})
	local pop = create("UIScale", { Scale = 0.2, Parent = label })
	TweenService:Create(pop, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(math.max(0, duration - 0.3), function()
		if label.Parent then
			TweenService:Create(label, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
		end
	end)
	return gui
end

local function play(userId: number, emoteId: string)
	local emote = Config.GetEmote(emoteId)
	local who = Players:GetPlayerByUserId(userId)
	local character = who and who.Character
	if not emote or not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return
	end
	local camera = workspace.CurrentCamera
	if camera and (camera.CFrame.Position - root.Position).Magnitude > MAX_DISTANCE then
		return
	end

	stop(character)
	local duration = Config.EmoteDuration
	local proc = PROCS[emote.Proc]
	active[character] = {
		Character = character,
		Humanoid = humanoid,
		Joints = findJoints(character),
		Touched = {},
		Proc = proc or function()
			return {}
		end,
		Started = os.clock(),
		Duration = duration,
		Gui = headEmoji(character, emote.Face, duration),
		Tears = emote.Proc == "Cry",
		NextTear = 0,
	}
	if not stepConnection then
		stepConnection = RunService.PreSimulation:Connect(step)
	end
end

-- ===== Окно эмоций =====
local function isLocked(emote): boolean
	return emote.Pass ~= nil and not Util.bool(player, "Pass_" .. emote.Pass)
end

local function buildWindow(ctx)
	local window, body = UiKit.window(ctx.Gui, Locale.T("EmotesTitle"), Vector2.new(480, 340))
	window.Name = "EmotesWindow"
	ctx.Register("Emotes", window)

	local grid = create("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = body,
	}, {
		create("UIGridLayout", {
			CellSize = UDim2.new(0.25, -8, 0, 104),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		create("UIPadding", { PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 2) }),
	})

	local cells = {}
	local lastEmoteAt = -math.huge
	for order, emote in Config.Emotes do
		local cell = UiKit.button({
			Text = "",
			BackgroundColor3 = COLORS.PanelLight,
			LayoutOrder = order,
			Parent = grid,
		})
		UiKit.text({
			Text = emote.Face,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.new(0, 8, 0, 6),
			Size = UDim2.new(1, -16, 0, 52),
			Parent = cell,
		})
		UiKit.text({
			Text = Locale.Name(emote),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.new(0, 4, 0, 60),
			Size = UDim2.new(1, -8, 0, 20),
			Parent = cell,
		}, { create("UITextSizeConstraint", { MaxTextSize = 16, MinTextSize = 8 }) })
		local lock = UiKit.text({
			Text = Locale.T("EmotePackLocked"),
			TextScaled = true,
			TextColor3 = COLORS.Gold,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.new(0, 4, 0, 82),
			Size = UDim2.new(1, -8, 0, 16),
			Parent = cell,
		}, { create("UITextSizeConstraint", { MaxTextSize = 13, MinTextSize = 7 }) })
		cells[emote.Id] = { Emote = emote, Cell = cell, Lock = lock }

		cell.Activated:Connect(function()
			if isLocked(emote) then
				Util.promptPass(emote.Pass, ctx.Toast)
				return
			end
			-- Перезарядку проверяет сервер; здесь только не спамим запросами
			local left = Config.EmoteCooldown - (os.clock() - lastEmoteAt)
			if left > 0 then
				ctx.Toast(Locale.T("EmoteWait", { Seconds = math.ceil(left) }), "error")
				return
			end
			lastEmoteAt = os.clock()
			Remotes:WaitForChild("Emote"):FireServer(emote.Id)
			window.Visible = false
		end)
	end

	local function render()
		for _, entry in cells do
			local locked = isLocked(entry.Emote)
			entry.Lock.Visible = locked
			entry.Cell.BackgroundColor3 = if locked then COLORS.Panel else COLORS.PanelLight
		end
	end
	local passes = {}
	for _, emote in Config.Emotes do
		if emote.Pass and not passes[emote.Pass] then
			passes[emote.Pass] = true
			player:GetAttributeChangedSignal("Pass_" .. emote.Pass):Connect(render)
		end
	end
	window:GetPropertyChangedSignal("Visible"):Connect(render)
	render()
end

function Emotes.Start(ctx)
	buildWindow(ctx)
	task.spawn(function()
		Remotes:WaitForChild("Fx").OnClientEvent:Connect(function(kind, data)
			if kind ~= "Emote" or type(data) ~= "table" then
				return
			end
			if type(data.UserId) == "number" and type(data.Emote) == "string" then
				play(data.UserId, data.Emote)
			end
		end)
	end)
	-- Персонаж удалён (респаун/выход) — сразу чистим запись
	Players.PlayerRemoving:Connect(function(who)
		if who.Character then
			stop(who.Character)
		end
	end)
end

return Emotes
