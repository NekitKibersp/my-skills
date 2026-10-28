-- Окно защиты базы: три карточки — страж (Kitten with a Sword), турель и лазерные ворота.
-- Уровни — атрибуты игрока GuardLevel / TurretLevel / LaserLevel, цены и параметры — Config.Guard и
-- Config.Defense. Покупку проверяет сервер: Remotes.UpgradeGuard() и Remotes.UpgradeDefense(kind).
-- (Раньше страж жил в отдельном GuardWindow; теперь это одна вкладка-карточка здесь.)
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

local CARD_HEIGHT = 132

-- Карточки: атрибут уровня, таблица уровней, как просить сервер и как описать следующий уровень
local KINDS = {
	{
		Id = "Guard",
		Title = "DefenseGuardName",
		Info = "GuardInfo",
		Attribute = "GuardLevel",
		Levels = Config.Guard,
		Invoke = function()
			return Remotes:WaitForChild("UpgradeGuard"):InvokeServer()
		end,
		Next = function(level)
			return Locale.T("GuardNext", { Range = level.Range, Cooldown = level.Cooldown })
		end,
	},
	{
		Id = "Turret",
		Title = "DefenseTurretName",
		Info = "DefenseTurretInfo",
		Attribute = "TurretLevel",
		Levels = Config.Defense.Turret,
		Invoke = function()
			return Remotes:WaitForChild("UpgradeDefense"):InvokeServer("Turret")
		end,
		Next = function(level)
			return Locale.T("DefenseTurretNext", { Range = level.Range, Cooldown = level.Cooldown, Stun = level.Stun })
		end,
	},
	{
		Id = "LaserGate",
		Title = "DefenseLaserName",
		Info = "DefenseLaserInfo",
		Attribute = "LaserLevel",
		Levels = Config.Defense.LaserGate,
		Invoke = function()
			return Remotes:WaitForChild("UpgradeDefense"):InvokeServer("LaserGate")
		end,
		Next = function(level)
			return Locale.T("DefenseLaserNext", { Cooldown = level.Cooldown, Stun = level.Stun })
		end,
	},
}

local DefenseWindow = {}

-- Самая дешёвая доступная прокачка (для подписи кнопки в HUD); nil — всё на максимуме
function DefenseWindow.CheapestPrice(): number?
	local best: number? = nil
	for _, kind in KINDS do
		local nextLevel = kind.Levels[Util.num(player, kind.Attribute) + 1]
		if nextLevel and (best == nil or nextLevel.Price < best) then
			best = nextLevel.Price
		end
	end
	return best
end

DefenseWindow.Attributes = { "GuardLevel", "TurretLevel", "LaserLevel" }

function DefenseWindow.Start(ctx)
	local window, body = UiKit.window(ctx.Gui, Locale.T("DefenseTitle"), Vector2.new(560, 480))
	window.Name = "DefenseWindow"
	ctx.Register("Defense", window)

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
		create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		create("UIPadding", { PaddingRight = UDim.new(0, 10) }),
	})

	local cards = {}
	local busy = false

	for order, kind in KINDS do
		local frame = create("Frame", {
			Name = kind.Id,
			Size = UDim2.new(1, 0, 0, CARD_HEIGHT),
			BackgroundColor3 = COLORS.PanelLight,
			LayoutOrder = order,
			Parent = list,
		}, { UiKit.corner(10), UiKit.padding(10) })
		UiKit.text({
			Text = Locale.T(kind.Title),
			TextScaled = true,
			Size = UDim2.new(1, -140, 0, 26),
			Parent = frame,
		}, { create("UITextSizeConstraint", { MaxTextSize = 20, MinTextSize = 12 }) })
		local level = UiKit.text({
			TextScaled = true,
			TextColor3 = COLORS.Gold,
			TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.fromOffset(130, 26),
			Parent = frame,
		}, { create("UITextSizeConstraint", { MaxTextSize = 18 }) })
		UiKit.text({
			Text = Locale.T(kind.Info),
			TextScaled = true,
			TextWrapped = true,
			Font = Enum.Font.Gotham,
			TextColor3 = COLORS.Muted,
			Position = UDim2.fromOffset(0, 28),
			Size = UDim2.new(1, -140, 0, 34),
			Parent = frame,
		}, { create("UITextSizeConstraint", { MaxTextSize = 14, MinTextSize = 8 }) })
		local nextInfo = UiKit.text({
			TextScaled = true,
			TextWrapped = true,
			Position = UDim2.fromOffset(0, 66),
			Size = UDim2.new(1, -140, 0, 40),
			Parent = frame,
		}, { create("UITextSizeConstraint", { MaxTextSize = 15, MinTextSize = 8 }) })
		local buy = UiKit.button({
			TextScaled = true,
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.fromScale(1, 1),
			Size = UDim2.fromOffset(130, 52),
			BackgroundColor3 = COLORS.Green,
			Parent = frame,
		})
		create("UITextSizeConstraint", { MaxTextSize = 17, Parent = buy })
		create("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), Parent = buy })

		buy.Activated:Connect(function()
			local current = Util.num(player, kind.Attribute)
			local nextLevel = kind.Levels[current + 1]
			if busy or not nextLevel then
				return
			end
			busy = true
			local ok, success, key = pcall(kind.Invoke)
			busy = false
			if ok and type(key) == "string" then
				ctx.Toast(Locale.T(key, { Level = current + 1, Price = nextLevel.Price }), if success then "success" else "error")
			end
		end)

		cards[kind.Id] = { Kind = kind, Level = level, Next = nextInfo, Buy = buy }
	end

	local function render()
		local coins = Util.num(player, "Coins")
		for _, card in cards do
			local kind = card.Kind
			local current = Util.num(player, kind.Attribute)
			local nextLevel = kind.Levels[current + 1]
			card.Level.Text = Locale.T("GuardLevelNow", { Level = current, Max = #kind.Levels })
			if nextLevel then
				card.Next.Text = kind.Next(nextLevel)
				card.Buy.Text = Locale.T(if current == 0 then "GuardBuy" else "GuardUpgrade", { Price = nextLevel.Price })
				local affordable = coins >= nextLevel.Price
				card.Buy.BackgroundColor3 = if affordable then COLORS.Green else COLORS.Panel
				card.Buy.TextColor3 = if affordable then COLORS.Text else COLORS.Red
				card.Buy.AutoButtonColor = true
			else
				card.Next.Text = ""
				card.Buy.Text = Locale.T("GuardMaxed")
				card.Buy.BackgroundColor3 = COLORS.Panel
				card.Buy.TextColor3 = COLORS.Muted
				card.Buy.AutoButtonColor = false
			end
		end
	end

	for _, name in DefenseWindow.Attributes do
		player:GetAttributeChangedSignal(name):Connect(render)
	end
	player:GetAttributeChangedSignal("Coins"):Connect(function()
		if window.Visible then
			render()
		end
	end)
	window:GetPropertyChangedSignal("Visible"):Connect(render)
	render()
end

return DefenseWindow
