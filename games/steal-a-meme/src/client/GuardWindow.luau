-- Окно стража базы (Котёнок с мечом): текущий уровень, что даст следующий, цена.
-- Покупку проверяет сервер (Remotes.UpgradeGuard), цены — из Config.Guard.
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

local GuardWindow = {}

function GuardWindow.Start(ctx)
	local window, body = UiKit.window(ctx.Gui, Locale.T("GuardTitle"), Vector2.new(460, 330))
	window.Name = "GuardWindow"
	ctx.Register("Guard", window)

	create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = body })

	UiKit.text({
		Text = Locale.T("GuardInfo"),
		TextSize = 16,
		TextWrapped = true,
		TextColor3 = COLORS.Muted,
		Size = UDim2.new(1, 0, 0, 40),
		LayoutOrder = 1,
		Parent = body,
	})
	local level = UiKit.text({ TextSize = 22, TextColor3 = COLORS.Gold, Size = UDim2.new(1, 0, 0, 28), LayoutOrder = 2, Parent = body })
	local nextInfo = UiKit.text({ TextSize = 16, TextWrapped = true, Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 3, Parent = body })
	local buy = UiKit.button({
		TextSize = 20,
		Size = UDim2.new(1, 0, 0, 50),
		BackgroundColor3 = COLORS.Green,
		LayoutOrder = 4,
		Parent = body,
	})

	local function render()
		local current = Util.num(player, "GuardLevel")
		local nextLevel = Config.Guard[current + 1]
		level.Text = Locale.T("GuardLevelNow", { Level = current, Max = #Config.Guard })
		if nextLevel then
			nextInfo.Text = Locale.T("GuardNext", { Range = nextLevel.Range, Cooldown = nextLevel.Cooldown })
			buy.Text = Locale.T(if current == 0 then "GuardBuy" else "GuardUpgrade", { Price = nextLevel.Price })
			local affordable = Util.num(player, "Coins") >= nextLevel.Price
			buy.BackgroundColor3 = if affordable then COLORS.Green else COLORS.PanelLight
			buy.AutoButtonColor = true
		else
			nextInfo.Text = ""
			buy.Text = Locale.T("GuardMaxed")
			buy.BackgroundColor3 = COLORS.Panel
			buy.AutoButtonColor = false
		end
	end

	player:GetAttributeChangedSignal("GuardLevel"):Connect(render)
	player:GetAttributeChangedSignal("Coins"):Connect(function()
		if window.Visible then
			render()
		end
	end)
	window:GetPropertyChangedSignal("Visible"):Connect(render)
	render()

	local busy = false
	buy.Activated:Connect(function()
		local current = Util.num(player, "GuardLevel")
		local nextLevel = Config.Guard[current + 1]
		if busy or not nextLevel then
			return
		end
		busy = true
		local ok, success, key = pcall(function()
			return Remotes:WaitForChild("UpgradeGuard"):InvokeServer()
		end)
		busy = false
		if ok and type(key) == "string" then
			ctx.Toast(
				Locale.T(key, { Level = current + 1, Price = nextLevel.Price }),
				if success then "success" else "error"
			)
		end
		render()
	end)
end

return GuardWindow
