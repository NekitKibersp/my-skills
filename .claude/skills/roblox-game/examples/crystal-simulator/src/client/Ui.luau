-- Строит весь интерфейс кодом: панель статистики, кнопки, магазин, окно перерождения и уведомления.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Format = require(ReplicatedStorage.Shared:WaitForChild("Format"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer

local COLORS = {
	Panel = Color3.fromRGB(24, 26, 38),
	PanelLight = Color3.fromRGB(40, 43, 60),
	Text = Color3.fromRGB(245, 245, 255),
	Muted = Color3.fromRGB(160, 165, 190),
	Gold = Color3.fromRGB(255, 200, 50),
	Green = Color3.fromRGB(70, 210, 110),
	Red = Color3.fromRGB(235, 80, 80),
	Purple = Color3.fromRGB(160, 100, 255),
	Ore = Color3.fromRGB(90, 190, 255),
}

local function create(className: string, props: { [string]: any }, children: { Instance }?): any
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

local function corner(radius: number?)
	return create("UICorner", { CornerRadius = UDim.new(0, radius or 10) })
end

local function padding(px: number)
	return create("UIPadding", {
		PaddingTop = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
	})
end

local function text(props: { [string]: any }): TextLabel
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.Font = props.Font or Enum.Font.GothamBold
	props.TextColor3 = props.TextColor3 or COLORS.Text
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	return create("TextLabel", props)
end

local function button(props: { [string]: any }): TextButton
	props.Font = props.Font or Enum.Font.GothamBold
	props.TextColor3 = props.TextColor3 or COLORS.Text
	props.AutoButtonColor = true
	return create("TextButton", props, { corner(8) })
end

local Ui = {}

function Ui.Start()
	local gui = create("ScreenGui", {
		Name = "CrystalSimulatorUi",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})

	-- Уведомления сверху по центру
	local toasts = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.new(0.9, 0, 0, 200),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		create("UIListLayout", {
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	local toastCount = 0
	local function toast(message: string, kind: string?)
		toastCount += 1
		local color = if kind == "error" then COLORS.Red elseif kind == "success" then COLORS.Green else COLORS.Purple
		local label = text({
			Text = message,
			TextWrapped = true,
			TextSize = 18,
			TextXAlignment = Enum.TextXAlignment.Center,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(0, 420, 0, 0),
			BackgroundTransparency = 0.1,
			BackgroundColor3 = COLORS.Panel,
			LayoutOrder = toastCount,
			Parent = toasts,
		})
		create("UIStroke", { Color = color, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = label })
		corner(10).Parent = label
		padding(8).Parent = label
		create("UISizeConstraint", { MaxSize = Vector2.new(420, math.huge), Parent = label })

		task.delay(2.5, function()
			local fade = TweenInfo.new(0.4)
			TweenService:Create(label, fade, { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
			TweenService:Create(label.UIStroke, fade, { Transparency = 1 }):Play()
			task.wait(0.4)
			label:Destroy()
		end)
	end

	-- Панель статистики слева сверху
	local stats = create("Frame", {
		Position = UDim2.new(0, 12, 0, 12),
		Size = UDim2.new(0, 240, 0, 116),
		BackgroundColor3 = COLORS.Panel,
		BackgroundTransparency = 0.15,
		Parent = gui,
	}, {
		corner(12),
		padding(10),
		create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	local coinsLabel = text({ Size = UDim2.new(1, 0, 0, 28), TextSize = 24, TextColor3 = COLORS.Gold, LayoutOrder = 1, Parent = stats })

	local oreBar = create("Frame", {
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundColor3 = COLORS.PanelLight,
		LayoutOrder = 2,
		Parent = stats,
	}, { corner(8) })
	local oreFill = create("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = COLORS.Ore,
		Parent = oreBar,
	}, { corner(8) })
	local oreLabel = text({
		Size = UDim2.fromScale(1, 1),
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.5,
		ZIndex = 2,
		Parent = oreBar,
	})

	local rebirthLabel = text({ Size = UDim2.new(1, 0, 0, 22), TextSize = 17, TextColor3 = COLORS.Purple, LayoutOrder = 3, Parent = stats })

	-- Кнопки слева по центру
	local menu = create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.new(0, 150, 0, 110),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		create("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local shopButton = button({ Text = "🛒 Магазин", TextSize = 20, Size = UDim2.new(1, 0, 0, 48), BackgroundColor3 = COLORS.Gold, TextColor3 = COLORS.Panel, LayoutOrder = 1, Parent = menu })
	local rebirthButton = button({ Text = "♻ Перерождение", TextSize = 18, Size = UDim2.new(1, 0, 0, 48), BackgroundColor3 = COLORS.Purple, LayoutOrder = 2, Parent = menu })

	-- Общий каркас окна
	local function makeWindow(title: string): (Frame, Frame)
		local window = create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.9, 0.75),
			BackgroundColor3 = COLORS.Panel,
			Visible = false,
			Parent = gui,
		}, {
			corner(14),
			padding(14),
			create("UISizeConstraint", { MaxSize = Vector2.new(500, 430) }),
			create("UIStroke", { Color = COLORS.PanelLight, Thickness = 2 }),
		})
		text({ Text = title, TextSize = 26, Size = UDim2.new(1, -50, 0, 34), Parent = window })
		local close = button({
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

	-- Магазин
	local shopWindow, shopBody = makeWindow("🛒 Магазин")
	local currentTab = "Tool"

	local tabs = create("Frame", { Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, Parent = shopBody }, {
		create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8) }),
	})
	local toolTab = button({ Text = "⛏ Кирки", TextSize = 18, Size = UDim2.new(0.5, -4, 1, 0), Parent = tabs })
	local backpackTab = button({ Text = "🎒 Рюкзаки", TextSize = 18, Size = UDim2.new(0.5, -4, 1, 0), Parent = tabs })

	local list = create("ScrollingFrame", {
		Position = UDim2.new(0, 0, 0, 46),
		Size = UDim2.new(1, 0, 1, -46),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = shopBody,
	}, {
		create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	local function renderShop()
		for _, child in list:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end

		toolTab.BackgroundColor3 = if currentTab == "Tool" then COLORS.Gold else COLORS.PanelLight
		toolTab.TextColor3 = if currentTab == "Tool" then COLORS.Panel else COLORS.Text
		backpackTab.BackgroundColor3 = if currentTab == "Backpack" then COLORS.Gold else COLORS.PanelLight
		backpackTab.TextColor3 = if currentTab == "Backpack" then COLORS.Panel else COLORS.Text

		local catalog = if currentTab == "Tool" then Config.Tools else Config.Backpacks
		local currentTier = player:GetAttribute(currentTab .. "Tier") or 1
		local coins = player:GetAttribute("Coins") or 0

		for tier, item in catalog do
			local row = create("Frame", {
				Size = UDim2.new(1, -8, 0, 62),
				BackgroundColor3 = COLORS.PanelLight,
				LayoutOrder = tier,
				Parent = list,
			}, { corner(10), padding(8) })

			text({ Text = item.Name, TextSize = 18, Size = UDim2.new(1, -120, 0, 24), Parent = row })
			local detail = if currentTab == "Tool"
				then ("Сила %s · удар раз в %gс"):format(Format.Number(item.Power), item.Cooldown)
				else "Вместимость " .. Format.Number(item.Capacity)
			text({
				Text = detail,
				TextSize = 14,
				Font = Enum.Font.Gotham,
				TextColor3 = COLORS.Muted,
				Position = UDim2.new(0, 0, 0, 26),
				Size = UDim2.new(1, -120, 0, 20),
				Parent = row,
			})

			local action = button({
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.fromScale(1, 0.5),
				Size = UDim2.fromOffset(110, 38),
				TextSize = 16,
				Parent = row,
			})

			if tier == currentTier then
				action.Text = "✔ Надето"
				action.BackgroundColor3 = COLORS.Green
				action.AutoButtonColor = false
			elseif tier < currentTier then
				action.Text = "Куплено"
				action.BackgroundColor3 = COLORS.Panel
				action.TextColor3 = COLORS.Muted
				action.AutoButtonColor = false
			else
				local affordable = coins >= item.Price
				action.Text = "💰 " .. Format.Number(item.Price)
				action.BackgroundColor3 = if affordable then COLORS.Gold else COLORS.Panel
				action.TextColor3 = if affordable then COLORS.Panel else COLORS.Muted
				local kind = currentTab
				action.Activated:Connect(function()
					local ok, message = Remotes.Shop:InvokeServer(kind, tier)
					toast(message, if ok then "success" else "error")
				end)
			end
		end
	end

	toolTab.Activated:Connect(function()
		currentTab = "Tool"
		renderShop()
	end)
	backpackTab.Activated:Connect(function()
		currentTab = "Backpack"
		renderShop()
	end)

	-- Перерождение
	local rebirthWindow, rebirthBody = makeWindow("♻ Перерождение")
	local rebirthInfo = text({
		Size = UDim2.new(1, 0, 1, -64),
		TextSize = 18,
		Font = Enum.Font.Gotham,
		TextWrapped = true,
		RichText = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = rebirthBody,
	})
	local rebirthConfirm = button({
		Text = "Переродиться",
		TextSize = 22,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundColor3 = COLORS.Purple,
		Parent = rebirthBody,
	})

	local function renderRebirth()
		local rebirths = player:GetAttribute("Rebirths") or 0
		local cost = Config.RebirthCost(rebirths)
		local coins = player:GetAttribute("Coins") or 0
		rebirthInfo.Text = table.concat({
			("Перерождений: <b>%d</b>"):format(rebirths),
			("Множитель руды: <b>×%g → ×%g</b>"):format(Config.Multiplier(rebirths), Config.Multiplier(rebirths + 1)),
			("Цена: <b>%s</b> монет (у тебя %s)"):format(Format.Number(cost), Format.Number(coins)),
			"",
			'<font color="#A0A5BE">Сбросятся монеты, руда, кирка и рюкзак. Открытые зоны останутся.</font>',
		}, "\n")
		rebirthConfirm.BackgroundColor3 = if coins >= cost then COLORS.Purple else COLORS.PanelLight
	end

	rebirthConfirm.Activated:Connect(function()
		local ok, message = Remotes.Rebirth:InvokeServer()
		toast(message, if ok then "success" else "error")
	end)

	shopButton.Activated:Connect(function()
		rebirthWindow.Visible = false
		shopWindow.Visible = not shopWindow.Visible
		renderShop()
	end)
	rebirthButton.Activated:Connect(function()
		shopWindow.Visible = false
		rebirthWindow.Visible = not rebirthWindow.Visible
		renderRebirth()
	end)

	-- Обновление при изменении атрибутов игрока
	local function renderStats()
		local coins = player:GetAttribute("Coins") or 0
		local ore = player:GetAttribute("Ore") or 0
		local capacity = player:GetAttribute("Capacity") or 1
		local rebirths = player:GetAttribute("Rebirths") or 0

		coinsLabel.Text = "💰 " .. Format.Number(coins)
		oreLabel.Text = "💎 " .. Format.Number(ore) .. " / " .. Format.Number(capacity)
		oreFill.Size = UDim2.fromScale(math.clamp(ore / capacity, 0, 1), 1)
		oreFill.BackgroundColor3 = if ore >= capacity then COLORS.Red else COLORS.Ore
		rebirthLabel.Text = ("♻ %d   ×%g"):format(rebirths, Config.Multiplier(rebirths))

		if shopWindow.Visible then
			renderShop()
		end
		if rebirthWindow.Visible then
			renderRebirth()
		end
	end

	for _, key in { "Coins", "Ore", "Capacity", "Rebirths", "ToolTier", "BackpackTier" } do
		player:GetAttributeChangedSignal(key):Connect(renderStats)
	end
	renderStats()

	Remotes.Notify.OnClientEvent:Connect(toast)
end

return Ui
