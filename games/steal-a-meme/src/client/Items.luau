-- Окно предметов: оружие и гаджеты из Config.Items, покупка за монеты навсегда.
-- Купленные — атрибут игрока ItemsJson (JSON-массив Id). Покупку проверяет и выдаёт сервер
-- (Remotes.BuyItem), клиент только просит и показывает ответ.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))
local Locale = require(Shared:WaitForChild("Locale"))
local UiKit = require(script.Parent:WaitForChild("UiKit"))
local Util = require(script.Parent:WaitForChild("Util"))

local COLORS = UiKit.Colors
local create = UiKit.create
local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local ROW_HEIGHT = 86

local Items = {}

-- Множество купленных Id; нет атрибута или битый JSON -> только Тапок (он есть всегда)
local function ownedSet(): { [string]: boolean }
	local set = { Slipper = true }
	local raw = Util.str(player, "ItemsJson")
	if raw == "" then
		return set
	end
	local ok, list = pcall(HttpService.JSONDecode, HttpService, raw)
	if ok and type(list) == "table" then
		for _, id in list do
			if type(id) == "string" then
				set[id] = true
			end
		end
	end
	return set
end

local function statsText(item): string
	if item.Kind == "Weapon" then
		local text = Locale.T("ItemStatsWeapon", { Range = item.Range, Cooldown = item.Cooldown, Stun = item.Stun or 0 })
		if item.Area then
			text ..= " · " .. Locale.T("ItemArea")
		end
		return text
	end
	return Locale.T("ItemStatsGadget", { Duration = item.Duration or 0, Cooldown = item.Cooldown or 0 })
end

function Items.Start(ctx)
	local window, body = UiKit.window(ctx.Gui, Locale.T("ItemsTitle"), Vector2.new(580, 480))
	window.Name = "ItemsWindow"
	ctx.Register("Items", window)

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

	-- Строки создаются один раз, render() только перекрашивает кнопки
	local rows = {}
	local busy = false

	local function row(item)
		local frame = create("Frame", {
			Name = item.Id,
			Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
			BackgroundColor3 = COLORS.PanelLight,
			LayoutOrder = nextOrder(),
			Parent = list,
		}, { UiKit.corner(10) })
		UiKit.text({
			Text = item.Face,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(6, 13),
			Size = UDim2.fromOffset(60, 60),
			Parent = frame,
		})
		local name = UiKit.text({
			Text = Locale.Name(item),
			TextScaled = true,
			Position = UDim2.fromOffset(72, 4),
			Size = UDim2.new(1, -200, 0, 26),
			Parent = frame,
		})
		create("UITextSizeConstraint", { MaxTextSize = 18, MinTextSize = 10, Parent = name })
		local desc = UiKit.text({
			Text = if Locale.IsRussian and item.DescRu then item.DescRu else item.Desc or "",
			TextScaled = true,
			TextWrapped = true,
			Font = Enum.Font.Gotham,
			TextColor3 = COLORS.Text,
			Position = UDim2.fromOffset(72, 30),
			Size = UDim2.new(1, -200, 0, 32),
			Parent = frame,
		})
		create("UITextSizeConstraint", { MaxTextSize = 14, MinTextSize = 9, Parent = desc })
		local stats = UiKit.text({
			Text = statsText(item),
			TextScaled = true,
			TextColor3 = COLORS.Muted,
			Position = UDim2.fromOffset(72, 62),
			Size = UDim2.new(1, -200, 0, 18),
			Parent = frame,
		})
		create("UITextSizeConstraint", { MaxTextSize = 13, MinTextSize = 8, Parent = stats })
		local buy = UiKit.button({
			Text = "",
			TextSize = 18,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(116, 46),
			BackgroundColor3 = COLORS.Green,
			Parent = frame,
		})

		buy.Activated:Connect(function()
			if busy or ownedSet()[item.Id] then
				return
			end
			busy = true
			local ok, success, key = pcall(function()
				return Remotes:WaitForChild("BuyItem"):InvokeServer(item.Id)
			end)
			busy = false
			if ok and type(key) == "string" then
				ctx.Toast(Locale.T(key, { Price = item.Price }), if success then "success" else "error")
			end
		end)

		rows[item.Id] = { Item = item, Button = buy }
	end

	local function render()
		local owned = ownedSet()
		local coins = Util.num(player, "Coins")
		for _, entry in rows do
			local item, buy = entry.Item, entry.Button
			if owned[item.Id] then
				buy.Text = Locale.T("ShopOwned")
				buy.TextColor3 = COLORS.Muted
				buy.BackgroundColor3 = COLORS.Panel
				buy.AutoButtonColor = false
			else
				local affordable = coins >= item.Price
				buy.Text = if item.Price > 0 then "$" .. Format.Number(item.Price) else Locale.T("ItemFree")
				-- Не хватает денег — цена красным, кнопка тусклая (решает всё равно сервер)
				buy.TextColor3 = if affordable then COLORS.Text else COLORS.Red
				buy.BackgroundColor3 = if affordable then COLORS.Green else COLORS.Panel
				buy.AutoButtonColor = true
			end
		end
	end

	local groups = {
		{ Kind = "Weapon", Title = "ItemsWeapons" },
		{ Kind = "Gadget", Title = "ItemsGadgets" },
	}
	for _, group in groups do
		section(group.Title)
		for _, item in Config.Items do
			if item.Kind == group.Kind then
				row(item)
			end
		end
	end

	player:GetAttributeChangedSignal("ItemsJson"):Connect(render)
	player:GetAttributeChangedSignal("Coins"):Connect(function()
		if window.Visible then
			render()
		end
	end)
	window:GetPropertyChangedSignal("Visible"):Connect(render)
	render()
end

return Items
