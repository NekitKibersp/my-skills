-- Окно ежедневных квестов. Источник — атрибут игрока QuestsJson:
-- { List = { { Id, Goal, Progress, Claimed } }, AllClaimed = bool, ResetAt = serverTime }.
-- Описание и награда — из Config.GetQuest(Id); прогресс и цель (Goal) считает сервер.
-- Забрать — Remotes.ClaimQuest(index) / ClaimQuest("All") за бонус «все квесты».
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

local ROW_HEIGHT = 78

local QuestsWindow = {}

type Entry = { Id: string, Goal: number, Progress: number, Claimed: boolean }
type Data = { List: { Entry }, AllClaimed: boolean, ResetAt: number }

-- Разобрать QuestsJson; битые записи пропускаются
function QuestsWindow.Read(): Data
	local raw = Util.json(player, "QuestsJson")
	local data: Data = { List = {}, AllClaimed = false, ResetAt = 0 }
	if type(raw) ~= "table" then
		return data
	end
	data.AllClaimed = raw.AllClaimed == true
	data.ResetAt = if type(raw.ResetAt) == "number" then raw.ResetAt else 0
	if type(raw.List) == "table" then
		for _, entry in raw.List do
			if type(entry) == "table" and type(entry.Id) == "string" then
				table.insert(data.List, {
					Id = entry.Id,
					Goal = if type(entry.Goal) == "number" then entry.Goal else 1,
					Progress = if type(entry.Progress) == "number" then entry.Progress else 0,
					Claimed = entry.Claimed == true,
				})
			end
		end
	end
	return data
end

local function isDone(entry: Entry): boolean
	return entry.Progress >= entry.Goal
end

local function allClaimed(data: Data): boolean
	if #data.List == 0 then
		return false
	end
	for _, entry in data.List do
		if not entry.Claimed then
			return false
		end
	end
	return true
end

-- Сколько наград можно забрать прямо сейчас (для значка на кнопке HUD)
function QuestsWindow.ClaimableCount(): number
	local data = QuestsWindow.Read()
	local count = 0
	for _, entry in data.List do
		if isDone(entry) and not entry.Claimed then
			count += 1
		end
	end
	if allClaimed(data) and not data.AllClaimed then
		count += 1
	end
	return count
end

-- Число в описании и прогрессе: деньги — "$1.2K", время — "5:00", остальное — "12"
local function amount(quest, value: number): string
	if quest and quest.Stat == "Earn" then
		return "$" .. Format.Number(value)
	elseif quest and quest.Stat == "Play" then
		return Util.clock(value)
	end
	return Format.Number(value)
end

local function describe(quest, goal: number): string
	if not quest then
		return "?"
	end
	local text = if Locale.IsRussian and quest.DescRu then quest.DescRu else quest.Desc
	local goalText = if quest.Stat == "Earn" then "$" .. Format.Number(goal) else Format.Number(goal)
	return (string.gsub(text, "{Goal}", function()
		return goalText
	end))
end

function QuestsWindow.Start(ctx)
	local window, body = UiKit.window(ctx.Gui, Locale.T("QuestsTitle"), Vector2.new(560, 440))
	window.Name = "QuestsWindow"
	ctx.Register("Quests", window)

	local resetLabel = UiKit.text({
		TextScaled = true,
		TextColor3 = COLORS.Muted,
		Font = Enum.Font.Gotham,
		Size = UDim2.new(1, 0, 0, 20),
		Parent = body,
	}, { create("UITextSizeConstraint", { MaxTextSize = 15 }) })

	local list = create("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 26),
		Size = UDim2.new(1, 0, 1, -26),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = body,
	}, {
		create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
		create("UIPadding", { PaddingRight = UDim.new(0, 10) }),
	})

	local busy = false
	local function claim(index: number | string)
		if busy then
			return
		end
		busy = true
		local ok, success, key = pcall(function()
			return Remotes:WaitForChild("ClaimQuest"):InvokeServer(index)
		end)
		busy = false
		if ok and type(key) == "string" then
			ctx.Toast(Locale.T(key), if success then "success" else "error")
		end
	end

	-- Строка: описание, полоса прогресса, награда и кнопка справа. Возвращает (кнопка, полоса, подписи)
	local function row(order: number)
		local frame = create("Frame", {
			Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
			BackgroundColor3 = COLORS.PanelLight,
			LayoutOrder = order,
			Parent = list,
		}, { UiKit.corner(10) })
		local title = UiKit.text({
			TextScaled = true,
			Position = UDim2.fromOffset(12, 6),
			Size = UDim2.new(1, -150, 0, 24),
			Parent = frame,
		}, { create("UITextSizeConstraint", { MaxTextSize = 18, MinTextSize = 10 }) })
		local bar = create("Frame", {
			Position = UDim2.fromOffset(12, 34),
			Size = UDim2.new(1, -150, 0, 16),
			BackgroundColor3 = COLORS.Panel,
			Parent = frame,
		}, { UiKit.corner(6) })
		local fill = create("Frame", {
			Size = UDim2.fromScale(0, 1),
			BackgroundColor3 = COLORS.Green,
			Parent = bar,
		}, { UiKit.corner(6) })
		local barText = UiKit.text({
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextStrokeTransparency = 0.4,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 2,
			Parent = bar,
		})
		local reward = UiKit.text({
			TextScaled = true,
			TextColor3 = COLORS.Gold,
			Position = UDim2.fromOffset(12, 54),
			Size = UDim2.new(1, -150, 0, 18),
			Parent = frame,
		}, { create("UITextSizeConstraint", { MaxTextSize = 14 }) })
		local button = UiKit.button({
			TextSize = 18,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(122, 46),
			Parent = frame,
		})
		return { Frame = frame, Title = title, Bar = bar, Fill = fill, BarText = barText, Reward = reward, Button = button }
	end

	local function setButton(button: TextButton, state: "Claim" | "Done" | "Locked", text: string?)
		button.Text = text or ""
		if state == "Claim" then
			button.Text = Locale.T("QuestClaim")
			button.BackgroundColor3 = COLORS.Green
			button.TextColor3 = COLORS.Text
			button.AutoButtonColor = true
		elseif state == "Done" then
			button.Text = Locale.T("QuestDoneMark")
			button.BackgroundColor3 = COLORS.Panel
			button.TextColor3 = COLORS.Muted
			button.AutoButtonColor = false
		else
			button.BackgroundColor3 = COLORS.Panel
			button.TextColor3 = COLORS.Muted
			button.AutoButtonColor = false
		end
	end

	-- Строки квестов создаются по мере надобности и переиспользуются
	local rows = {}
	local current: Data = QuestsWindow.Read()

	local emptyLabel = UiKit.text({
		Text = Locale.T("QuestsEmpty"),
		TextSize = 16,
		TextColor3 = COLORS.Muted,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 40),
		LayoutOrder = 0,
		Parent = list,
	})

	local bonus = row(1000)
	bonus.Title.Text = Locale.T("QuestAllBonus")
	bonus.Frame.BackgroundColor3 = Color3.fromRGB(55, 45, 80)
	bonus.Button.Activated:Connect(function()
		if allClaimed(current) and not current.AllClaimed then
			claim("All")
		end
	end)

	local function render()
		current = QuestsWindow.Read()
		emptyLabel.Visible = #current.List == 0
		for index, entry in current.List do
			local r = rows[index]
			if not r then
				r = row(index)
				rows[index] = r
				local myIndex = index
				r.Button.Activated:Connect(function()
					local e = current.List[myIndex]
					if e and isDone(e) and not e.Claimed then
						claim(myIndex)
					end
				end)
			end
			r.Frame.Visible = true
			local quest = Config.GetQuest(entry.Id)
			local ratio = if entry.Goal > 0 then math.clamp(entry.Progress / entry.Goal, 0, 1) else 1
			r.Title.Text = describe(quest, entry.Goal)
			TweenService:Create(r.Fill, TweenInfo.new(0.25), { Size = UDim2.fromScale(ratio, 1) }):Play()
			r.BarText.Text = amount(quest, math.min(entry.Progress, entry.Goal)) .. " / " .. amount(quest, entry.Goal)
			r.Reward.Text = if quest then Locale.T("QuestRewardHint", { Coins = Util.coinsFor(quest.IncomeSeconds, quest.MinCoins) }) else ""
			if entry.Claimed then
				setButton(r.Button, "Done")
			elseif isDone(entry) then
				setButton(r.Button, "Claim")
			else
				setButton(r.Button, "Locked", math.floor(ratio * 100) .. "%")
			end
		end
		for index = #current.List + 1, #rows do
			rows[index].Frame.Visible = false
		end

		-- Бонус за все квесты
		local claimedCount = 0
		for _, entry in current.List do
			if entry.Claimed then
				claimedCount += 1
			end
		end
		local total = math.max(#current.List, 1)
		bonus.Frame.Visible = #current.List > 0
		bonus.Fill.Size = UDim2.fromScale(claimedCount / total, 1)
		bonus.Fill.BackgroundColor3 = COLORS.Gold
		bonus.BarText.Text = claimedCount .. " / " .. #current.List
		bonus.Reward.Text = Locale.T("QuestRewardHint", {
			Coins = Util.coinsFor(Config.Quests.AllDoneIncomeSeconds, Config.Quests.AllDoneMinCoins),
		})
		if current.AllClaimed then
			setButton(bonus.Button, "Done")
		elseif allClaimed(current) then
			setButton(bonus.Button, "Claim")
		else
			setButton(bonus.Button, "Locked", "🔒")
			bonus.Reward.Text ..= "  ·  " .. Locale.T("QuestAllHint")
		end
	end

	player:GetAttributeChangedSignal("QuestsJson"):Connect(render)
	player:GetAttributeChangedSignal("Income"):Connect(function()
		if window.Visible then
			render()
		end
	end)
	window:GetPropertyChangedSignal("Visible"):Connect(render)
	render()

	-- Таймер до сброса квестов
	task.spawn(function()
		while true do
			if window.Visible then
				local left = current.ResetAt - Util.now()
				resetLabel.Text = if current.ResetAt > 0 then Locale.T("QuestsResetIn", { Time = Util.clock(left) }) else ""
			end
			task.wait(0.5)
		end
	end)
end

return QuestsWindow
