-- Окно магазина: геймпассы (навсегда) и продукты за Robux (бусты, деньги).
-- Клиент только открывает окно покупки Roblox; выдачу делает сервер (ProcessReceipt / проверка пасса).
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Locale = require(Shared:WaitForChild("Locale"))
local UiKit = require(script.Parent:WaitForChild("UiKit"))
local Util = require(script.Parent:WaitForChild("Util"))

local COLORS = UiKit.Colors
local create = UiKit.create
local player = Players.LocalPlayer

local Shop = {}

-- Ключи словаря по возрастанию цены (порядок обхода словаря в Luau не гарантирован)
local function sortedKeys(items: { [string]: any }): { string }
	local keys = {}
	for key in items do
		table.insert(keys, key)
	end
	table.sort(keys, function(a, b)
		if items[a].Robux == items[b].Robux then
			return a < b
		end
		return items[a].Robux < items[b].Robux
	end)
	return keys
end

function Shop.Start(ctx)
	local window, body = UiKit.window(ctx.Gui, Locale.T("ShopTitle"), Vector2.new(560, 460))
	window.Name = "ShopWindow"
	ctx.Register("Shop", window)

	local list = create("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = body,
	}, {
		create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
		create("UIPadding", { PaddingRight = UDim.new(0, 10) }),
	})

	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	local function section(key: string)
		UiKit.text({
			Text = Locale.T(key),
			TextSize = 18,
			TextColor3 = COLORS.Gold,
			Size = UDim2.new(1, 0, 0, 28),
			LayoutOrder = nextOrder(),
			Parent = list,
		})
	end

	-- Строка товара: название слева, кнопка с ценой справа. Возвращает (кнопка, подпись-подсказка).
	local function row(item): (TextButton, TextLabel)
		local frame = create("Frame", {
			Size = UDim2.new(1, 0, 0, 56),
			BackgroundColor3 = COLORS.PanelLight,
			LayoutOrder = nextOrder(),
			Parent = list,
		}, { UiKit.corner(10) })
		local name = UiKit.text({
			Text = Locale.Name(item),
			TextScaled = true,
			Position = UDim2.fromOffset(12, 4),
			Size = UDim2.new(1, -140, 0, 28),
			Parent = frame,
		})
		create("UITextSizeConstraint", { MaxTextSize = 18, MinTextSize = 10, Parent = name })
		local hint = UiKit.text({
			Text = "",
			TextSize = 14,
			TextColor3 = COLORS.Muted,
			Position = UDim2.fromOffset(12, 32),
			Size = UDim2.new(1, -140, 0, 18),
			Parent = frame,
		})
		local buy = UiKit.button({
			Text = "R$ " .. item.Robux,
			TextSize = 18,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(116, 42),
			BackgroundColor3 = COLORS.Green,
			Parent = frame,
		})
		return buy, hint
	end

	-- Геймпассы
	section("ShopPasses")
	for _, key in sortedKeys(Config.GamePasses) do
		local item = Config.GamePasses[key]
		local buy = row(item)
		local attribute = "Pass_" .. key

		local function render()
			local owned = Util.bool(player, attribute)
			buy.Text = if owned then Locale.T("ShopOwned") else "R$ " .. item.Robux
			buy.BackgroundColor3 = if owned then COLORS.Panel else COLORS.Green
			buy.AutoButtonColor = not owned
		end
		player:GetAttributeChangedSignal(attribute):Connect(render)
		render()

		buy.Activated:Connect(function()
			if Util.bool(player, attribute) then
				return
			end
			if item.Id == 0 then
				ctx.Toast(Locale.T("NotConfigured"), "error")
				return
			end
			MarketplaceService:PromptGamePassPurchase(player, item.Id)
		end)
	end

	-- Продукты (многоразовые)
	section("ShopProducts")
	for _, key in sortedKeys(Config.Products) do
		local item = Config.Products[key]
		local buy, hint = row(item)

		-- Для пачек денег показываем примерную сумму (точную считает сервер)
		if item.IncomeSeconds then
			local function render()
				local estimate = math.max(Util.num(player, "Income") * item.IncomeSeconds, item.MinCoins or 0)
				hint.Text = Locale.T("ShopCashHint", { Coins = estimate })
			end
			player:GetAttributeChangedSignal("Income"):Connect(render)
			render()
		end

		buy.Activated:Connect(function()
			if item.Id == 0 then
				ctx.Toast(Locale.T("NotConfigured"), "error")
				return
			end
			MarketplaceService:PromptProductPurchase(player, item.Id)
		end)
	end
end

return Shop
