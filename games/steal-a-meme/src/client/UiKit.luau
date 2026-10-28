-- Небольшой набор для построения UI кодом (Studio под рукой нет, поэтому весь интерфейс — в скриптах).
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local UiKit = {}

UiKit.Colors = {
	Panel = Color3.fromRGB(24, 26, 38),
	PanelLight = Color3.fromRGB(40, 43, 60),
	Text = Color3.fromRGB(245, 245, 255),
	Muted = Color3.fromRGB(160, 165, 190),
	Gold = Color3.fromRGB(255, 200, 50),
	Green = Color3.fromRGB(70, 210, 110),
	Red = Color3.fromRGB(235, 80, 80),
	Purple = Color3.fromRGB(160, 100, 255),
}
local COLORS = UiKit.Colors

-- create("Frame", { Size = ..., Parent = gui }, { UiKit.corner() })
-- Parent ставится последним, чтобы объект не реплицировался/рендерился наполовину настроенным.
function UiKit.create(className: string, props: { [string]: any }, children: { Instance }?): any
	local inst = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			(inst :: any)[key] = value
		end
	end
	for _, child in children or {} do
		child.Parent = inst
	end
	if props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end
local create = UiKit.create

function UiKit.corner(radius: number?)
	return create("UICorner", { CornerRadius = UDim.new(0, radius or 10) })
end

function UiKit.padding(px: number)
	return create("UIPadding", {
		PaddingTop = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
	})
end

-- children (необязательно) — как у create: констрейнты, обводки и т.п.
function UiKit.text(props: { [string]: any }, children: { Instance }?): TextLabel
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.Font = props.Font or Enum.Font.GothamBold
	props.TextColor3 = props.TextColor3 or COLORS.Text
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	return create("TextLabel", props, children)
end

-- Звук клика: модуль Sounds ставит сюда функцию (вызывается при нажатии любой UiKit.button)
UiKit.OnClick = nil :: (() -> ())?

-- Используйте .Activated, а не .MouseButton1Click: Activated работает и на телефоне, и на геймпаде.
function UiKit.button(props: { [string]: any }): TextButton
	props.Font = props.Font or Enum.Font.GothamBold
	props.TextColor3 = props.TextColor3 or COLORS.Text
	props.AutoButtonColor = if props.AutoButtonColor == nil then true else props.AutoButtonColor
	local button = create("TextButton", props, { UiKit.corner(8) })
	button.Activated:Connect(function()
		local onClick = UiKit.OnClick
		if onClick then
			onClick()
		end
	end)
	return button
end

function UiKit.screen(name: string): ScreenGui
	return create("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
end

-- Окно по центру с заголовком и кнопкой закрытия. Возвращает (window, body).
function UiKit.window(parent: Instance, title: string, maxSize: Vector2?): (Frame, Frame)
	local window = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.9, 0.75),
		BackgroundColor3 = COLORS.Panel,
		Visible = false,
		Parent = parent,
	}, {
		UiKit.corner(14),
		UiKit.padding(14),
		create("UISizeConstraint", { MaxSize = maxSize or Vector2.new(500, 430) }),
		create("UIStroke", { Color = COLORS.PanelLight, Thickness = 2 }),
	})
	UiKit.text({ Text = title, TextSize = 26, Size = UDim2.new(1, -50, 0, 34), Parent = window })
	local close = UiKit.button({
		Text = "✕",
		TextSize = 20,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(36, 36),
		BackgroundColor3 = COLORS.Red,
		Parent = window,
	})
	close.Activated:Connect(function()
		window.Visible = false
	end)
	local body = create("Frame", {
		Position = UDim2.new(0, 0, 0, 46),
		Size = UDim2.new(1, 0, 1, -46),
		BackgroundTransparency = 1,
		Parent = window,
	})
	return window, body
end

-- Всплывающие уведомления сверху по центру. Возвращает функцию toast(text, kind).
function UiKit.toaster(parent: Instance): (string, string?) -> ()
	local container = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.new(0.9, 0, 0, 200),
		BackgroundTransparency = 1,
		Parent = parent,
	}, {
		create("UIListLayout", {
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	local count = 0
	return function(message: string, kind: string?)
		count += 1
		local color = if kind == "error" then COLORS.Red elseif kind == "success" then COLORS.Green else COLORS.Purple
		local label = UiKit.text({
			Text = message,
			TextWrapped = true,
			TextSize = 18,
			TextXAlignment = Enum.TextXAlignment.Center,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(0, 420, 0, 0),
			BackgroundTransparency = 0.1,
			BackgroundColor3 = COLORS.Panel,
			LayoutOrder = count,
			Parent = container,
		})
		local stroke = create("UIStroke", {
			Color = color,
			Thickness = 2,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Parent = label,
		})
		UiKit.corner(10).Parent = label
		UiKit.padding(8).Parent = label
		create("UISizeConstraint", { MaxSize = Vector2.new(420, math.huge), Parent = label })

		task.delay(2.5, function()
			local fade = TweenInfo.new(0.4)
			TweenService:Create(label, fade, { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
			TweenService:Create(stroke, fade, { Transparency = 1 }):Play()
			task.wait(0.4)
			label:Destroy()
		end)
	end
end

return UiKit
