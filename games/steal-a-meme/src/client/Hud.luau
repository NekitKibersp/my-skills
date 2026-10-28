-- HUD: деньги/доход/слоты/бонус друзей слева сверху, таймер подарка за игру и боковые кнопки в две
-- колонки: главная (Магазин, Мем-пропуск, Колесо, Награды дня, Квесты, Меню — со значками) и база
-- (Замок, Домой, Перерождение, Защита). Остальные окна (Предметы, Индекс, Скины, Эмоции, Обмен, Коды,
-- Скорость, Настройки) и приглашение друзей / группа — в меню «☰»: на телефоне кнопки не закрывают экран.
-- Всё рисуется из атрибутов игрока.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))
local Locale = require(Shared:WaitForChild("Locale"))
local DefenseWindow = require(script.Parent:WaitForChild("DefenseWindow"))
local PassWindow = require(script.Parent:WaitForChild("PassWindow"))
local QuestsWindow = require(script.Parent:WaitForChild("QuestsWindow"))
local RebirthWindow = require(script.Parent:WaitForChild("RebirthWindow"))
local Social = require(script.Parent:WaitForChild("Social"))
local SpinWindow = require(script.Parent:WaitForChild("SpinWindow"))
local UiKit = require(script.Parent:WaitForChild("UiKit"))
local Util = require(script.Parent:WaitForChild("Util"))

local COLORS = UiKit.Colors
local create = UiKit.create
local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local BUTTON = 56 -- размер боковой кнопки при масштабе 1 (на телефоне UIScale ~0.6)

local Hud = {}

-- Панель статистики слева сверху
local function buildStats(ctx)
	-- ScreenGui не игнорирует GuiInset, поэтому y = 8 — это уже под кнопками Roblox (~60 px от края)
	-- root без раскладки: в нём панель и всплывающие «+$X» рядом с ней
	local root = create("Frame", {
		Name = "Stats",
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.fromOffset(240, 120),
		BackgroundTransparency = 1,
		Parent = ctx.Gui,
	})
	ctx.Scale(root)
	local panel = create("Frame", {
		Name = "Panel",
		Size = UDim2.fromOffset(240, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = COLORS.Panel,
		BackgroundTransparency = 0.2,
		Parent = root,
	}, {
		UiKit.corner(12),
		UiKit.padding(8),
		create("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	local coins = UiKit.text({
		Name = "Coins",
		TextSize = 30,
		TextColor3 = COLORS.Gold,
		TextStrokeTransparency = 0.5,
		Size = UDim2.new(1, 0, 0, 36),
		LayoutOrder = 1,
		Parent = panel,
	})
	local coinsPop = create("UIScale", { Parent = coins })
	local income = UiKit.text({ TextSize = 20, TextColor3 = COLORS.Green, Size = UDim2.new(1, 0, 0, 24), LayoutOrder = 2, Parent = panel })
	local info = UiKit.text({ TextScaled = true, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = 3, Parent = panel })
	create("UITextSizeConstraint", { MaxTextSize = 16, Parent = info })
	local gift = UiKit.text({ TextSize = 14, TextColor3 = COLORS.Muted, Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 4, Parent = panel })

	-- Плавный счётчик денег
	local shown = create("NumberValue", { Value = Util.num(player, "Coins") })
	shown.Changed:Connect(function(value)
		coins.Text = "💰 $" .. Format.Number(value)
	end)
	coins.Text = "💰 $" .. Format.Number(shown.Value)

	-- Всплывающее «+$X» справа от панели (в root, вне UIListLayout)
	local function floatGain(amount: number)
		local start = UDim2.new(1, 6, 0, 12)
		local label = UiKit.text({
			Text = "+$" .. Format.Number(amount),
			TextSize = 22,
			TextColor3 = COLORS.Green,
			TextStrokeTransparency = 0.3,
			Position = start,
			Size = UDim2.fromOffset(120, 26),
			Parent = root,
		})
		local fade = TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(label, fade, {
			Position = start - UDim2.fromOffset(0, 26),
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		}):Play()
		task.delay(0.9, label.Destroy, label)
	end

	local lastCoins = Util.num(player, "Coins")
	player:GetAttributeChangedSignal("Coins"):Connect(function()
		local value = Util.num(player, "Coins")
		local delta = value - lastCoins
		lastCoins = value
		TweenService:Create(shown, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Value = value }):Play()
		-- Первая загрузка данных — не «доход», без всплывающей цифры
		if delta > 0 and Util.bool(player, "DataLoaded") then
			coinsPop.Scale = 1.1
			TweenService:Create(coinsPop, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
			floatGain(delta)
		end
	end)

	local function renderInfo()
		income.Text = Locale.T("UiIncome", { Coins = Util.num(player, "Income") })
		local count = Util.num(player, "IndexCount")
		info.Text = Locale.T("UiSlots", { Used = Util.num(player, "SlotsUsed"), Max = Util.num(player, "MaxSlots") })
			.. "   "
			.. Locale.T("UiRebirths", { Count = Util.num(player, "Rebirths") })
			.. "   "
			.. Locale.T("UiIndexBonus", { Percent = math.floor(count * Config.IndexBonusPerEntry * 100 + 0.5) })
		-- Бонус за друзей на сервере и группу
		local social = Social.BoostPercent()
		if social > 0 then
			info.Text ..= "   " .. Locale.T("UiSocialBoost", { Percent = social })
		end
	end
	for _, name in { "Income", "SlotsUsed", "MaxSlots", "Rebirths", "IndexCount", "FriendBoost", "InGroup" } do
		player:GetAttributeChangedSignal(name):Connect(renderInfo)
	end
	renderInfo()

	-- Подарок за время в игре: выдаёт сервер, клиент только считает время до следующего
	local function renderGift()
		local claimed = Util.num(player, "GiftsClaimed")
		local nextGift = Config.PlaytimeGifts[claimed + 1]
		local start = Util.num(player, "SessionStart")
		if not nextGift then
			gift.Text = Locale.T("UiGiftsDone")
		elseif start <= 0 then
			gift.Text = ""
		else
			local left = start + nextGift.Minutes * 60 - Util.now()
			gift.Text = Locale.T("UiGiftIn", { Time = Util.clock(left) })
		end
	end
	return renderGift
end

-- Боковая кнопка: эмодзи крупно + подпись. Возвращает (кнопка, подпись).
local function sideButton(parent: Instance, order: number, icon: string, caption: string): (TextButton, TextLabel)
	local button = UiKit.button({
		Text = "",
		Size = UDim2.fromOffset(BUTTON, BUTTON),
		BackgroundColor3 = COLORS.Panel,
		BackgroundTransparency = 0.1,
		LayoutOrder = order,
		Parent = parent,
	})
	create("UIStroke", { Color = COLORS.PanelLight, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = button })
	UiKit.text({
		Name = "Icon",
		Text = icon,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(6, 3),
		Size = UDim2.new(1, -12, 0, 32),
		Parent = button,
	})
	local label = UiKit.text({
		Name = "Caption",
		Text = caption,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.5,
		Position = UDim2.new(0, 2, 1, -19),
		Size = UDim2.new(1, -4, 0, 16),
		Parent = button,
	})
	create("UITextSizeConstraint", { MaxTextSize = 14, Parent = label })
	return button, label
end

-- Красный значок в правом верхнем углу кнопки: число или просто точка (text = "")
local function badge(button: GuiObject): TextLabel
	local label = UiKit.text({
		Name = "Badge",
		Text = "",
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -4, 0, 4),
		Size = UDim2.fromOffset(20, 20),
		BackgroundTransparency = 0,
		BackgroundColor3 = COLORS.Red,
		ZIndex = 3,
		Visible = false,
		Parent = button,
	}, { UiKit.corner(10), create("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 1.5 }) })
	return label
end

local function column(parent: Instance, order: number): Frame
	return create("Frame", {
		Size = UDim2.fromOffset(BUTTON, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Parent = parent,
	}, {
		create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
end

-- Меню «☰»: второстепенные окна плиткой + друзья и группа. Регистрируется как окно,
-- поэтому закрывается, когда открывается любое другое.
local function buildMenu(ctx)
	local window, body = UiKit.window(ctx.Gui, Locale.T("MenuTitle"), Vector2.new(400, 380))
	window.Name = "MenuWindow"
	ctx.Register("Menu", window)

	local scroll = create("ScrollingFrame", {
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

	local grid = create("Frame", {
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Parent = scroll,
	}, {
		create("UIGridLayout", {
			CellSize = UDim2.new(1 / 3, -6, 0, 64),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local tiles = {
		{ Icon = "🗡️", Caption = "BtnItems", Window = "Items" },
		{ Icon = "📖", Caption = "BtnIndex", Window = "Index" },
		{ Icon = "🎨", Caption = "BtnSkins", Window = "Skins" },
		{ Icon = "😀", Caption = "BtnEmotes", Window = "Emotes" },
		{ Icon = "🤝", Caption = "BtnTrade", Window = "TradePick" },
		{ Icon = "🎟️", Caption = "BtnCodes", Window = "Codes" },
		{ Icon = "👟", Caption = "BtnSpeed", Window = "Defense", Card = "Speed" },
		{ Icon = "⚙️", Caption = "BtnSettings", Window = "Settings" },
	}
	for order, tile in tiles do
		local button = sideButton(grid, order, tile.Icon, Locale.T(tile.Caption))
		button.Activated:Connect(function()
			ctx.Open(tile.Window, true)
			if tile.Card then
				DefenseWindow.ScrollTo(tile.Card)
			end
		end)
	end

	-- Друзья: приглашение + подсказка про бонус
	local invite = UiKit.button({
		Text = Locale.T("SocialInvite"),
		TextScaled = true,
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = COLORS.Green,
		LayoutOrder = 2,
		Parent = scroll,
	})
	create("UITextSizeConstraint", { MaxTextSize = 20, Parent = invite })
	create("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = invite })
	UiKit.text({
		Text = Locale.T("SocialInviteHint", {
			Per = math.floor(Config.Social.FriendBoostPer * 100 + 0.5),
			Max = math.floor(Config.Social.FriendBoostMax * 100 + 0.5),
		}),
		TextScaled = true,
		TextWrapped = true,
		Font = Enum.Font.Gotham,
		TextColor3 = COLORS.Muted,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 30),
		LayoutOrder = 3,
		Parent = scroll,
	}, { create("UITextSizeConstraint", { MaxTextSize = 14 }) })
	invite.Activated:Connect(function()
		Social.Invite(ctx.Toast)
	end)

	-- Группа: кнопка только если GroupId задан и игрок ещё не в группе
	local group = UiKit.button({
		Text = Locale.T("SocialJoinGroup", { Percent = math.floor(Config.Social.GroupBoost * 100 + 0.5) }),
		TextScaled = true,
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = COLORS.Purple,
		LayoutOrder = 4,
		Parent = scroll,
	})
	create("UITextSizeConstraint", { MaxTextSize = 20, Parent = group })
	create("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = group })
	group.Activated:Connect(Social.JoinGroup)
	local function renderGroup()
		group.Visible = Social.CanJoinGroup()
	end
	player:GetAttributeChangedSignal("InGroup"):Connect(renderGroup)
	renderGroup()
end

function Hud.Start(ctx)
	local renderGift = buildStats(ctx)
	buildMenu(ctx)

	-- Кнопки слева по центру, две колонки: главное (с значками) и база (замок, перерождение, защита).
	-- Остальное — в меню «☰», чтобы на телефоне кнопки не закрывали экран.
	local side = create("Frame", {
		Name = "SideButtons",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 8, 0.55, 0),
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		Parent = ctx.Gui,
	}, {
		create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	ctx.Scale(side)
	local main = column(side, 1)
	local extra = column(side, 2)

	local shop = sideButton(main, 1, "🛒", Locale.T("BtnShop"))
	local pass = sideButton(main, 2, "🎫", Locale.T("BtnPass"))
	local spin = sideButton(main, 3, "🎡", Locale.T("BtnSpin"))
	local daily = sideButton(main, 4, "📅", Locale.T("BtnDaily"))
	local quests = sideButton(main, 5, "📜", Locale.T("BtnQuests"))
	local menu = sideButton(main, 6, "☰", Locale.T("BtnMenu"))

	local lock, lockCaption = sideButton(extra, 1, "🔒", Locale.T("BtnLock"))
	local home, homeCaption = sideButton(extra, 2, "🏠", Locale.T("BtnHome"))
	local rebirth, rebirthCaption = sideButton(extra, 3, "♻️", Locale.T("BtnRebirth"))
	local guard, guardCaption = sideButton(extra, 4, "🛡️", Locale.T("BtnDefense"))
	local lockIcon = lock:FindFirstChild("Icon") :: TextLabel
	local homeIcon = home:FindFirstChild("Icon") :: TextLabel

	local passBadge = badge(pass)
	local spinBadge = badge(spin)
	local dailyBadge = badge(daily)
	local questsBadge = badge(quests)

	local opens = { [shop] = "Shop", [pass] = "Pass", [spin] = "Spin", [daily] = "Daily", [quests] = "Quests", [menu] = "Menu" }
	for button, name in opens do
		button.Activated:Connect(function()
			ctx.Open(name)
		end)
	end

	local function setBadge(label: TextLabel, button: TextButton, count: number)
		label.Visible = count > 0
		label.Text = if count > 0 then tostring(count) else ""
		button.BackgroundColor3 = if count > 0 then COLORS.Purple else COLORS.Panel
	end

	local function renderBadges()
		setBadge(dailyBadge, daily, if Util.bool(player, "DailyReady") then 1 else 0)
		dailyBadge.Text = ""
		setBadge(questsBadge, quests, QuestsWindow.ClaimableCount())
		setBadge(passBadge, pass, PassWindow.ClaimableCount())
		setBadge(spinBadge, spin, SpinWindow.Available())
	end
	local badgeAttributes = { "DailyReady", "QuestsJson" }
	for _, list in { PassWindow.Attributes, SpinWindow.Attributes } do
		for _, name in list do
			table.insert(badgeAttributes, name)
		end
	end
	for _, name in badgeAttributes do
		player:GetAttributeChangedSignal(name):Connect(renderBadges)
	end
	renderBadges()

	shop.BackgroundColor3 = COLORS.Green
	rebirth.Activated:Connect(function()
		ctx.Open("Rebirth")
	end)
	guard.Activated:Connect(function()
		ctx.Open("Defense")
	end)
	lock.Activated:Connect(function()
		-- Можно ли закрыть — решает сервер (он же пришлёт Notify с причиной)
		Remotes:WaitForChild("LockBase"):FireServer()
	end)

	-- «Домой»: перезарядку и запрет с мемом проверяет сервер, кнопка только подсказывает
	home.Activated:Connect(function()
		if Util.str(player, "Carrying") ~= "" then
			ctx.Toast(Locale.T("HomeCarrying"), "error")
			return
		end
		if Util.num(player, "HomeReadyAt") > Util.now() then
			return
		end
		Remotes:WaitForChild("GoHome"):FireServer()
	end)
	local function renderHome()
		local carrying = Util.str(player, "Carrying") ~= ""
		local left = Util.num(player, "HomeReadyAt") - Util.now()
		if carrying then
			homeIcon.Text = "🚫"
			homeCaption.Text = Locale.T("BtnHome")
		elseif left > 0 then
			homeIcon.Text = "🏠"
			homeCaption.Text = Util.clock(left)
		else
			homeIcon.Text = "🏠"
			homeCaption.Text = Locale.T("BtnHome")
		end
		local ready = not carrying and left <= 0
		home.BackgroundColor3 = if ready then COLORS.Panel else COLORS.PanelLight
		home.AutoButtonColor = ready
		homeIcon.TextTransparency = if ready then 0 else 0.4
	end

	-- Подпись «Перерождения» — прогресс денег в процентах (короткая цель всегда на экране).
	-- Не хватает мемов для тира — «⚠️» и не больше 99%.
	local function renderRebirth()
		local status = RebirthWindow.Status()
		local percent = math.floor(math.clamp(status.Coins / status.Cost, 0, 1) * 100)
		if status.MemesOk then
			rebirthCaption.Text = percent .. "%"
		else
			rebirthCaption.Text = "⚠️" .. math.min(percent, 99) .. "%"
		end
		rebirth.BackgroundColor3 = if status.CashOk and status.MemesOk then COLORS.Purple else COLORS.Panel
	end

	-- Подпись «Защиты» — цена самой дешёвой следующей прокачки (страж, турель, лазер)
	local function renderGuard()
		local price = DefenseWindow.CheapestPrice()
		guardCaption.Text = if price then "$" .. Format.Number(price) else Locale.T("BtnMax")
	end

	player:GetAttributeChangedSignal("Coins"):Connect(renderRebirth)
	player:GetAttributeChangedSignal("Rebirths"):Connect(renderRebirth)
	for _, name in DefenseWindow.Attributes do
		player:GetAttributeChangedSignal(name):Connect(renderGuard)
	end
	renderRebirth()
	renderGuard()

	-- Замок базы: таймер из атрибутов своей базы
	local function renderLock()
		local plot = Util.myPlot()
		local now = Util.now()
		local lockedLeft = Util.num(plot, "LockedUntil") - now
		local cooldownLeft = Util.num(plot, "LockCooldownUntil") - now
		if lockedLeft > 0 then
			lockIcon.Text = "🔒"
			lockCaption.Text = Util.clock(lockedLeft)
			lock.BackgroundColor3 = COLORS.Green
		elseif cooldownLeft > 0 then
			lockIcon.Text = "⏳"
			lockCaption.Text = Util.clock(cooldownLeft)
			lock.BackgroundColor3 = COLORS.PanelLight
		else
			lockIcon.Text = "🔓"
			lockCaption.Text = Locale.T("BtnLock")
			lock.BackgroundColor3 = COLORS.Panel
		end
	end

	-- Мемы на базе меняются без атрибутов игрока — прогресс перерождения перепроверяем раз в секунду
	task.spawn(function()
		local ticks = 0
		while true do
			renderLock()
			renderHome()
			renderGift()
			ticks += 1
			if ticks % 4 == 0 then
				renderRebirth()
			end
			task.wait(0.25)
		end
	end)
end

return Hud
