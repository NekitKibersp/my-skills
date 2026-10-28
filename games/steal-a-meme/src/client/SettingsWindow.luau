-- Окно настроек ⚙️ (открывается из меню «☰»): звук, слабая графика, скрытие табличек чужих мемов,
-- размер интерфейса. Значения — модуль Settings (атрибут SettingsJson + Remotes.SetSetting),
-- применяются сразу. Здесь же — локальная «слабая графика»: выключаем частицы/огонь/дым в мире и
-- пост-эффекты освещения только у себя (сервер ничего не меняет); вспышки и конфетти Effects
-- урезает сам, дальность табличек — MemeBillboards.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Locale = require(Shared:WaitForChild("Locale"))
local Settings = require(script.Parent:WaitForChild("Settings"))
local UiKit = require(script.Parent:WaitForChild("UiKit"))

local COLORS = UiKit.Colors
local create = UiKit.create

local SCALE_STEP = 0.1
-- Пост-эффекты, которые выключаем (ColorCorrection не трогаем — им красится Ночь Смайлика)
local POST_EFFECTS = { "BloomEffect", "SunRaysEffect", "DepthOfFieldEffect" }
local EMITTERS = { "ParticleEmitter", "Fire", "Smoke", "Sparkles", "Trail" }

local SettingsWindow = {}

-- ===== Слабая графика =====
local disabled: { [Instance]: boolean } = {} -- что выключили мы (чтобы вернуть именно это)
local savedShadows: boolean? = nil
local descendantConnection: RBXScriptConnection? = nil

local function isEmitter(inst: Instance): boolean
	for _, className in EMITTERS do
		if inst:IsA(className) then
			return true
		end
	end
	return false
end

local function isPostEffect(inst: Instance): boolean
	for _, className in POST_EFFECTS do
		if inst:IsA(className) then
			return true
		end
	end
	return false
end

local function switchOff(inst: Instance)
	if disabled[inst] then
		return
	end
	local target: any = inst
	local ok, enabled = pcall(function()
		return target.Enabled
	end)
	if ok and enabled == true then
		disabled[inst] = true
		target.Enabled = false
	end
end

local function applyLowGraphics(low: boolean)
	if low then
		for _, inst in workspace:GetDescendants() do
			if isEmitter(inst) then
				switchOff(inst)
			end
		end
		for _, inst in Lighting:GetChildren() do
			if isPostEffect(inst) then
				switchOff(inst)
			end
		end
		if savedShadows == nil then
			savedShadows = Lighting.GlobalShadows
		end
		Lighting.GlobalShadows = false
		if not descendantConnection then
			descendantConnection = workspace.DescendantAdded:Connect(function(inst)
				if isEmitter(inst) then
					-- Свойства копии могут прийти чуть позже самого объекта
					task.defer(switchOff, inst)
				end
			end)
		end
	else
		if descendantConnection then
			descendantConnection:Disconnect()
			descendantConnection = nil
		end
		for inst in disabled do
			if inst.Parent then
				local target: any = inst
				pcall(function()
					target.Enabled = true
				end)
			end
		end
		table.clear(disabled)
		if savedShadows ~= nil then
			Lighting.GlobalShadows = savedShadows
			savedShadows = nil
		end
	end
end

-- ===== Окно =====
local function card(parent: Instance, order: number, title: string, hint: string?): Frame
	local frame = create("Frame", {
		Size = UDim2.new(1, 0, 0, if hint then 62 else 50),
		BackgroundColor3 = COLORS.PanelLight,
		LayoutOrder = order,
		Parent = parent,
	}, { UiKit.corner(10), UiKit.padding(8) })
	UiKit.text({
		Text = title,
		TextScaled = true,
		Size = UDim2.new(1, -130, 0, 24),
		Parent = frame,
	}, { create("UITextSizeConstraint", { MaxTextSize = 18, MinTextSize = 10 }) })
	if hint then
		UiKit.text({
			Text = hint,
			TextScaled = true,
			TextWrapped = true,
			Font = Enum.Font.Gotham,
			TextColor3 = COLORS.Muted,
			Position = UDim2.fromOffset(0, 26),
			Size = UDim2.new(1, -130, 0, 20),
			Parent = frame,
		}, { create("UITextSizeConstraint", { MaxTextSize = 13, MinTextSize = 8 }) })
	end
	return frame
end

local function toggle(parent: Instance, order: number, key: string, title: string, hint: string?)
	local frame = card(parent, order, title, hint)
	local button = UiKit.button({
		TextScaled = true,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(110, 36),
		Parent = frame,
	})
	create("UITextSizeConstraint", { MaxTextSize = 18, Parent = button })
	local function render()
		local on = Settings.Get(key) == true
		button.Text = Locale.T(if on then "SetOn" else "SetOff")
		button.BackgroundColor3 = if on then COLORS.Green else COLORS.Panel
	end
	button.Activated:Connect(function()
		Settings.Set(key, not (Settings.Get(key) == true))
	end)
	Settings.Changed:Connect(function(changedKey)
		if changedKey == key then
			render()
		end
	end)
	render()
end

local function scaleRow(parent: Instance, order: number)
	local frame = card(parent, order, "")
	local title = frame:FindFirstChildWhichIsA("TextLabel") :: TextLabel
	local function stepButton(text: string, x: number): TextButton
		local button = UiKit.button({
			Text = text,
			TextSize = 22,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, x, 0.5, 0),
			Size = UDim2.fromOffset(52, 36),
			BackgroundColor3 = COLORS.Purple,
			Parent = frame,
		})
		return button
	end
	local minus = stepButton("−", -58)
	local plus = stepButton("+", 0)
	local function current(): number
		local value = Settings.Get("UiScale")
		return if type(value) == "number" then value else 1
	end
	local function render()
		local value = current()
		title.Text = Locale.T("SetUiScale", { Percent = math.floor(value * 100 + 0.5) })
		minus.AutoButtonColor = value > Settings.ScaleMin + 0.001
		plus.AutoButtonColor = value < Settings.ScaleMax - 0.001
		minus.BackgroundColor3 = if minus.AutoButtonColor then COLORS.Purple else COLORS.Panel
		plus.BackgroundColor3 = if plus.AutoButtonColor then COLORS.Purple else COLORS.Panel
	end
	minus.Activated:Connect(function()
		Settings.Set("UiScale", math.max(Settings.ScaleMin, current() - SCALE_STEP))
	end)
	plus.Activated:Connect(function()
		Settings.Set("UiScale", math.min(Settings.ScaleMax, current() + SCALE_STEP))
	end)
	Settings.Changed:Connect(function(key)
		if key == "UiScale" then
			render()
		end
	end)
	render()
end

function SettingsWindow.Start(ctx)
	local window, body = UiKit.window(ctx.Gui, Locale.T("SettingsTitle"), Vector2.new(440, 360))
	window.Name = "SettingsWindow"
	ctx.Register("Settings", window)

	local list = create("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = body,
	}, {
		create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		create("UIPadding", { PaddingRight = UDim.new(0, 8) }),
	})

	toggle(list, 1, "Sound", Locale.T("SetSound"))
	toggle(list, 2, "LowGraphics", Locale.T("SetLowGraphics"), Locale.T("SetLowGraphicsHint"))
	toggle(list, 3, "HideBillboards", Locale.T("SetHideBillboards"), Locale.T("SetHideBillboardsHint"))
	scaleRow(list, 4)

	Settings.Changed:Connect(function(key, value)
		if key == "LowGraphics" then
			applyLowGraphics(value == true)
		end
	end)
	if Settings.Get("LowGraphics") == true then
		applyLowGraphics(true)
	end
end

return SettingsWindow
