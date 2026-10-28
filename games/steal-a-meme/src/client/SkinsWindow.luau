-- Окно скинов: две вкладки (база / тапок) из Config.Skins. Источник — атрибут игрока SkinsJson:
-- { Owned = { id… }, Base = id, Slipper = id }. Купить за монеты — Remotes.BuySkin(id)
-- (только Price > 0 без Source), надеть — Remotes.EquipSkin(id). Скины с Source = "Pass" / "Spin"
-- не продаются: их выдаёт Мем-пропуск или колесо. Цену и владение проверяет сервер.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))
local Locale = require(Shared:WaitForChild("Locale"))
local Rewards = require(script.Parent:WaitForChild("Rewards"))
local UiKit = require(script.Parent:WaitForChild("UiKit"))
local Util = require(script.Parent:WaitForChild("Util"))

local COLORS = UiKit.Colors
local create = UiKit.create
local player = Players.LocalPlayer

local CELL_HEIGHT = 150
local GAP = 8
local DEFAULT_SWATCH = Color3.fromRGB(150, 150, 160)
local TABS = { { Kind = "Base", Key = "SkinsBase" }, { Kind = "Slipper", Key = "SkinsSlipper" } }

local SkinsWindow = {}

type State = { Owned: { [string]: boolean }, Base: string, Slipper: string }

local function readState(): State
	local raw = Util.json(player, "SkinsJson")
	local state: State = { Owned = {}, Base = "BaseDefault", Slipper = "SlipperDefault" }
	if type(raw) ~= "table" then
		return state
	end
	if type(raw.Owned) == "table" then
		for _, id in raw.Owned do
			if type(id) == "string" then
				state.Owned[id] = true
			end
		end
	end
	if type(raw.Base) == "string" then
		state.Base = raw.Base
	end
	if type(raw.Slipper) == "string" then
		state.Slipper = raw.Slipper
	end
	return state
end

-- Бесплатные скины без Source (классика) есть у всех
local function owns(state: State, skin): boolean
	return state.Owned[skin.Id] == true or (skin.Price == 0 and skin.Source == nil)
end

-- Образец цвета: пол базы (обводка — стены) или цвет тапка; радужный — градиент
local function swatch(parent: Instance, skin)
	local main = skin.Floor or skin.Color or DEFAULT_SWATCH
	local frame = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(56, 56),
		BackgroundColor3 = main,
		Parent = parent,
	}, {
		UiKit.corner(if skin.Kind == "Slipper" then 28 else 10),
		create("UIStroke", { Color = skin.Wall or Color3.new(1, 1, 1), Thickness = 3 }),
	})
	if skin.Rainbow then
		frame.BackgroundColor3 = Color3.new(1, 1, 1)
		create("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 60, 60)),
				ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 40)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(60, 230, 90)),
				ColorSequenceKeypoint.new(0.75, Color3.fromRGB(60, 140, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 70, 255)),
			}),
			Rotation = 45,
			Parent = frame,
		})
	end
	return frame
end

function SkinsWindow.Start(ctx)
	local window, body = UiKit.window(ctx.Gui, Locale.T("SkinsTitle"), Vector2.new(620, 440))
	window.Name = "SkinsWindow"
	ctx.Register("Skins", window)

	local tabRow = create("Frame", {
		Size = UDim2.new(1, 0, 0, 38),
		BackgroundTransparency = 1,
		Parent = body,
	}, {
		create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	local grid = create("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 46),
		Size = UDim2.new(1, 0, 1, -46),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = body,
	}, {
		create("UIPadding", { PaddingRight = UDim.new(0, 10), PaddingBottom = UDim.new(0, 6) }),
	})
	local layout = create("UIGridLayout", {
		CellPadding = UDim2.fromOffset(GAP, GAP),
		CellSize = UDim2.fromOffset(130, CELL_HEIGHT),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})
	-- Колонки по ширине: 2 на узком телефоне, до 4 на ПК
	local function relayout()
		local width = grid.AbsoluteSize.X - 10
		if width <= 0 then
			return
		end
		local columns = math.clamp(math.floor((width + GAP) / (130 + GAP)), 2, 4)
		layout.CellSize = UDim2.fromOffset(math.floor((width - GAP * (columns - 1)) / columns), CELL_HEIGHT)
	end
	grid:GetPropertyChangedSignal("AbsoluteSize"):Connect(relayout)
	relayout()

	local busy = false
	local function call(remote: string, id: string)
		if busy then
			return
		end
		busy = true
		local success, key = Rewards.invoke(remote, id)
		busy = false
		if type(key) == "string" then
			ctx.Toast(Locale.T(key), if success then "success" else "error")
		end
	end

	-- Клетки создаются один раз; вкладка только скрывает чужой вид
	local cells = {}
	for order, skin in Config.Skins do
		local cell = create("Frame", {
			BackgroundColor3 = COLORS.PanelLight,
			LayoutOrder = order,
			Visible = false,
			Parent = grid,
		}, { UiKit.corner(10) })
		local stroke = create("UIStroke", { Color = COLORS.PanelLight, Thickness = 2, Parent = cell })
		swatch(cell, skin)
		local name = UiKit.text({
			Text = Locale.Name(skin),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.new(0, 4, 0, 70),
			Size = UDim2.new(1, -8, 0, 22),
			Parent = cell,
		}, { create("UITextSizeConstraint", { MaxTextSize = 16, MinTextSize = 9 }) })
		name.Name = "SkinName"
		local button = UiKit.button({
			Text = "",
			TextScaled = true,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -8),
			Size = UDim2.new(1, -16, 0, 40),
			Parent = cell,
		})
		create("UITextSizeConstraint", { MaxTextSize = 16, Parent = button })
		create("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4), Parent = button })
		cells[skin.Id] = { Skin = skin, Frame = cell, Stroke = stroke, Button = button }
	end

	local currentKind = "Base"
	local tabButtons = {}

	local function render()
		local state = readState()
		local coins = Util.num(player, "Coins")
		for _, c in cells do
			local skin = c.Skin
			c.Frame.Visible = skin.Kind == currentKind
			local equipped = (if skin.Kind == "Base" then state.Base else state.Slipper) == skin.Id
			local button: TextButton = c.Button
			if equipped then
				button.Text = "✅ " .. Locale.T("SkinEquipped")
				button.BackgroundColor3 = COLORS.Panel
				button.AutoButtonColor = false
				c.Stroke.Color = COLORS.Green
			elseif owns(state, skin) then
				button.Text = Locale.T("SkinEquip")
				button.BackgroundColor3 = COLORS.Purple
				button.AutoButtonColor = true
				c.Stroke.Color = COLORS.PanelLight
			elseif skin.Source then
				button.Text = if skin.Source == "Spin" then Locale.T("SkinFromSpin") else Locale.T("SkinFromPass")
				button.BackgroundColor3 = Color3.fromRGB(90, 70, 20)
				button.AutoButtonColor = skin.Source == "Pass"
				c.Stroke.Color = COLORS.Gold
			else
				button.Text = "$" .. Format.Number(skin.Price)
				button.BackgroundColor3 = if coins >= skin.Price then COLORS.Green else COLORS.Panel
				button.AutoButtonColor = true
				c.Stroke.Color = COLORS.PanelLight
			end
		end
		for kind, tab in tabButtons do
			tab.BackgroundColor3 = if kind == currentKind then COLORS.Purple else COLORS.PanelLight
		end
	end

	for order, tab in TABS do
		local button = UiKit.button({
			Text = Locale.T(tab.Key),
			TextScaled = true,
			Size = UDim2.new(0.5, -4, 1, 0),
			BackgroundColor3 = COLORS.PanelLight,
			LayoutOrder = order,
			Parent = tabRow,
		})
		create("UITextSizeConstraint", { MaxTextSize = 18, Parent = button })
		tabButtons[tab.Kind] = button
		button.Activated:Connect(function()
			currentKind = tab.Kind
			grid.CanvasPosition = Vector2.zero
			render()
		end)
	end

	for id, c in cells do
		c.Button.Activated:Connect(function()
			local state = readState()
			local skin = c.Skin
			local equipped = (if skin.Kind == "Base" then state.Base else state.Slipper) == id
			if equipped then
				return
			elseif owns(state, skin) then
				call("EquipSkin", id)
			elseif skin.Source == "Pass" then
				ctx.Open("Pass", true) -- где взять — в Мем-пропуске
			elseif not skin.Source and skin.Price > 0 then
				call("BuySkin", id)
			end
		end)
	end

	player:GetAttributeChangedSignal("SkinsJson"):Connect(render)
	player:GetAttributeChangedSignal("Coins"):Connect(function()
		if window.Visible then
			render()
		end
	end)
	window:GetPropertyChangedSignal("Visible"):Connect(render)
	render()
end

return SkinsWindow
