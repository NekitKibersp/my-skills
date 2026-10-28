-- Календарь ежедневных наград: 7 клеток из Config.DailyCalendar, забранные дни с галочкой,
-- текущий день подсвечен. Забрать — Remotes.ClaimDaily (награду выбирает и выдаёт сервер).
-- Атрибуты игрока: DailyReady (можно забрать), DailyDay (какой день выдадут; если не готово —
-- последний забранный), DailyStreak. Окно само открывается один раз за сессию, если награда
-- готова (но не во время туториала).
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
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local AUTO_OPEN_DELAY = 2.5 -- после загрузки данных, чтобы не перекрыть оффлайн-доход сразу

local DailyWindow = {}

-- Иконка, подпись и цвет награды дня
local function describe(reward): (string, string, Color3)
	if reward.Kind == "Meme" then
		local rarity = Config.GetRarity(reward.Rarity)
		return "🎲", Locale.T("DailyMeme", { Rarity = Locale.Name(rarity) }), rarity.Color
	elseif reward.Kind == "Item" then
		local item = Config.GetItem(reward.ItemId)
		-- Предмет уже куплен — сервер выдаст монеты Fallback, их и показываем
		local owned = Util.json(player, "ItemsJson")
		local hasItem = type(owned) == "table" and table.find(owned, reward.ItemId) ~= nil
		if item and not hasItem then
			return item.Face, Locale.Name(item), COLORS.Purple
		end
		local fallback = reward.Fallback or {}
		return "💰", Locale.T("DailyCoins", { Coins = Util.coinsFor(fallback.IncomeSeconds, fallback.MinCoins) }), COLORS.Gold
	end
	return "💰", Locale.T("DailyCoins", { Coins = Util.coinsFor(reward.IncomeSeconds, reward.MinCoins) }), COLORS.Gold
end

-- Сколько дней текущего круга уже забрано и какой день подсветить
local function progress(): (number, number, boolean)
	local ready = Util.bool(player, "DailyReady")
	local day = math.clamp(Util.num(player, "DailyDay"), 0, #Config.DailyCalendar)
	if ready then
		local current = math.max(day, 1)
		return current - 1, current, true
	end
	-- Уже забрано сегодня: DailyDay = последний забранный день (DailyStreak — запасной вариант)
	local claimed = if day > 0 then day else math.clamp(Util.num(player, "DailyStreak"), 0, #Config.DailyCalendar)
	local nextDay = if claimed >= #Config.DailyCalendar then 1 else claimed + 1
	return claimed, nextDay, false
end

function DailyWindow.Start(ctx)
	local window, body = UiKit.window(ctx.Gui, Locale.T("DailyTitle"), Vector2.new(640, 380))
	window.Name = "DailyWindow"
	ctx.Register("Daily", window)

	UiKit.text({
		Text = Locale.T("DailyHint"),
		TextScaled = true,
		TextWrapped = true,
		Font = Enum.Font.Gotham,
		TextColor3 = COLORS.Muted,
		Size = UDim2.new(1, 0, 0, 22),
		Parent = body,
	}, { create("UITextSizeConstraint", { MaxTextSize = 15 }) })

	local grid = create("Frame", {
		Position = UDim2.fromOffset(0, 28),
		Size = UDim2.new(1, 0, 1, -94),
		BackgroundTransparency = 1,
		Parent = body,
	}, {
		create("UIGridLayout", {
			CellSize = UDim2.new(1 / 7, -6, 1, 0),
			CellPadding = UDim2.fromOffset(6, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}),
	})

	local cells = {}
	for day, reward in Config.DailyCalendar do
		local cell = create("Frame", {
			Name = "Day" .. day,
			BackgroundColor3 = COLORS.PanelLight,
			LayoutOrder = day,
			Parent = grid,
		}, { UiKit.corner(10) })
		local stroke = create("UIStroke", { Color = COLORS.Gold, Thickness = 3, Enabled = false, Parent = cell })
		local dayLabel = UiKit.text({
			Text = Locale.T("DailyDayN", { Day = day }),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.new(0, 2, 0, 4),
			Size = UDim2.new(1, -4, 0.16, 0),
			Parent = cell,
		}, { create("UITextSizeConstraint", { MaxTextSize = 16 }) })
		local icon = UiKit.text({
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromScale(0.15, 0.2),
			Size = UDim2.fromScale(0.7, 0.4),
			Parent = cell,
		})
		create("UIAspectRatioConstraint", { AspectRatio = 1, Parent = icon })
		local caption = UiKit.text({
			TextScaled = true,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.new(0, 3, 0.62, 0),
			Size = UDim2.new(1, -6, 0.24, 0),
			Parent = cell,
		}, { create("UITextSizeConstraint", { MaxTextSize = 14, MinTextSize = 7 }) })
		local tag = UiKit.text({
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = COLORS.Gold,
			Position = UDim2.new(0, 2, 0.86, 0),
			Size = UDim2.new(1, -4, 0.12, 0),
			Parent = cell,
		}, { create("UITextSizeConstraint", { MaxTextSize = 12 }) })
		local check = UiKit.text({
			Text = "✅",
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Center,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.42),
			Size = UDim2.fromScale(0.6, 0.35),
			ZIndex = 3,
			Visible = false,
			Parent = cell,
		})
		create("UIAspectRatioConstraint", { AspectRatio = 1, Parent = check })
		cells[day] = { Reward = reward, Frame = cell, Stroke = stroke, Day = dayLabel, Icon = icon, Caption = caption, Tag = tag, Check = check }
	end

	local claim = UiKit.button({
		TextSize = 22,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.new(0.6, 0, 0, 54),
		BackgroundColor3 = COLORS.Green,
		Parent = body,
	})

	local function render()
		local claimed, highlight, ready = progress()
		for day, cell in cells do
			local icon, caption, color = describe(cell.Reward)
			local done = day <= claimed
			local current = day == highlight
			cell.Icon.Text = icon
			cell.Icon.TextTransparency = if done then 0.6 else 0
			cell.Caption.Text = caption
			cell.Caption.TextColor3 = color
			cell.Check.Visible = done
			cell.Stroke.Enabled = current
			cell.Stroke.Color = if ready then COLORS.Green else COLORS.Gold
			cell.Frame.BackgroundColor3 = if current and ready then Color3.fromRGB(40, 80, 55) else COLORS.PanelLight
			cell.Tag.Text = if current then Locale.T(if ready then "DailyToday" else "DailyNext") else ""
			cell.Tag.TextColor3 = if ready then COLORS.Green else COLORS.Gold
		end
		claim.Text = Locale.T(if ready then "DailyClaim" else "DailyTomorrow")
		claim.BackgroundColor3 = if ready then COLORS.Green else COLORS.PanelLight
		claim.TextColor3 = if ready then COLORS.Text else COLORS.Muted
		claim.AutoButtonColor = ready
	end

	for _, name in { "DailyReady", "DailyDay", "DailyStreak" } do
		player:GetAttributeChangedSignal(name):Connect(render)
	end
	player:GetAttributeChangedSignal("ItemsJson"):Connect(render)
	player:GetAttributeChangedSignal("Income"):Connect(function()
		if window.Visible then
			render()
		end
	end)
	window:GetPropertyChangedSignal("Visible"):Connect(render)
	render()

	local busy = false
	claim.Activated:Connect(function()
		if busy or not Util.bool(player, "DailyReady") then
			return
		end
		busy = true
		local ok, success, key = pcall(function()
			return Remotes:WaitForChild("ClaimDaily"):InvokeServer()
		end)
		busy = false
		if ok and type(key) == "string" then
			ctx.Toast(Locale.T(key), if success then "success" else "error")
		end
		if ok and success then
			-- Награду показывает Popup «Daily» от сервера
			window.Visible = false
		end
		render()
	end)

	-- Автооткрытие: один раз за сессию, после загрузки данных и вне туториала
	task.spawn(function()
		while not Util.bool(player, "DataLoaded") do
			player:GetAttributeChangedSignal("DataLoaded"):Wait()
		end
		task.wait(AUTO_OPEN_DELAY)
		while player:GetAttribute("TutorialDone") == 0 do
			player:GetAttributeChangedSignal("TutorialDone"):Wait()
		end
		if not Util.bool(player, "DailyReady") then
			return
		end
		-- Не перебиваем окно, которое игрок уже открыл сам
		for _, other in ctx.Windows do
			if other.Visible then
				return
			end
		end
		ctx.Open("Daily", true)
	end)
end

return DailyWindow
