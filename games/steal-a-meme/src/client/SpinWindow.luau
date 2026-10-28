-- Колесо удачи: сегменты из Config.Spin.Segments по кругу, указатель сверху.
-- «Крутить» -> Remotes.Spin() -> (ok, key, segmentIndex): награду выбирает сервер, клиент только
-- докручивает колесо до выпавшего сегмента (~3.5 с). Награда приходит Popup "Spin" — Popups
-- показывает её после анимации (Rewards.SpinHoldUntil). Атрибуты игрока: Spins, FreeSpinReady.
-- Шансы сегментов показаны в окне: вращения продаются за Robux (правила Roblox о случайных наградах).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Locale = require(Shared:WaitForChild("Locale"))
local Rewards = require(script.Parent:WaitForChild("Rewards"))
local UiKit = require(script.Parent:WaitForChild("UiKit"))
local Util = require(script.Parent:WaitForChild("Util"))

local COLORS = UiKit.Colors
local create = UiKit.create
local player = Players.LocalPlayer

local SEGMENTS = Config.Spin.Segments
local SPIN_TIME = 3.5
local TURNS = 5 -- полных оборотов до остановки
local WHEEL_BG = Color3.fromRGB(32, 30, 52)

local SpinWindow = {}

-- Сколько вращений доступно сейчас (бесплатное + купленные)
function SpinWindow.Available(): number
	return Util.num(player, "Spins") + (if Util.bool(player, "FreeSpinReady") then 1 else 0)
end

SpinWindow.Attributes = { "Spins", "FreeSpinReady" }

local function totalWeight(): number
	local total = 0
	for _, segment in SEGMENTS do
		total += segment.Weight
	end
	return math.max(total, 0.0001)
end

-- Колесо: круг, разделители и подписи сегментов. Всё внутри wheel, который вращается целиком.
local function buildWheel(holder: Frame): Frame
	local wheel = create("Frame", {
		Name = "Wheel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.94, 0.94),
		BackgroundColor3 = WHEEL_BG,
		Parent = holder,
	}, {
		create("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		create("UIStroke", { Color = COLORS.Gold, Thickness = 4 }),
	})
	local step = 360 / #SEGMENTS
	for index, segment in SEGMENTS do
		-- Подпись: «контейнер на весь круг» повёрнут к центру сегмента, сама подпись — у обода.
		-- Rotation поворачивает вокруг центра объекта, поэтому контейнер размером с колесо.
		local arm = create("Frame", {
			Name = "Segment" .. index,
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Rotation = (index - 0.5) * step,
			Parent = wheel,
		})
		local icon, text, color = Rewards.describe(segment.Reward)
		-- Цветная точка у обода (цвет награды) и подпись без фона — соседние подписи не наезжают
		create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.025),
			Size = UDim2.fromScale(0.05, 0.05),
			BackgroundColor3 = color,
			Parent = arm,
		}, { create("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
		local chip = create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.085),
			Size = UDim2.fromScale(0.21, 0.28),
			BackgroundTransparency = 1,
			Parent = arm,
		})
		UiKit.text({
			Text = icon,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.fromScale(1, 0.5),
			Parent = chip,
		})
		local label = UiKit.text({
			Name = "Label",
			Text = text,
			TextScaled = true,
			TextWrapped = true,
			TextColor3 = color,
			TextStrokeTransparency = 0.2,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromScale(0.04, 0.5),
			Size = UDim2.fromScale(0.92, 0.48),
			Parent = chip,
		})
		create("UITextSizeConstraint", { MaxTextSize = 13, MinTextSize = 6, Parent = label })

		-- Разделитель на границе сегмента
		local divider = create("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Rotation = index * step,
			Parent = wheel,
		})
		create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.new(0, 2, 0.5, 0),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.6,
			BorderSizePixel = 0,
			Parent = divider,
		})
	end
	-- Ступица по центру
	create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.16, 0.16),
		BackgroundColor3 = COLORS.Gold,
		ZIndex = 2,
		Parent = wheel,
	}, { create("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
	return wheel
end

function SpinWindow.Start(ctx)
	local window, body = UiKit.window(ctx.Gui, Locale.T("SpinTitle"), Vector2.new(660, 430))
	window.Name = "SpinWindow"
	ctx.Register("Spin", window)

	-- Слева колесо (квадрат по высоте), справа кнопки и шансы
	local holder = create("Frame", {
		Size = UDim2.fromScale(0.5, 1),
		BackgroundTransparency = 1,
		Parent = body,
	}, { create("UIAspectRatioConstraint", { AspectRatio = 1 }) })
	local wheel = buildWheel(holder)
	UiKit.text({
		Text = "▼",
		TextScaled = true,
		TextColor3 = COLORS.Red,
		TextStrokeTransparency = 0,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.35),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromScale(0.14, 0.14),
		ZIndex = 5,
		Parent = holder,
	})

	local side = create("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.5, -10, 1, 0),
		BackgroundTransparency = 1,
		Parent = body,
	})
	local spinButton = UiKit.button({
		Text = "",
		TextScaled = true,
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundColor3 = COLORS.Green,
		Parent = side,
	})
	create("UITextSizeConstraint", { MaxTextSize = 22, Parent = spinButton })
	create("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = spinButton })
	UiKit.text({
		Text = Locale.T("SpinHint"),
		TextScaled = true,
		Font = Enum.Font.Gotham,
		TextColor3 = COLORS.Muted,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 56),
		Size = UDim2.new(1, 0, 0, 18),
		Parent = side,
	}, { create("UITextSizeConstraint", { MaxTextSize = 14 }) })

	-- Покупка вращений
	local buyRow = create("Frame", {
		Position = UDim2.fromOffset(0, 78),
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundTransparency = 1,
		Parent = side,
	}, {
		create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for order, key in { "Spins3", "Spins10" } do
		local product = Config.Products[key]
		local buy = UiKit.button({
			Text = "🎡 +" .. tostring(product.Spins or 0) .. " · R$ " .. product.Robux,
			TextScaled = true,
			Size = UDim2.new(0.5, -3, 1, 0),
			BackgroundColor3 = COLORS.Purple,
			LayoutOrder = order,
			Parent = buyRow,
		})
		create("UITextSizeConstraint", { MaxTextSize = 16, Parent = buy })
		create("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4), Parent = buy })
		buy.Activated:Connect(function()
			Rewards.promptProduct(key, ctx.Toast)
		end)
	end

	-- Шансы
	UiKit.text({
		Text = Locale.T("SpinOdds"),
		TextSize = 16,
		TextColor3 = COLORS.Gold,
		Position = UDim2.fromOffset(0, 124),
		Size = UDim2.new(1, 0, 0, 20),
		Parent = side,
	})
	local odds = create("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 146),
		Size = UDim2.new(1, 0, 1, -146),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = side,
	}, {
		create("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }),
		create("UIPadding", { PaddingRight = UDim.new(0, 8) }),
	})
	local oddsLabels = {}
	local total = totalWeight()
	for index, segment in SEGMENTS do
		local label = UiKit.text({
			Text = "",
			RichText = true,
			TextScaled = true,
			Font = Enum.Font.Gotham,
			Size = UDim2.new(1, 0, 0, 18),
			LayoutOrder = index,
			Parent = odds,
		}, { create("UITextSizeConstraint", { MaxTextSize = 14 }) })
		oddsLabels[index] = { Label = label, Percent = segment.Weight / total * 100 }
	end

	local function renderOdds()
		for index, segment in SEGMENTS do
			local entry = oddsLabels[index]
			local icon, text, color = Rewards.describe(segment.Reward)
			local percent = entry.Percent
			local percentText = if percent >= 1 then string.format("%.0f%%", percent) else string.format("%.1f%%", percent)
			entry.Label.Text = icon .. ' <font color="#' .. color:ToHex() .. '">' .. text .. "</font> — " .. percentText
		end
	end

	local spinning = false
	local function renderButton()
		if spinning then
			spinButton.Text = Locale.T("SpinSpinning")
			spinButton.BackgroundColor3 = COLORS.PanelLight
			spinButton.AutoButtonColor = false
			return
		end
		local spins = Util.num(player, "Spins")
		if Util.bool(player, "FreeSpinReady") then
			spinButton.Text = Locale.T("SpinFree")
		elseif spins > 0 then
			spinButton.Text = Locale.T("SpinLeft", { Count = spins })
		else
			spinButton.Text = Locale.T("SpinNone")
		end
		local can = SpinWindow.Available() > 0
		spinButton.BackgroundColor3 = if can then COLORS.Green else COLORS.Panel
		spinButton.AutoButtonColor = can
	end

	-- Докрутить колесо так, чтобы сегмент index оказался под указателем сверху
	local function spinTo(index: number)
		local step = 360 / #SEGMENTS
		local center = (index - 0.5) * step
		local jitter = (math.random() - 0.5) * step * 0.6
		local current = wheel.Rotation % 360
		wheel.Rotation = current
		local base = current + 360 * TURNS
		local desired = (-center + jitter) % 360
		local target = base + (desired - base) % 360
		local tween = TweenService:Create(wheel, TweenInfo.new(SPIN_TIME, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
			Rotation = target,
		})
		tween:Play()
		tween.Completed:Wait()
	end

	spinButton.Activated:Connect(function()
		if spinning or SpinWindow.Available() <= 0 then
			return
		end
		spinning = true
		renderButton()
		-- Пока ждём ответа и крутим, всплывашку с наградой придерживаем
		Rewards.SpinHoldUntil = os.clock() + 15
		local success, key, segmentIndex = Rewards.invoke("Spin")
		if success and type(segmentIndex) == "number" and SEGMENTS[segmentIndex] then
			Rewards.SpinHoldUntil = os.clock() + SPIN_TIME + 0.3
			spinTo(segmentIndex)
		else
			Rewards.SpinHoldUntil = 0
			if not success and type(key) == "string" then
				ctx.Toast(Locale.T(key), "error")
			end
		end
		Rewards.SpinHoldUntil = 0
		spinning = false
		renderButton()
	end)

	for _, name in SpinWindow.Attributes do
		player:GetAttributeChangedSignal(name):Connect(renderButton)
	end
	-- Подписи «~$X» зависят от дохода — обновляем при открытии окна
	window:GetPropertyChangedSignal("Visible"):Connect(function()
		if window.Visible then
			renderOdds()
			for index, segment in SEGMENTS do
				local label = wheel:FindFirstChild("Segment" .. index, true)
				local text = label and label:FindFirstChild("Label", true)
				if text and text:IsA("TextLabel") then
					text.Text = select(2, Rewards.describe(segment.Reward))
				end
			end
		end
	end)
	renderOdds()
	renderButton()
end

return SpinWindow
