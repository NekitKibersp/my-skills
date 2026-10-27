-- Окно перерождения: цена, прогресс денег до цены, что даёт, кнопка.
-- Цену и условия проверяет сервер (Remotes.Rebirth), клиент только показывает и просит.
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

local RebirthWindow = {}

function RebirthWindow.Start(ctx)
	local window, body = UiKit.window(ctx.Gui, Locale.T("RebirthTitle"), Vector2.new(460, 360))
	window.Name = "RebirthWindow"
	ctx.Register("Rebirth", window)

	create("UIListLayout", {
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = body,
	})

	local cost = UiKit.text({ TextSize = 22, TextColor3 = COLORS.Gold, Size = UDim2.new(1, 0, 0, 28), LayoutOrder = 1, Parent = body })

	local bar = create("Frame", {
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundColor3 = COLORS.PanelLight,
		LayoutOrder = 2,
		Parent = body,
	}, { UiKit.corner(8) })
	local fill = create("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = COLORS.Green,
		Parent = bar,
	}, { UiKit.corner(8) })
	local barText = UiKit.text({
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.4,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
		Parent = bar,
	})

	local function perk(order: number): TextLabel
		return UiKit.text({
			TextSize = 16,
			TextWrapped = true,
			Size = UDim2.new(1, 0, 0, 22),
			LayoutOrder = order,
			Parent = body,
		})
	end
	local perkIncome = perk(3)
	local perkSlots = perk(4)
	local cashReset = perk(5)
	cashReset.TextColor3 = COLORS.Muted
	cashReset.TextSize = 14
	cashReset.Text = Locale.T("RebirthCashReset")

	local go = UiKit.button({
		Text = Locale.T("RebirthButton"),
		TextSize = 22,
		Size = UDim2.new(1, 0, 0, 50),
		BackgroundColor3 = COLORS.Purple,
		LayoutOrder = 6,
		Parent = body,
	})

	local function render()
		local rebirths = Util.num(player, "Rebirths")
		local coins = Util.num(player, "Coins")
		local price = Config.RebirthCost(rebirths)
		local progress = math.clamp(coins / price, 0, 1)

		cost.Text = Locale.T("RebirthCost", { Price = price })
		TweenService:Create(fill, TweenInfo.new(0.25), { Size = UDim2.fromScale(progress, 1) }):Play()
		barText.Text = "$" .. Format.Number(coins) .. " / $" .. Format.Number(price) .. "  (" .. math.floor(progress * 100) .. "%)"
		go.BackgroundColor3 = if progress >= 1 then COLORS.Green else COLORS.PanelLight

		perkIncome.Text = Locale.T("RebirthPerkIncome", {
			Percent = math.floor(Config.Rebirth.IncomeBonus * 100 + 0.5),
			Mult = Config.IncomeMult(rebirths + 1),
		})
		local now = Config.MaxSlots(rebirths)
		local after = Config.MaxSlots(rebirths + 1)
		perkSlots.Text = if after > now
			then Locale.T("RebirthPerkSlots", { Count = after - now })
			else Locale.T("RebirthPerkSlotsMax")
	end

	player:GetAttributeChangedSignal("Coins"):Connect(function()
		if window.Visible then
			render()
		end
	end)
	player:GetAttributeChangedSignal("Rebirths"):Connect(render)
	window:GetPropertyChangedSignal("Visible"):Connect(render)
	render()

	local busy = false
	go.Activated:Connect(function()
		if busy then
			return
		end
		busy = true
		local rebirths = Util.num(player, "Rebirths")
		local ok, success, key = pcall(function()
			return Remotes:WaitForChild("Rebirth"):InvokeServer()
		end)
		busy = false
		if not ok then
			return
		end
		if type(key) == "string" then
			ctx.Toast(
				Locale.T(key, { Count = rebirths + 1, Price = Config.RebirthCost(rebirths) }),
				if success then "success" else "error"
			)
		end
		if success then
			window.Visible = false
		end
	end)
end

return RebirthWindow
