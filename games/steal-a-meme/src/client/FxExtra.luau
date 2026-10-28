-- Эффекты v3 по Remotes.Fx: выстрел турели ("Turret" {From, To}), вспышка лазерных ворот ("Laser"
-- {Position}), ледяная бомба ("Freeze" {Position, Radius}), ракетные ботинки ("Rocket" {Position}),
-- дальнее оружие ("Shot" {From, To, Item?}), старт админ-ивента ("AdminEvent" {Id} — большая заставка
-- по центру на 3 с), мистери-бокс ("MysteryBox" {UserId, Meme}: себе — анимация открытия, другим — тост)
-- и открытие Lucky Block ("LuckyOpen" {Position, Meme, UserId}: вспышка + «<Face> <Name>!» цветом редкости,
-- хозяину — тост).
-- Всё локально, без звуков и текстур по ID; детали/конфетти — помощники из Effects.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Locale = require(Shared:WaitForChild("Locale"))
local Effects = require(script.Parent:WaitForChild("Effects"))
local UiKit = require(script.Parent:WaitForChild("UiKit"))

local COLORS = UiKit.Colors
local create = UiKit.create
local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local MAX_DISTANCE = 250
local MAX_TRACER = 120 -- длиннее не рисуем (защита от странных координат)
local TURRET_COLOR = Color3.fromRGB(255, 170, 40)
local LASER_COLOR = Color3.fromRGB(255, 40, 40)
local ICE_COLOR = Color3.fromRGB(150, 225, 255)
local FLAME_COLORS = { Color3.fromRGB(255, 200, 40), Color3.fromRGB(255, 120, 20), Color3.fromRGB(255, 60, 30) }
local CONFETTI_COLORS = {
	Color3.fromRGB(255, 80, 120),
	Color3.fromRGB(255, 210, 60),
	Color3.fromRGB(80, 200, 255),
	Color3.fromRGB(120, 255, 120),
	Color3.fromRGB(190, 110, 255),
}
-- Цвет трассера дальнего оружия по Id предмета (нет / неизвестно — белый)
local SHOT_COLORS: { [string]: { Color3 } } = {
	Snowball = { Color3.new(1, 1, 1), ICE_COLOR },
	ConfettiCannon = CONFETTI_COLORS,
}

local FxExtra = {}

local function near(position: Vector3): boolean
	local camera = workspace.CurrentCamera
	return camera == nil or (camera.CFrame.Position - position).Magnitude <= MAX_DISTANCE
end

local function isVector(value: any): boolean
	return typeof(value) == "Vector3" and value == value
end

-- Светящийся луч from -> to, который быстро тает
local function tracer(from: Vector3, to: Vector3, color: Color3, width: number, duration: number)
	local distance = (to - from).Magnitude
	if distance < 0.1 or distance > MAX_TRACER then
		return
	end
	local beam = Effects.Piece(from, Vector3.new(width, width, distance), color)
	beam.CFrame = CFrame.lookAt((from + to) / 2, to)
	beam.Transparency = 0.1
	TweenService:Create(beam, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Transparency = 1,
		Size = Vector3.new(width * 0.2, width * 0.2, distance),
	}):Play()
	Debris:AddItem(beam, duration + 0.1)
end

-- Снаряд-шарик летит from -> to и по прилёту вызывает onHit
local function projectile(from: Vector3, to: Vector3, color: Color3, size: number, speed: number, onHit: (() -> ())?)
	local distance = (to - from).Magnitude
	if distance > MAX_TRACER then
		return
	end
	local time = math.clamp(distance / speed, 0.05, 0.6)
	local ball = Effects.Piece(from, Vector3.one * size, color, Enum.PartType.Ball)
	TweenService:Create(ball, TweenInfo.new(time, Enum.EasingStyle.Linear), { CFrame = CFrame.new(to) }):Play()
	task.delay(time, function()
		ball:Destroy()
		if onHit then
			onHit()
		end
	end)
end

local function onTurret(data)
	local from, to = data.From, data.To
	if not isVector(from) or not isVector(to) or not (near(from) or near(to)) then
		return
	end
	Effects.Flash(from, TURRET_COLOR, 3, 0.15)
	tracer(from, to, TURRET_COLOR, 0.25, 0.25)
	projectile(from, to, Color3.fromRGB(255, 240, 150), 0.7, 160, function()
		Effects.Flash(to, TURRET_COLOR, 5, 0.25)
		Effects.Confetti(to, { TURRET_COLOR, Color3.new(1, 1, 1) }, 10, 4)
	end)
end

local function onLaser(data)
	local position = data.Position
	if not isVector(position) or not near(position) then
		return
	end
	Effects.Flash(position, LASER_COLOR, 8, 0.35)
	-- Вертикальная красная полоса «сработал лазер»
	local pillar = Effects.Piece(position, Vector3.new(0.4, 10, 0.4), LASER_COLOR)
	pillar.Transparency = 0.1
	TweenService:Create(pillar, TweenInfo.new(0.4), { Transparency = 1, Size = Vector3.new(2.5, 10, 2.5) }):Play()
	Debris:AddItem(pillar, 0.5)
	Effects.Confetti(position, { LASER_COLOR, Color3.fromRGB(255, 150, 150) }, 12, 5)
end

local function onFreeze(data)
	local position = data.Position
	if not isVector(position) or not near(position) then
		return
	end
	local radius = if type(data.Radius) == "number" and data.Radius == data.Radius then math.clamp(data.Radius, 2, 40) else 14
	local sphere = Effects.Piece(position, Vector3.one * 2, ICE_COLOR, Enum.PartType.Ball)
	sphere.Material = Enum.Material.Glass
	sphere.Transparency = 0.35
	TweenService:Create(sphere, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.one * radius * 2,
	}):Play()
	TweenService:Create(sphere, TweenInfo.new(0.5, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, 0.35), {
		Transparency = 1,
	}):Play()
	Debris:AddItem(sphere, 0.9)
	Effects.Flash(position, Color3.new(1, 1, 1), 6, 0.3)
	Effects.Confetti(position, { ICE_COLOR, Color3.new(1, 1, 1), Color3.fromRGB(200, 240, 255) }, 30, radius * 0.8)
end

local function onRocket(data)
	local position = data.Position
	if not isVector(position) or not near(position) then
		return
	end
	Effects.Flash(position, FLAME_COLORS[2], 6, 0.3)
	Effects.Confetti(position - Vector3.new(0, 1.5, 0), FLAME_COLORS, 22, 5)
	Effects.Confetti(position - Vector3.new(0, 2, 0), { Color3.fromRGB(90, 90, 90), Color3.fromRGB(150, 150, 150) }, 8, 3)
end

local function onShot(data)
	local from, to = data.From, data.To
	if not isVector(from) or not isVector(to) or not (near(from) or near(to)) then
		return
	end
	local colors = SHOT_COLORS[if type(data.Item) == "string" then data.Item else ""] or { Color3.new(1, 1, 1) }
	tracer(from, to, colors[1], 0.3, 0.3)
	projectile(from, to, colors[#colors], 0.8, 140, function()
		Effects.Flash(to, colors[1], 5, 0.25)
		Effects.Confetti(to, if #colors > 1 then colors else { colors[1], Color3.fromRGB(230, 230, 230) }, 18, 6)
	end)
end

-- ===== Экранные заставки =====
local function overlay(name: string): ScreenGui
	return create("ScreenGui", {
		Name = name,
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 40,
		Parent = player:WaitForChild("PlayerGui"),
	})
end

local function bigLabel(parent: Instance, text: string, color: Color3, y: number, height: number): TextLabel
	return UiKit.text({
		Text = text,
		TextScaled = true,
		TextColor3 = color,
		TextStrokeTransparency = 0,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, y),
		Size = UDim2.fromScale(0.85, height),
		Parent = parent,
	})
end

local function fadeOut(labels: { TextLabel }, after: number, duration: number)
	task.delay(after, function()
		for _, label in labels do
			if label.Parent then
				TweenService:Create(label, TweenInfo.new(duration), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			end
		end
	end)
end

local function popIn(label: GuiObject, delay: number)
	local scale = create("UIScale", { Scale = 0, Parent = label })
	TweenService:Create(scale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, delay), { Scale = 1 }):Play()
end

-- Старт админ-ивента: эмодзи, «АДМИН-ИВЕНТ!», название и описание на 3 секунды
local function adminSplash(id: string)
	local event = Config.GetAdminEvent(id)
	if not event then
		return
	end
	local gui = overlay("AdminEventSplash")
	local band = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromScale(1, 0.46),
		BackgroundColor3 = Color3.fromRGB(30, 10, 45),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = gui,
	})
	TweenService:Create(band, TweenInfo.new(0.3), { BackgroundTransparency = 0.35 }):Play()
	local face = bigLabel(gui, event.Face, Color3.new(1, 1, 1), 0.27, 0.14)
	local header = bigLabel(gui, "⭐ " .. Locale.T("SplashAdminEvent") .. " ⭐", COLORS.Gold, 0.37, 0.06)
	local name = bigLabel(gui, Locale.Name(event), Color3.fromRGB(255, 120, 230), 0.46, 0.11)
	local desc = bigLabel(gui, if Locale.IsRussian and event.DescRu then event.DescRu else event.Desc, Color3.new(1, 1, 1), 0.57, 0.05)
	popIn(face, 0)
	popIn(header, 0.1)
	popIn(name, 0.2)
	popIn(desc, 0.35)
	local spin = TweenService:Create(face, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Rotation = 12 })
	face.Rotation = -12
	spin:Play()
	fadeOut({ face, header, name, desc }, 2.6, 0.4)
	task.delay(2.6, function()
		TweenService:Create(band, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
	end)
	Debris:AddItem(gui, 3.1)
end

-- Своё открытие мистери-бокса: коробка трясётся, вспышка, затем мем с редкостью
local function mysteryReveal(memeId: string)
	local creature = Config.GetCreature(memeId)
	if not creature then
		return
	end
	local rarity = Config.GetRarity(creature.Rarity)
	local gui = overlay("MysteryBoxReveal")
	local box = bigLabel(gui, "📦", Color3.new(1, 1, 1), 0.42, 0.22)
	popIn(box, 0)
	local shake = TweenService:Create(box, TweenInfo.new(0.07, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, true), { Rotation = 14 })
	box.Rotation = -14
	shake:Play()

	task.delay(1, function()
		shake:Cancel()
		box:Destroy()
		local flashFrame = create("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = rarity.Color,
			BackgroundTransparency = 0.2,
			BorderSizePixel = 0,
			Parent = gui,
		})
		TweenService:Create(flashFrame, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
		local you = bigLabel(gui, Locale.T("MysteryBoxYou"), Color3.new(1, 1, 1), 0.22, 0.05)
		local face = bigLabel(gui, creature.Face, Color3.new(1, 1, 1), 0.36, 0.2)
		local name = bigLabel(gui, creature.Name .. "!", COLORS.Gold, 0.52, 0.08)
		local rarityLabel = bigLabel(gui, Locale.Name(rarity), rarity.Color, 0.61, 0.06)
		rarityLabel.TextStrokeColor3 = Color3.new(1, 1, 1)
		popIn(you, 0)
		popIn(face, 0)
		popIn(name, 0.15)
		popIn(rarityLabel, 0.3)
		fadeOut({ you, face, name, rarityLabel }, 2.3, 0.5)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			Effects.Confetti(root.Position + Vector3.new(0, 3, 0), { rarity.Color, COLORS.Gold, Color3.new(1, 1, 1) }, 40, 10)
		end
	end)
	Debris:AddItem(gui, 4)
end

-- Lucky Block открылся: вспышка и конфетти цвета редкости, над ним — лицо и имя мема
local function onLuckyOpen(_ctx, data)
	local creature = if type(data.Meme) == "string" then Config.GetCreature(data.Meme) else nil
	if not creature then
		return
	end
	local rarity = Config.GetRarity(creature.Rarity)
	local color = if creature.Rarity == "Secret" then Color3.new(1, 1, 1) else rarity.Color
	local position = data.Position
	if isVector(position) and near(position) then
		Effects.Flash(position, color, 10, 0.5)
		Effects.Confetti(position, { color, COLORS.Gold, Color3.new(1, 1, 1) }, 40, 9)
		Effects.FloatText(position + Vector3.new(0, 4, 0), creature.Face .. " " .. creature.Name .. "!", color)
	end
	-- Тост хозяину шлёт сервер (Notify "LuckyOpened"), здесь только эффект
end

function FxExtra.Start(ctx)
	local handlers = {
		Turret = onTurret,
		Laser = onLaser,
		Freeze = onFreeze,
		Rocket = onRocket,
		Shot = onShot,
	}
	task.spawn(function()
		Remotes:WaitForChild("Fx").OnClientEvent:Connect(function(kind, data)
			if type(kind) ~= "string" or type(data) ~= "table" then
				return
			end
			local handler = handlers[kind]
			if handler then
				handler(data)
			elseif kind == "LuckyOpen" then
				onLuckyOpen(ctx, data)
			elseif kind == "AdminEvent" and type(data.Id) == "string" then
				adminSplash(data.Id)
			elseif kind == "MysteryBox" and type(data.Meme) == "string" and Config.GetCreature(data.Meme) then
				if data.UserId == player.UserId then
					mysteryReveal(data.Meme)
				else
					local who = if type(data.UserId) == "number" then Players:GetPlayerByUserId(data.UserId) else nil
					ctx.Toast(Locale.T("MysteryBoxOther", { Player = if who then who.DisplayName else "?", Meme = data.Meme }), "info")
				end
			end
		end)
	end)
end

return FxExtra
