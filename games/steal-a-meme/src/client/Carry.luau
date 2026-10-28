-- Кража: пока игрок несёт мема (атрибут Carrying), показываем баннер с таймером
-- и луч от персонажа к своей базе. Плюс метка «ТВОЯ БАЗА ⬇» над своей базой в начале игры.
-- Всё создаётся локально и видно только этому игроку.
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

local INTRO_SECONDS = 90 -- сколько показывать метку над своей базой после входа
local BEAM_COLOR = Color3.fromRGB(80, 255, 140)
-- База многоэтажная: метка над верхним этажом (Config.Plot.Floors[*].Height), луч — ко входу на земле (Floor)
local MARKER_HEIGHT = Config.Plot.Floors[#Config.Plot.Floors].Height + 14

local Carry = {}

function Carry.Start(ctx)
	-- Баннер по центру (ниже середины, чтобы не закрывать персонажа и уведомления)
	local bannerLabel = UiKit.text({
		Name = "CarryBanner",
		Text = "",
		TextSize = 24,
		TextColor3 = COLORS.Gold,
		TextStrokeTransparency = 0.3,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.7),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 40),
		BackgroundColor3 = COLORS.Panel,
		BackgroundTransparency = 0.15,
		Visible = false,
		Parent = ctx.Gui,
	})
	UiKit.corner(12).Parent = bannerLabel
	create("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), Parent = bannerLabel })
	local bannerStroke = create("UIStroke", {
		Color = COLORS.Green,
		Thickness = 3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = bannerLabel,
	})
	ctx.Scale(bannerLabel)

	-- Луч к базе: вложения создаём локально, сам Beam живёт в персонаже
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

	local function ensureBeam()
		local _, root = Util.character()
		local plot = Util.myPlot()
		local floor = plot and plot:FindFirstChild("Floor")
		if not root or not floor or not floor:IsA("BasePart") then
			clearBeam()
			return
		end
		if beam and fromAttachment and toAttachment and fromAttachment.Parent == root and toAttachment.Parent == floor then
			return
		end
		clearBeam()
		local a0 = create("Attachment", { Name = "CarryBeamFrom", Parent = root })
		local a1 = create("Attachment", {
			Name = "CarryBeamTo",
			Position = Vector3.new(0, floor.Size.Y / 2 + 3, 0),
			Parent = floor,
		})
		beam = create("Beam", {
			Name = "CarryBeam",
			Attachment0 = a0,
			Attachment1 = a1,
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
		fromAttachment, toAttachment = a0, a1
	end

	-- «ТВОЯ БАЗА ⬇» над полом своей базы
	local folder = create("Folder", { Name = "LocalMarkers", Parent = player:WaitForChild("PlayerGui") })
	local marker = create("BillboardGui", {
		Name = "YourBase",
		Size = UDim2.fromOffset(220, 56),
		StudsOffsetWorldSpace = Vector3.new(0, MARKER_HEIGHT, 0),
		AlwaysOnTop = true,
		LightInfluence = 0,
		Enabled = false,
		Parent = folder,
	})
	local markerText = UiKit.text({
		Text = Locale.T("YourBaseArrow"),
		TextScaled = true,
		TextColor3 = COLORS.Green,
		TextStrokeTransparency = 0,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		Parent = marker,
	})
	-- Мягкое покачивание метки, чтобы её было заметно
	TweenService:Create(
		markerText,
		TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Position = UDim2.fromOffset(0, 8) }
	):Play()

	local introStart: number? = nil -- отсчёт с момента, когда своя база впервые найдена

	local function render()
		local carrying = Util.str(player, "Carrying")
		local isCarrying = carrying ~= ""

		bannerLabel.Visible = isCarrying
		if isCarrying then
			local left = Util.num(player, "CarryEndsAt") - Util.now()
			bannerLabel.Text = Locale.T("BannerCarry", { Meme = carrying, Time = Util.clock(left) })
			bannerStroke.Color = if left < 10 then COLORS.Red else COLORS.Green
			ensureBeam()
		elseif beam then
			clearBeam()
		end

		local plot = Util.myPlot()
		local floor = plot and plot:FindFirstChild("Floor")
		marker.Adornee = if floor and floor:IsA("BasePart") then floor else nil
		if marker.Adornee and not introStart then
			introStart = os.clock()
		end
		local intro = introStart ~= nil and os.clock() - introStart < INTRO_SECONDS
		marker.Enabled = marker.Adornee ~= nil and (isCarrying or intro)
	end

	player.CharacterRemoving:Connect(clearBeam)
	task.spawn(function()
		while true do
			render()
			task.wait(0.2)
		end
	end)
end

return Carry
