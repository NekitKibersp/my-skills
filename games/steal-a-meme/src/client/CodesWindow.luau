-- Окно кодов: поле ввода + «Активировать» -> Remotes.RedeemCode(text).
-- Проверяет код и выдаёт награду сервер (Config.Codes); награда приходит Popup "Code".
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Locale = require(Shared:WaitForChild("Locale"))
local Rewards = require(script.Parent:WaitForChild("Rewards"))
local UiKit = require(script.Parent:WaitForChild("UiKit"))

local COLORS = UiKit.Colors
local create = UiKit.create

local MAX_LENGTH = 32

local CodesWindow = {}

function CodesWindow.Start(ctx)
	local window, body = UiKit.window(ctx.Gui, Locale.T("CodesTitle"), Vector2.new(420, 230))
	window.Name = "CodesWindow"
	ctx.Register("Codes", window)

	UiKit.text({
		Text = Locale.T("CodesHint"),
		TextScaled = true,
		TextWrapped = true,
		Font = Enum.Font.Gotham,
		TextColor3 = COLORS.Muted,
		Size = UDim2.new(1, 0, 0, 36),
		Parent = body,
	}, { create("UITextSizeConstraint", { MaxTextSize = 15 }) })

	local box = create("TextBox", {
		Text = "",
		PlaceholderText = Locale.T("CodesPlaceholder"),
		PlaceholderColor3 = COLORS.Muted,
		ClearTextOnFocus = false,
		Font = Enum.Font.GothamBold,
		TextSize = 22,
		TextColor3 = COLORS.Text,
		BackgroundColor3 = COLORS.PanelLight,
		Position = UDim2.fromOffset(0, 44),
		Size = UDim2.new(1, 0, 0, 50),
		Parent = body,
	}, { UiKit.corner(10), create("UIStroke", { Color = COLORS.Purple, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) })

	local redeem = UiKit.button({
		Text = Locale.T("CodesRedeem"),
		TextSize = 22,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 104),
		Size = UDim2.new(0.7, 0, 0, 50),
		BackgroundColor3 = COLORS.Green,
		Parent = body,
	})

	-- Ограничиваем длину прямо в поле (сервер всё равно проверит)
	box:GetPropertyChangedSignal("Text"):Connect(function()
		if #box.Text > MAX_LENGTH then
			box.Text = string.sub(box.Text, 1, MAX_LENGTH)
		end
	end)

	local busy = false
	local function submit()
		if busy then
			return
		end
		local code = string.gsub(box.Text, "^%s+", "")
		code = string.gsub(code, "%s+$", "")
		if code == "" then
			ctx.Toast(Locale.T("CodesEmpty"), "error")
			return
		end
		busy = true
		redeem.AutoButtonColor = false
		redeem.BackgroundColor3 = COLORS.PanelLight
		local success, key = Rewards.invoke("RedeemCode", code)
		busy = false
		redeem.AutoButtonColor = true
		redeem.BackgroundColor3 = COLORS.Green
		if type(key) == "string" then
			ctx.Toast(Locale.T(key), if success then "success" else "error")
		end
		if success then
			box.Text = ""
		end
	end

	redeem.Activated:Connect(submit)
	box.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			submit()
		end
	end)
end

return CodesWindow
