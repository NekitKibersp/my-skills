-- Всплывающие окна от сервера (Remotes.Popup): оффлайн-доход и ежедневная награда.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Locale = require(Shared:WaitForChild("Locale"))
local UiKit = require(script.Parent:WaitForChild("UiKit"))
local Util = require(script.Parent:WaitForChild("Util"))

local COLORS = UiKit.Colors
local create = UiKit.create
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Popups = {}

function Popups.Start(ctx)
	-- Очередь: если пришли и «Оффлайн», и «Ежедневная», показываем по одному
	local queue: { { Title: string, Text: string } } = {}
	local showing = false

	local window, body = UiKit.window(ctx.Gui, "", Vector2.new(420, 260))
	window.Name = "PopupWindow"
	window.ZIndex = 10
	local title = window:FindFirstChildWhichIsA("TextLabel")

	local message = UiKit.text({
		TextSize = 22,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = COLORS.Gold,
		Size = UDim2.new(1, 0, 1, -64),
		Parent = body,
	})
	create("UITextSizeConstraint", { MaxTextSize = 24, Parent = message })
	message.TextScaled = true
	local ok = UiKit.button({
		Text = Locale.T("PopupOk"),
		TextSize = 22,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.new(0.6, 0, 0, 52),
		BackgroundColor3 = COLORS.Green,
		Parent = body,
	})

	local function showNext()
		local item = table.remove(queue, 1)
		if not item then
			showing = false
			window.Visible = false
			return
		end
		showing = true
		if title then
			title.Text = item.Title
		end
		message.Text = item.Text
		window.Visible = true
	end

	ok.Activated:Connect(showNext)
	-- Крестик в заголовке тоже переходит к следующему
	window:GetPropertyChangedSignal("Visible"):Connect(function()
		if not window.Visible and showing then
			task.defer(showNext)
		end
	end)

	Remotes:WaitForChild("Popup").OnClientEvent:Connect(function(kind, data)
		if type(data) ~= "table" then
			return
		end
		local coins = if type(data.Coins) == "number" then data.Coins else 0
		if kind == "Offline" then
			local seconds = if type(data.Seconds) == "number" then data.Seconds else 0
			table.insert(queue, {
				Title = Locale.T("PopupOfflineTitle"),
				Text = Locale.T("PopupOffline", { Coins = coins, Time = Util.clock(seconds) }),
			})
		elseif kind == "Daily" then
			table.insert(queue, {
				Title = Locale.T("PopupDailyTitle"),
				Text = Locale.T("PopupDaily", { Coins = coins, Day = if type(data.Day) == "number" then data.Day else 1 }),
			})
		else
			return
		end
		if not showing then
			showNext()
		end
	end)
end

return Popups
