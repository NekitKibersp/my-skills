-- Баннеры сверху по центру: «В ТРЕНДЕ», Ночь Смайлика (идёт / до следующей), Удача сервера.
-- Источник — атрибуты ReplicatedStorage (TrendingId, TrendEndsAt, NightActive, NightEndsAt, NextNightAt, LuckEndsAt).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Locale = require(Shared:WaitForChild("Locale"))
local UiKit = require(script.Parent:WaitForChild("UiKit"))
local Util = require(script.Parent:WaitForChild("Util"))

local COLORS = UiKit.Colors
local create = UiKit.create

local NIGHT_COLOR = Color3.fromRGB(255, 220, 40)
local LUCK_COLOR = Color3.fromRGB(80, 230, 120)

local Banners = {}

local function banner(parent: Instance, order: number, textSize: number, stroke: Color3): TextLabel
	local label = UiKit.text({
		Text = "",
		TextSize = textSize,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.5,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, textSize + 12),
		BackgroundColor3 = COLORS.Panel,
		BackgroundTransparency = 0.15,
		LayoutOrder = order,
		Visible = false,
		Parent = parent,
	})
	UiKit.corner(10).Parent = label
	create("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), Parent = label })
	create("UIStroke", { Color = stroke, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = label })
	return label
end

function Banners.Start(ctx)
	local stack = create("Frame", {
		Name = "Banners",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 4),
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		Parent = ctx.Gui,
	}, {
		create("UIListLayout", {
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	ctx.Scale(stack)

	local trend = banner(stack, 1, 20, COLORS.Gold)
	trend.TextColor3 = COLORS.Gold
	local night = banner(stack, 2, 22, NIGHT_COLOR)
	local luck = banner(stack, 3, 16, LUCK_COLOR)
	luck.TextColor3 = LUCK_COLOR

	local function render()
		local now = Util.now()

		local trendId = Util.str(ReplicatedStorage, "TrendingId")
		trend.Visible = trendId ~= "" and Config.GetCreature(trendId) ~= nil
		if trend.Visible then
			trend.Text = Locale.T("BannerTrend", {
				Meme = trendId,
				Mult = Config.Trend.Mult,
				Time = Util.clock(Util.num(ReplicatedStorage, "TrendEndsAt") - now),
			})
		end

		if Util.bool(ReplicatedStorage, "NightActive") then
			night.Visible = true
			night.TextSize = 22
			night.Size = UDim2.fromOffset(0, 34)
			night.TextColor3 = NIGHT_COLOR
			night.BackgroundColor3 = Color3.fromRGB(40, 10, 30)
			night.Text = Locale.T("BannerNight", { Time = Util.clock(Util.num(ReplicatedStorage, "NightEndsAt") - now) })
		else
			local nextAt = Util.num(ReplicatedStorage, "NextNightAt")
			night.Visible = nextAt > now
			night.TextSize = 14
			night.Size = UDim2.fromOffset(0, 24)
			night.TextColor3 = COLORS.Muted
			night.BackgroundColor3 = COLORS.Panel
			night.Text = Locale.T("BannerNextNight", { Time = Util.clock(nextAt - now) })
		end

		local luckLeft = Util.num(ReplicatedStorage, "LuckEndsAt") - now
		luck.Visible = luckLeft > 0
		if luck.Visible then
			luck.Text = Locale.T("BannerLuck", { Time = Util.clock(luckLeft) })
		end
	end

	task.spawn(function()
		while true do
			render()
			task.wait(0.25)
		end
	end)
end

return Banners
