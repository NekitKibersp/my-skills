-- Окно Мем-пропуска (боевой пропуск сезона). Источник — атрибут игрока BPJson:
-- { Season, Xp, Level, XpInLevel, Free = { забранные уровни }, Premium = { ... }, EndsAt }.
-- Уровни и награды — Config.BattlePass.Levels; премиум-ряд — с геймпассом BattlePass (Pass_BattlePass).
-- Забрать — Remotes.ClaimPass(level, "Free" | "Premium"); награду выдаёт сервер (Popup "Pass").
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

local BP = Config.BattlePass
local COLUMN_WIDTH = 112
local GAP = 8
local PREMIUM_COLOR = Color3.fromRGB(255, 200, 50)
local PREMIUM_BG = Color3.fromRGB(60, 48, 24)
local TRACKS = { "Free", "Premium" }

local PassWindow = {}

type Data = { Level: number, XpInLevel: number, EndsAt: number, Free: { [number]: boolean }, Premium: { [number]: boolean } }

local function levelSet(list: any): { [number]: boolean }
	local set = {}
	if type(list) == "table" then
		for _, level in list do
			if type(level) == "number" then
				set[level] = true
			end
		end
	end
	return set
end

-- Разобрать BPJson; нет данных — уровень 0
function PassWindow.Read(): Data
	local raw = Util.json(player, "BPJson")
	if type(raw) ~= "table" then
		raw = {}
	end
	return {
		Level = math.clamp(if type(raw.Level) == "number" then raw.Level else 0, 0, #BP.Levels),
		XpInLevel = if type(raw.XpInLevel) == "number" then raw.XpInLevel else 0,
		EndsAt = if type(raw.EndsAt) == "number" and raw.EndsAt > 0 then raw.EndsAt else BP.EndsAt,
		Free = levelSet(raw.Free),
		Premium = levelSet(raw.Premium),
	}
end

local function claimable(data: Data, level: number, track: string): boolean
	if level > data.Level then
		return false
	end
	if track == "Premium" then
		return Util.bool(player, "Pass_BattlePass") and not data.Premium[level]
	end
	return not data.Free[level]
end

-- Сколько наград можно забрать прямо сейчас (значок на кнопке HUD)
function PassWindow.ClaimableCount(): number
	local data = PassWindow.Read()
	local count = 0
	for level = 1, data.Level do
		for _, track in TRACKS do
			if claimable(data, level, track) then
				count += 1
			end
		end
	end
	return count
end

PassWindow.Attributes = { "BPJson", "Pass_BattlePass" }

function PassWindow.Start(ctx)
	local window, body = UiKit.window(ctx.Gui, Locale.T("PassTitle"), Vector2.new(780, 470))
	window.Name = "PassWindow"
	ctx.Register("Pass", window)

	-- Шапка: сезон и сколько осталось
	local season = UiKit.text({
		Text = Locale.Name(BP),
		TextScaled = true,
		TextColor3 = COLORS.Gold,
		Size = UDim2.new(0.6, 0, 0, 22),
		Parent = body,
	}, { create("UITextSizeConstraint", { MaxTextSize = 18 }) })
	season.Name = "Season"
	local endsIn = UiKit.text({
		TextScaled = true,
		TextColor3 = COLORS.Muted,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.4, 0, 0, 22),
		Parent = body,
	}, { create("UITextSizeConstraint", { MaxTextSize = 15 }) })

	-- Уровень и полоса XP текущего уровня
	local levelLabel = UiKit.text({
		TextScaled = true,
		Position = UDim2.fromOffset(0, 26),
		Size = UDim2.new(0, 130, 0, 22),
		Parent = body,
	}, { create("UITextSizeConstraint", { MaxTextSize = 18 }) })
	local bar = create("Frame", {
		Position = UDim2.fromOffset(136, 29),
		Size = UDim2.new(1, -136, 0, 18),
		BackgroundColor3 = COLORS.PanelLight,
		Parent = body,
	}, { UiKit.corner(8) })
	local fill = create("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = COLORS.Purple,
		Parent = bar,
	}, { UiKit.corner(8) })
	local barText = UiKit.text({
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.4,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
		Parent = bar,
	})
	UiKit.text({
		Text = Locale.T("PassXpHint"),
		TextScaled = true,
		Font = Enum.Font.Gotham,
		TextColor3 = COLORS.Muted,
		Position = UDim2.fromOffset(0, 50),
		Size = UDim2.new(1, 0, 0, 16),
		Parent = body,
	}, { create("UITextSizeConstraint", { MaxTextSize = 13 }) })

	-- Кнопки покупки снизу: премиум (геймпасс) и +5 уровней (продукт)
	local footer = create("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundTransparency = 1,
		Parent = body,
	}, {
		create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local premiumButton = UiKit.button({
		Text = Locale.T("PassUnlockPremium", { Robux = Config.GamePasses.BattlePass.Robux }),
		TextScaled = true,
		Size = UDim2.new(0.55, -4, 1, 0),
		BackgroundColor3 = Color3.fromRGB(200, 140, 20),
		LayoutOrder = 1,
		Parent = footer,
	})
	create("UITextSizeConstraint", { MaxTextSize = 18, Parent = premiumButton })
	create("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), Parent = premiumButton })
	local levelsProduct = Config.Products.PassLevels
	local levelsButton = UiKit.button({
		Text = Locale.T("PassBuyLevels", { Count = levelsProduct.Levels or 5, Robux = levelsProduct.Robux }),
		TextScaled = true,
		Size = UDim2.new(0.45, -4, 1, 0),
		BackgroundColor3 = COLORS.Purple,
		LayoutOrder = 2,
		Parent = footer,
	})
	create("UITextSizeConstraint", { MaxTextSize = 18, Parent = levelsButton })
	create("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), Parent = levelsButton })

	premiumButton.Activated:Connect(function()
		if not Util.bool(player, "Pass_BattlePass") then
			Util.promptPass("BattlePass", ctx.Toast)
		end
	end)
	levelsButton.Activated:Connect(function()
		Rewards.promptProduct("PassLevels", ctx.Toast)
	end)

	-- Лента уровней: колонка на уровень (номер, бесплатная клетка, премиум-клетка), прокрутка по X
	local strip = create("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 72),
		Size = UDim2.new(1, 0, 1, -72 - 52),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		CanvasSize = UDim2.fromScale(0, 1), -- высота холста = высота ленты, колонки тянутся по ней
		ScrollingDirection = Enum.ScrollingDirection.X,
		Parent = body,
	}, {
		create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		create("UIPadding", { PaddingBottom = UDim.new(0, 10) }),
	})

	local current: Data = PassWindow.Read()
	local busy = false
	local function claim(level: number, track: string)
		if busy then
			return
		end
		if track == "Premium" and not Util.bool(player, "Pass_BattlePass") then
			Util.promptPass("BattlePass", ctx.Toast)
			return
		end
		if not claimable(current, level, track) then
			return
		end
		busy = true
		local success, key = Rewards.invoke("ClaimPass", level, track)
		busy = false
		-- Успех показывает всплывающее окно с наградой; ошибку — тостом
		if not success and type(key) == "string" then
			ctx.Toast(Locale.T(key), "error")
		end
	end

	-- Клетка награды: иконка, подпись, кнопка состояния
	local function cell(parent: Instance, order: number, reward: any, premium: boolean)
		local frame = create("Frame", {
			Size = UDim2.new(1, 0, 0.5, -16),
			BackgroundColor3 = if premium then PREMIUM_BG else COLORS.PanelLight,
			LayoutOrder = order,
			Parent = parent,
		}, { UiKit.corner(10) })
		local stroke = create("UIStroke", {
			Color = if premium then PREMIUM_COLOR else COLORS.PanelLight,
			Thickness = 2,
			Parent = frame,
		})
		local icon, text, color = Rewards.describe(reward)
		UiKit.text({
			Text = icon,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.new(0, 6, 0, 4),
			Size = UDim2.new(1, -12, 0.38, 0),
			Parent = frame,
		})
		local label = UiKit.text({
			Text = text,
			TextScaled = true,
			TextWrapped = true,
			TextColor3 = color,
			TextStrokeTransparency = 0.5,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.new(0, 4, 0.38, 4),
			Size = UDim2.new(1, -8, 0.3, -4),
			Parent = frame,
		})
		create("UITextSizeConstraint", { MaxTextSize = 14, MinTextSize = 8, Parent = label })
		local button = UiKit.button({
			Text = "",
			TextScaled = true,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -4),
			Size = UDim2.new(1, -10, 0.3, -4),
			Parent = frame,
		})
		create("UITextSizeConstraint", { MaxTextSize = 15, Parent = button })
		return { Frame = frame, Stroke = stroke, Label = label, Button = button }
	end

	local columns = {}
	for level, entry in BP.Levels do
		local column = create("Frame", {
			Size = UDim2.new(0, COLUMN_WIDTH, 1, 0),
			BackgroundTransparency = 1,
			LayoutOrder = level,
			Parent = strip,
		}, {
			create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
		})
		local title = UiKit.text({
			Text = Locale.T("PassLv", { Level = level }),
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.new(1, 0, 0, 22),
			BackgroundTransparency = 0,
			BackgroundColor3 = COLORS.Panel,
			LayoutOrder = 0,
			Parent = column,
		}, { UiKit.corner(8) })
		local free = cell(column, 1, entry.Free, false)
		local premium = cell(column, 2, entry.Premium, true)
		free.Button.Activated:Connect(function()
			claim(level, "Free")
		end)
		premium.Button.Activated:Connect(function()
			claim(level, "Premium")
		end)
		columns[level] = { Title = title, Free = free, Premium = premium }
	end

	local function paint(c, data: Data, level: number, track: string)
		local hasPass = Util.bool(player, "Pass_BattlePass")
		local claimed = if track == "Premium" then data.Premium[level] else data.Free[level]
		local reached = level <= data.Level
		local button: TextButton = c.Button
		if claimed then
			button.Text = "✅"
			button.BackgroundColor3 = COLORS.Panel
			button.AutoButtonColor = false
			c.Frame.BackgroundTransparency = 0.4
		elseif track == "Premium" and not hasPass then
			button.Text = "🔒 " .. Locale.T("PassPremium")
			button.BackgroundColor3 = Color3.fromRGB(120, 90, 20)
			button.AutoButtonColor = true
			c.Frame.BackgroundTransparency = 0
		elseif reached then
			button.Text = Locale.T("PassClaim")
			button.BackgroundColor3 = COLORS.Green
			button.AutoButtonColor = true
			c.Frame.BackgroundTransparency = 0
		else
			button.Text = "🔒"
			button.BackgroundColor3 = COLORS.Panel
			button.AutoButtonColor = false
			c.Frame.BackgroundTransparency = 0.4
		end
		c.Stroke.Color = if not claimed and reached and (track == "Free" or hasPass)
			then COLORS.Green
			elseif track == "Premium" then PREMIUM_COLOR
			else COLORS.PanelLight
	end

	local function render()
		current = PassWindow.Read()
		local hasPass = Util.bool(player, "Pass_BattlePass")
		local max = #BP.Levels
		levelLabel.Text = Locale.T("PassLevel", { Level = current.Level, Max = max })
		if current.Level >= max then
			fill.Size = UDim2.fromScale(1, 1)
			barText.Text = Locale.T("PassMaxLevel")
		else
			local ratio = math.clamp(current.XpInLevel / math.max(BP.XpPerLevel, 1), 0, 1)
			TweenService:Create(fill, TweenInfo.new(0.25), { Size = UDim2.fromScale(ratio, 1) }):Play()
			barText.Text = Locale.T("PassXp", { Xp = math.floor(current.XpInLevel), Need = BP.XpPerLevel })
		end
		for level, c in columns do
			c.Title.TextColor3 = if level <= current.Level then COLORS.Gold else COLORS.Muted
			paint(c.Free, current, level, "Free")
			paint(c.Premium, current, level, "Premium")
		end
		premiumButton.Text = if hasPass
			then Locale.T("PassPremiumOwned")
			else Locale.T("PassUnlockPremium", { Robux = Config.GamePasses.BattlePass.Robux })
		premiumButton.AutoButtonColor = not hasPass
		premiumButton.BackgroundColor3 = if hasPass then COLORS.PanelLight else Color3.fromRGB(200, 140, 20)
		levelsButton.Visible = current.Level < max
	end

	for _, name in PassWindow.Attributes do
		player:GetAttributeChangedSignal(name):Connect(render)
	end
	player:GetAttributeChangedSignal("Income"):Connect(function()
		if window.Visible then
			-- Подписи «~$X» зависят от дохода: перерисовываем текст клеток с монетами
			for level, c in columns do
				local entry = BP.Levels[level]
				c.Free.Label.Text = select(2, Rewards.describe(entry.Free))
				c.Premium.Label.Text = select(2, Rewards.describe(entry.Premium))
			end
		end
	end)

	-- При открытии — прокрутить к первой незабранной награде (или к текущему уровню)
	window:GetPropertyChangedSignal("Visible"):Connect(function()
		if not window.Visible then
			return
		end
		render()
		local target = math.max(current.Level, 1)
		for level = 1, current.Level do
			if claimable(current, level, "Free") or claimable(current, level, "Premium") then
				target = level
				break
			end
		end
		task.defer(function()
			strip.CanvasPosition = Vector2.new(math.max(0, (target - 1) * (COLUMN_WIDTH + GAP) - COLUMN_WIDTH), 0)
		end)
	end)
	render()

	task.spawn(function()
		while true do
			if window.Visible then
				local left = current.EndsAt - Util.now()
				endsIn.Text = if left > 0 then Locale.T("PassEndsIn", { Time = Rewards.timeLeft(left) }) else Locale.T("PassEnded")
			end
			task.wait(1)
		end
	end)
end

return PassWindow
