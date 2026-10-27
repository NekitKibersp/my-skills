-- HUD: деньги/доход/слоты слева сверху, таймер подарка за игру и боковые кнопки
-- (Магазин, Индекс, Перерождение, Замок базы, Страж). Всё рисуется из атрибутов игрока.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

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
	end
	for _, name in { "Income", "SlotsUsed", "MaxSlots", "Rebirths", "IndexCount" } do
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

function Hud.Start(ctx)
	local renderGift = buildStats(ctx)

	-- Вертикальные кнопки слева по центру
	local side = create("Frame", {
		Name = "SideButtons",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 8, 0.55, 0),
		Size = UDim2.fromOffset(BUTTON, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = ctx.Gui,
	}, {
		create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	ctx.Scale(side)

	local shop = sideButton(side, 1, "🛒", Locale.T("BtnShop"))
	local index = sideButton(side, 2, "📖", Locale.T("BtnIndex"))
	local rebirth, rebirthCaption = sideButton(side, 3, "♻️", Locale.T("BtnRebirth"))
	local lock, lockCaption = sideButton(side, 4, "🔒", Locale.T("BtnLock"))
	local guard, guardCaption = sideButton(side, 5, "🐱⚔️", Locale.T("BtnGuard"))
	local lockIcon = lock:FindFirstChild("Icon") :: TextLabel

	shop.BackgroundColor3 = COLORS.Green
	shop.Activated:Connect(function()
		ctx.Open("Shop")
	end)
	index.Activated:Connect(function()
		ctx.Open("Index")
	end)
	rebirth.Activated:Connect(function()
		ctx.Open("Rebirth")
	end)
	guard.Activated:Connect(function()
		ctx.Open("Guard")
	end)
	lock.Activated:Connect(function()
		-- Можно ли закрыть — решает сервер (он же пришлёт Notify с причиной)
		Remotes:WaitForChild("LockBase"):FireServer()
	end)

	-- Подпись «Перерождения» — прогресс в процентах (короткая цель всегда на экране)
	local function renderRebirth()
		local progress = Util.num(player, "Coins") / Config.RebirthCost(Util.num(player, "Rebirths"))
		rebirthCaption.Text = math.floor(math.clamp(progress, 0, 1) * 100) .. "%"
		rebirth.BackgroundColor3 = if progress >= 1 then COLORS.Purple else COLORS.Panel
	end

	-- Подпись «Стража» — цена следующего уровня
	local function renderGuard()
		local nextLevel = Config.Guard[Util.num(player, "GuardLevel") + 1]
		guardCaption.Text = if nextLevel then "$" .. Format.Number(nextLevel.Price) else Locale.T("BtnMax")
	end

	player:GetAttributeChangedSignal("Coins"):Connect(renderRebirth)
	player:GetAttributeChangedSignal("Rebirths"):Connect(renderRebirth)
	player:GetAttributeChangedSignal("GuardLevel"):Connect(renderGuard)
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

	task.spawn(function()
		while true do
			renderLock()
			renderGift()
			task.wait(0.25)
		end
	end)
end

return Hud
