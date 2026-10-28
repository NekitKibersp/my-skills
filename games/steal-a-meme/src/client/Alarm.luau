-- Тревога «крадут твоего мема»: пока атрибут игрока StolenBy ~= 0 (UserId вора, мем — StolenMeme),
-- по краям экрана пульсирует красная рамка (4 Frame с UIGradient, без картинок), сверху баннер
-- «🚨 <вор> ворует твоего <мем>! — бей тапком!», от своего персонажа к вору тянется красный луч,
-- раз в ALARM_PERIOD секунд звучит сирена (Sounds). StolenBy = 0 — всё убираем.
-- Всё локально и видно только хозяину мема.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Locale = require(Shared:WaitForChild("Locale"))
local Settings = require(script.Parent:WaitForChild("Settings"))
local Sounds = require(script.Parent:WaitForChild("Sounds"))
local UiKit = require(script.Parent:WaitForChild("UiKit"))
local Util = require(script.Parent:WaitForChild("Util"))

local create = UiKit.create
local player = Players.LocalPlayer

local ALARM_COLOR = Color3.fromRGB(255, 30, 40)
local ALARM_PERIOD = 1.2
local EDGE = 0.16 -- толщина рамки (доля экрана)
local PULSE = TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)

local Alarm = {}

-- Красная рамка: каждая сторона — Frame, прозрачность растёт от края внутрь (UIGradient)
local function buildVignette(): (ScreenGui, { Frame })
	local gui = create("ScreenGui", {
		Name = "StealAlarm",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = -1, -- под интерфейсом: кнопки не закрываются
		Enabled = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	-- { позиция, размер, поворот градиента (0 — от левого края) }
	local sides = {
		{ UDim2.fromScale(0, 0), UDim2.fromScale(1, EDGE), 90 },
		{ UDim2.fromScale(0, 1 - EDGE), UDim2.fromScale(1, EDGE), -90 },
		{ UDim2.fromScale(0, 0), UDim2.fromScale(EDGE * 0.6, 1), 0 },
		{ UDim2.fromScale(1 - EDGE * 0.6, 0), UDim2.fromScale(EDGE * 0.6, 1), 180 },
	}
	local frames = {}
	for _, side in sides do
		local frame = create("Frame", {
			Position = side[1],
			Size = side[2],
			BackgroundColor3 = ALARM_COLOR,
			BackgroundTransparency = 0.2,
			BorderSizePixel = 0,
			Active = false,
			Parent = gui,
		}, {
			create("UIGradient", {
				Rotation = side[3],
				Transparency = NumberSequence.new(0, 1),
			}),
		})
		table.insert(frames, frame)
	end
	return gui, frames
end

function Alarm.Start(ctx)
	local vignette, frames = buildVignette()
	local pulses: { Tween } = {}

	local banner = UiKit.text({
		Name = "StealAlarmBanner",
		Text = "",
		TextSize = 22,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0.3,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.26),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 42),
		BackgroundColor3 = Color3.fromRGB(120, 10, 20),
		BackgroundTransparency = 0.1,
		Visible = false,
		Parent = ctx.Gui,
	})
	UiKit.corner(12).Parent = banner
	create("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), Parent = banner })
	create("UIStroke", { Color = ALARM_COLOR, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = banner })
	ctx.Scale(banner)
	local bannerPop = create("UIScale", { Parent = banner })

	-- Луч к вору: вложения локальные, в корнях обоих персонажей
	local beam: Beam? = nil
	local fromAttachment: Attachment? = nil
	local toAttachment: Attachment? = nil

	local function clearBeam()
		if beam then
			beam:Destroy()
		end
		if fromAttachment then
			fromAttachment:Destroy()
		end
		if toAttachment then
			toAttachment:Destroy()
		end
		beam, fromAttachment, toAttachment = nil, nil, nil
	end

	local function ensureBeam(thief: Player?)
		local _, root = Util.character()
		local thiefCharacter = thief and thief.Character
		local thiefRoot = thiefCharacter and thiefCharacter:FindFirstChild("HumanoidRootPart")
		if not root or not thiefRoot or not thiefRoot:IsA("BasePart") then
			clearBeam()
			return
		end
		if beam and fromAttachment and toAttachment and fromAttachment.Parent == root and toAttachment.Parent == thiefRoot then
			return
		end
		clearBeam()
		local a0 = create("Attachment", { Name = "AlarmBeamFrom", Parent = root })
		local a1 = create("Attachment", { Name = "AlarmBeamTo", Parent = thiefRoot })
		local low = Settings.Get("LowGraphics") == true
		beam = create("Beam", {
			Name = "AlarmBeam",
			Attachment0 = a0,
			Attachment1 = a1,
			Color = ColorSequence.new(ALARM_COLOR),
			Transparency = NumberSequence.new(0.15, 0.4),
			Width0 = 0.7,
			Width1 = 1.2,
			Segments = if low then 4 else 16,
			FaceCamera = true,
			LightEmission = 1,
			Parent = root,
		})
		fromAttachment, toAttachment = a0, a1
	end

	local active = false
	local lastSiren = 0

	local function setActive(on: boolean)
		if on == active then
			return
		end
		active = on
		vignette.Enabled = on
		banner.Visible = on
		for _, tween in pulses do
			tween:Cancel()
		end
		table.clear(pulses)
		if on then
			for _, frame in frames do
				frame.BackgroundTransparency = 0.15
				local tween = TweenService:Create(frame, PULSE, { BackgroundTransparency = 0.75 })
				tween:Play()
				table.insert(pulses, tween)
			end
			bannerPop.Scale = 0.6
			TweenService:Create(bannerPop, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
			lastSiren = 0
		else
			clearBeam()
		end
	end

	local function update()
		local thiefId = Util.num(player, "StolenBy")
		setActive(thiefId ~= 0)
		if not active then
			return
		end
		local thief = Players:GetPlayerByUserId(thiefId)
		banner.Text = Locale.T("AlarmBanner", {
			Player = if thief then thief.DisplayName else Locale.T("AlarmSomeone"),
			Meme = Util.str(player, "StolenMeme"),
		})
		ensureBeam(thief)
		if os.clock() - lastSiren >= ALARM_PERIOD then
			lastSiren = os.clock()
			Sounds.Play("Alarm")
		end
	end

	player:GetAttributeChangedSignal("StolenBy"):Connect(update)
	player:GetAttributeChangedSignal("StolenMeme"):Connect(update)
	player.CharacterRemoving:Connect(clearBeam)
	task.spawn(function()
		while true do
			update()
			task.wait(0.2)
		end
	end)
end

return Alarm
