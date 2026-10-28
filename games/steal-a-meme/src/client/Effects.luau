-- Клиентские эффекты: отбрасывание с оглушением (Remotes.Knockback), разовые вспышки/конфетти
-- (Remotes.Fx), оттенок Ночью Смайлика по сезону (Хэллоуин — красноватый, Зима — холодный синий)
-- и табличка со здоровьем монстра.
-- Всё создаётся локально, без звуков и текстур по ID.
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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

local KNOCKBACK_TIME = 0.6 -- оглушение по умолчанию (старый вызов без второго аргумента)
local MAX_STUN = 4
local DIZZY_STUN = 1.5 -- с такого оглушения над головой крутятся звёздочки
local MAX_KNOCKBACK = 300 -- защита от странных значений: клиент не улетит за карту
local MAX_PIECES = 250 -- не больше стольких частиц конфетти одновременно
local VIRAL_COLOR = Color3.fromRGB(255, 80, 220)
local MONSTER_COLOR = Color3.fromRGB(255, 220, 40)
local BANANA_COLOR = Color3.fromRGB(255, 225, 50)
local ENERGY_COLOR = Color3.fromRGB(80, 255, 120)

-- Оттенок ночи по сезону (Season в ReplicatedStorage); без сезона — как на Хэллоуин
local NIGHT_TINTS = {
	Halloween = { TintColor = Color3.fromRGB(255, 222, 215), Saturation = -0.15, Contrast = 0.12, Brightness = -0.03 },
	Winter = { TintColor = Color3.fromRGB(205, 225, 255), Saturation = -0.1, Contrast = 0.1, Brightness = -0.02 },
}
local NO_TINT = { TintColor = Color3.new(1, 1, 1), Saturation = 0, Contrast = 0, Brightness = 0 }

local Effects = {}

-- ===== Отбрасывание =====
local function shakeCamera(humanoid: Humanoid, duration: number, strength: number)
	task.spawn(function()
		local started = os.clock()
		while os.clock() - started < duration and humanoid.Parent do
			local fade = 1 - (os.clock() - started) / duration
			humanoid.CameraOffset = Vector3.new(
				(math.random() - 0.5) * strength * fade,
				(math.random() - 0.5) * strength * fade,
				0
			)
			task.wait()
		end
		humanoid.CameraOffset = Vector3.zero
	end)
end

-- «💫» над своей головой на время оглушения (только у себя)
local dizzyGui: BillboardGui? = nil
local function showDizzy(character: Model, duration: number)
	if dizzyGui then
		dizzyGui:Destroy()
	end
	local head = character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	local gui = create("BillboardGui", {
		Name = "Dizzy",
		Adornee = head,
		Size = UDim2.fromOffset(60, 60),
		StudsOffsetWorldSpace = Vector3.new(0, 2.2, 0),
		AlwaysOnTop = true,
		LightInfluence = 0,
		ResetOnSpawn = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local label = UiKit.text({
		Text = "💫",
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		Parent = gui,
	})
	TweenService:Create(label, TweenInfo.new(0.6, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1), { Rotation = 360 }):Play()
	dizzyGui = gui
	task.delay(duration, function()
		if dizzyGui == gui then
			dizzyGui = nil
		end
		gui:Destroy()
	end)
end

local knockToken = 0
local function onKnockback(velocity: any, stun: any)
	if typeof(velocity) ~= "Vector3" or velocity ~= velocity then
		return
	end
	local duration = if type(stun) == "number" and stun == stun then math.clamp(stun, 0, MAX_STUN) else KNOCKBACK_TIME
	if velocity.Magnitude > MAX_KNOCKBACK then
		velocity = velocity.Unit * MAX_KNOCKBACK
	end
	local character, root, humanoid = Util.character()
	if not character or not root or not humanoid or humanoid.Health <= 0 then
		return
	end
	if duration <= 0 then
		-- stun = 0 (ракетные ботинки): просто толчок без падения и тряски камеры.
		-- В Physics + сразу GettingUp персонаж «вставал» и терял скорость; прыжок сохраняет полёт.
		-- Если игрок сейчас оглушён — не прерываем оглушение, только добавляем скорость.
		if humanoid:GetState() ~= Enum.HumanoidStateType.Physics then
			humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		end
		root.AssemblyLinearVelocity = velocity
		return
	end
	knockToken += 1
	local token = knockToken
	humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	root.AssemblyLinearVelocity = velocity
	shakeCamera(humanoid, 0.35, 0.6)
	if duration >= DIZZY_STUN then
		showDizzy(character, duration)
	end
	task.delay(duration, function()
		-- Новый удар за это время продлевает полёт
		if token == knockToken and humanoid.Parent and humanoid.Health > 0 then
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end)
end

-- ===== Вспышки и конфетти =====
local livePieces = 0

local function fxParent(): Instance
	return workspace.CurrentCamera or workspace
end

local function piece(position: Vector3, size: Vector3, color: Color3, shape: Enum.PartType?): Part
	return create("Part", {
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Material = Enum.Material.Neon,
		Shape = shape or Enum.PartType.Block,
		Size = size,
		Color = color,
		CFrame = CFrame.new(position),
		Parent = fxParent(),
	})
end

-- Разлетающиеся кусочки цветов colors
local function confetti(position: Vector3, colors: { Color3 }, count: number, spread: number)
	count = math.min(count, MAX_PIECES - livePieces)
	for _ = 1, count do
		livePieces += 1
		local size = 0.25 + math.random() * 0.35
		local part = piece(position, Vector3.new(size, size, size * 0.4), colors[math.random(#colors)])
		local direction = Vector3.new(math.random() - 0.5, 0.6 + math.random(), math.random() - 0.5).Unit
		local target = position + direction * (spread * (0.5 + math.random() * 0.5))
		local spin = CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
		local fly = TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(part, fly, { CFrame = CFrame.new(target) * spin }):Play()
		TweenService:Create(part, TweenInfo.new(0.5, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, 0.5), {
			Transparency = 1,
		}):Play()
		Debris:AddItem(part, 1.1)
		task.delay(1.1, function()
			livePieces -= 1
		end)
	end
end

-- Расширяющийся светящийся шар
local function flash(position: Vector3, color: Color3, size: number, duration: number)
	local ball = piece(position, Vector3.one, color, Enum.PartType.Ball)
	ball.Transparency = 0.2
	TweenService:Create(ball, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.one * size,
		Transparency = 1,
	}):Play()
	Debris:AddItem(ball, duration + 0.1)
end

-- Всплывающая надпись в мире (поднимается и тает)
local function floatText(position: Vector3, text: string, color: Color3)
	local anchor = piece(position, Vector3.one * 0.2, color)
	anchor.Transparency = 1
	local gui = create("BillboardGui", {
		Size = UDim2.fromOffset(160, 50),
		AlwaysOnTop = true,
		LightInfluence = 0,
		MaxDistance = 120,
		Parent = anchor,
	})
	local label = UiKit.text({
		Text = text,
		TextScaled = true,
		TextColor3 = color,
		TextStrokeTransparency = 0,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		Parent = gui,
	})
	local rise = TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(anchor, rise, { CFrame = CFrame.new(position + Vector3.new(0, 4, 0)) }):Play()
	TweenService:Create(label, TweenInfo.new(0.4, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, 0.6), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	Debris:AddItem(anchor, 1.1)
end

-- Белая вспышка экрана и крупный текст при своём перерождении
local function rebirthScreen()
	local overlay = create("ScreenGui", {
		Name = "RebirthFlash",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 50,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local white = create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0,
		Parent = overlay,
	})
	local label = UiKit.text({
		Text = "♻️ " .. Locale.T("FxRebirth"),
		TextScaled = true,
		TextColor3 = COLORS.Purple,
		TextStrokeTransparency = 0,
		TextStrokeColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromScale(0.8, 0.18),
		Parent = overlay,
	})
	local pop = create("UIScale", { Scale = 0.3, Parent = label })
	TweenService:Create(white, TweenInfo.new(0.9), { BackgroundTransparency = 1 }):Play()
	TweenService:Create(pop, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(1.6, function()
		TweenService:Create(label, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)
	Debris:AddItem(overlay, 2.3)
end

local function onFx(kind: any, data: any)
	if type(kind) ~= "string" or type(data) ~= "table" then
		return
	end
	local position = data.Position
	local hasPosition = typeof(position) == "Vector3"

	-- Эффекты далеко от игрока не рисуем — экономим телефоны
	if hasPosition then
		local _, root = Util.character()
		if root and (root.Position - position).Magnitude > 250 then
			return
		end
	end

	if kind == "Slap" and hasPosition then
		flash(position, Color3.new(1, 1, 1), 6, 0.25)
		confetti(position, { Color3.new(1, 1, 1), Color3.fromRGB(255, 240, 200) }, 10, 4)
	elseif kind == "Bought" and hasPosition then
		local rarityId = if type(data.Rarity) == "string" then data.Rarity else "Common"
		local color = Config.GetRarity(rarityId).Color
		local colors = if rarityId == "Secret"
			then { Color3.new(1, 1, 1), COLORS.Gold, Color3.fromRGB(40, 40, 40) }
			else { color, color, Color3.new(1, 1, 1), COLORS.Gold }
		confetti(position, colors, 24, 7)
	elseif kind == "Stolen" and hasPosition then
		flash(position, COLORS.Red, 5, 0.3)
		confetti(position, { COLORS.Red, Color3.fromRGB(255, 160, 160) }, 12, 5)
	elseif kind == "Delivered" and hasPosition then
		local mine = data.UserId == player.UserId
		confetti(position, { COLORS.Green, COLORS.Gold, Color3.new(1, 1, 1) }, if mine then 36 else 16, 8)
	elseif kind == "Merged" and hasPosition then
		flash(position, VIRAL_COLOR, 9, 0.45)
		confetti(position, { VIRAL_COLOR, COLORS.Purple, COLORS.Gold, Color3.new(1, 1, 1) }, 40, 9)
	elseif kind == "MonsterHit" and hasPosition then
		flash(position, MONSTER_COLOR, 4, 0.2)
		confetti(position, { MONSTER_COLOR, Color3.new(1, 1, 1) }, 8, 4)
	elseif kind == "Invisible" and hasPosition then
		flash(position, Color3.fromRGB(170, 170, 180), 8, 0.5)
		confetti(position, { Color3.fromRGB(150, 150, 160), Color3.fromRGB(210, 210, 220), Color3.new(1, 1, 1) }, 18, 5)
	elseif kind == "Banana" and hasPosition then
		flash(position, BANANA_COLOR, 6, 0.3)
		confetti(position, { BANANA_COLOR, Color3.fromRGB(255, 240, 150), Color3.fromRGB(120, 90, 30) }, 16, 6)
		floatText(position + Vector3.new(0, 3, 0), Locale.T("FxSlip"), BANANA_COLOR)
	elseif kind == "Energy" and hasPosition then
		flash(position, ENERGY_COLOR, 5, 0.25)
		confetti(position, { ENERGY_COLOR, Color3.fromRGB(200, 255, 120), Color3.new(1, 1, 1) }, 20, 9)
	elseif kind == "Rebirth" then
		if data.UserId == player.UserId then
			rebirthScreen()
		end
		-- Конфетти над перерождённым игроком (если он рядом)
		local who = if type(data.UserId) == "number" then Players:GetPlayerByUserId(data.UserId) else nil
		local character = who and who.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			confetti(root.Position + Vector3.new(0, 3, 0), { COLORS.Purple, COLORS.Gold, Color3.new(1, 1, 1) }, 40, 10)
		end
	end
end

-- ===== Ночь Смайлика: лёгкий оттенок по сезону поверх освещения сервера =====
local function startNightTint()
	local tint = create("ColorCorrectionEffect", {
		Name = "SmileyNightLocal",
		TintColor = Color3.new(1, 1, 1),
		Parent = Lighting,
	})
	local fade = TweenInfo.new(2.5, Enum.EasingStyle.Sine)
	local function render()
		local active = Util.bool(ReplicatedStorage, "NightActive")
		local goal = if active then NIGHT_TINTS[Util.str(ReplicatedStorage, "Season")] or NIGHT_TINTS.Halloween else NO_TINT
		TweenService:Create(tint, fade, goal):Play()
	end
	ReplicatedStorage:GetAttributeChangedSignal("NightActive"):Connect(render)
	ReplicatedStorage:GetAttributeChangedSignal("Season"):Connect(render)
	render()
end

-- ===== Монстр: табличка с полосой здоровья =====
local function trackMonster(model: Instance): () -> ()
	local gui = create("BillboardGui", {
		Name = "Monster",
		Size = UDim2.fromOffset(220, 74),
		SizeOffset = Vector2.new(0, 0.5),
		AlwaysOnTop = true,
		MaxDistance = 300,
		LightInfluence = 0,
		ResetOnSpawn = false,
	})
	local name = UiKit.text({
		Text = Locale.T("MonsterName"),
		TextSize = 20,
		TextColor3 = MONSTER_COLOR,
		TextStrokeTransparency = 0,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 24),
		Parent = gui,
	})
	local bar = create("Frame", {
		Position = UDim2.fromOffset(10, 26),
		Size = UDim2.new(1, -20, 0, 18),
		BackgroundColor3 = Color3.fromRGB(30, 20, 20),
		Parent = gui,
	}, { UiKit.corner(6), create("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 2 }) })
	local fill = create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = COLORS.Red,
		Parent = bar,
	}, { UiKit.corner(6) })
	local hpText = UiKit.text({
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.3,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
		Parent = bar,
	})
	local carrying = UiKit.text({
		TextSize = 16,
		TextColor3 = COLORS.Red,
		TextStrokeTransparency = 0,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 48),
		Size = UDim2.new(1, 0, 0, 22),
		Parent = gui,
	})

	local function render()
		local hp, maxHp = Util.num(model, "Hp"), Util.num(model, "MaxHp")
		local ratio = if maxHp > 0 then math.clamp(hp / maxHp, 0, 1) else 0
		TweenService:Create(fill, TweenInfo.new(0.15), { Size = UDim2.fromScale(ratio, 1) }):Play()
		hpText.Text = math.max(0, math.ceil(hp)) .. " / " .. math.ceil(maxHp)
		local memeId = Util.str(model, "Carrying")
		carrying.Text = if memeId ~= "" then "😈 " .. Locale.MemeName(memeId) else ""
		name.Text = (if memeId ~= "" then "😈 " else "") .. Locale.T("MonsterName")
	end

	local function adorn()
		local part = Util.mainPart(model)
		gui.Adornee = part
		local height = if part then part.Size.Y else 6
		if model:IsA("Model") then
			local ok, size = pcall(model.GetExtentsSize, model)
			if ok and size.Y > 0 then
				height = size.Y
			end
		end
		gui.StudsOffsetWorldSpace = Vector3.new(0, height / 2 + 1, 0)
	end

	adorn()
	render()
	gui.Parent = player:WaitForChild("PlayerGui"):FindFirstChild("MemeBillboards") or player.PlayerGui

	local connections = {
		model.AttributeChanged:Connect(render),
		model.ChildAdded:Connect(function(child)
			if child:IsA("BasePart") then
				adorn()
			end
		end),
	}
	return function()
		for _, connection in connections do
			connection:Disconnect()
		end
		gui:Destroy()
	end
end

-- Помощники для других модулей эффектов (FxExtra): те же детали, вспышки и конфетти
Effects.Piece = piece
Effects.Confetti = confetti
Effects.Flash = flash
Effects.FloatText = floatText
Effects.FxParent = fxParent

function Effects.Start()
	Remotes:WaitForChild("Knockback").OnClientEvent:Connect(onKnockback)
	Remotes:WaitForChild("Fx").OnClientEvent:Connect(onFx)
	startNightTint()
	Util.watchTagged("Monster", trackMonster)
end

return Effects
