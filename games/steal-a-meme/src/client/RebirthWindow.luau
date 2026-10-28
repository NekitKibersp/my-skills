-- Окно перерождения: следующий тир (Config.RebirthTier) — цена с прогрессом денег, требования к мемам
-- на базе с живыми галочками, награды (этаж, вращения, предмет, +доход) и кнопка (активна, только
-- когда всё выполнено). После последнего тира — обычная растущая цена без требований.
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

export type ReqState = { Requirement: any, Have: number, Met: boolean }
export type Status = {
	Rebirths: number,
	Cost: number,
	Coins: number,
	CashOk: boolean,
	MemesOk: boolean,
	Tier: any?,
	Reqs: { ReqState },
}

-- Id мемов, которые стоят на своей базе (несомый вором мем не считается)
local function baseMemeIds(): { string }
	local ids = {}
	local plot = Util.myPlot()
	local folder = plot and plot:FindFirstChild("Memes")
	if not folder then
		return ids
	end
	for _, model in folder:GetChildren() do
		local id = Util.str(model, "CreatureId")
		if id ~= "" and Util.str(model, "State") ~= "Carried" then
			table.insert(ids, id)
		end
	end
	return ids
end

-- Состояние следующего перерождения (для окна и подписи кнопки в HUD).
-- Каждое требование считается отдельно по всем мемам базы (как Config.MatchesRequirement).
function RebirthWindow.Status(): Status
	local rebirths = Util.num(player, "Rebirths")
	local coins = Util.num(player, "Coins")
	local cost = Config.RebirthCost(rebirths)
	local tier = Config.RebirthTier(rebirths)
	local reqs: { ReqState } = {}
	local memesOk = true
	if tier and tier.Requires then
		local ids = baseMemeIds()
		for _, requirement in tier.Requires do
			local have = 0
			for _, id in ids do
				if Config.MatchesRequirement(id, requirement) then
					have += 1
				end
			end
			local met = have >= (requirement.Count or 1)
			memesOk = memesOk and met
			table.insert(reqs, { Requirement = requirement, Have = have, Met = met })
		end
	end
	return {
		Rebirths = rebirths,
		Cost = cost,
		Coins = coins,
		CashOk = coins >= cost,
		MemesOk = memesOk,
		Tier = tier,
		Reqs = reqs,
	}
end

local function requirementText(state: ReqState): string
	local requirement = state.Requirement
	local args = {
		Mark = if state.Met then "✅" else "❌",
		Count = requirement.Count or 1,
		Have = state.Have,
	}
	if requirement.Id then
		local creature = Config.GetCreature(requirement.Id)
		args.Name = if creature then creature.Name else requirement.Id
		return Locale.T("RebirthReqMeme", args)
	end
	args.Rarity = Locale.Name(Config.GetRarity(requirement.Rarity))
	return Locale.T("RebirthReqRarity", args)
end

-- Ближайший ещё закрытый этаж после перерождения rebirths + 1 (номер этажа, нужное перерождение)
local function nextLockedFloor(rebirthsAfter: number): (number?, number?)
	for index, floor in Config.Plot.Floors do
		if floor.UnlockRebirth > rebirthsAfter then
			return index, floor.UnlockRebirth
		end
	end
	return nil, nil
end

function RebirthWindow.Start(ctx)
	local window, body = UiKit.window(ctx.Gui, Locale.T("RebirthTitle"), Vector2.new(480, 470))
	window.Name = "RebirthWindow"
	ctx.Register("Rebirth", window)

	-- Кнопка снизу, остальное прокручивается над ней
	local go = UiKit.button({
		Text = Locale.T("RebirthButton"),
		TextScaled = true,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 50),
		BackgroundColor3 = COLORS.Purple,
		Parent = body,
	})
	create("UITextSizeConstraint", { MaxTextSize = 22, Parent = go })

	local scroll = create("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, -58),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = body,
	}, {
		create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
		create("UIPadding", { PaddingRight = UDim.new(0, 8) }),
	})

	local function line(order: number, textSize: number, color: Color3?): TextLabel
		return UiKit.text({
			Text = "",
			TextSize = textSize,
			TextWrapped = true,
			TextColor3 = color or COLORS.Text,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, textSize + 4),
			LayoutOrder = order,
			Parent = scroll,
		})
	end

	local nextLabel = line(1, 16, COLORS.Muted)
	local cost = line(2, 22, COLORS.Gold)

	local bar = create("Frame", {
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundColor3 = COLORS.PanelLight,
		LayoutOrder = 3,
		Parent = scroll,
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

	local reqTitle = line(10, 16, COLORS.Muted)
	reqTitle.Text = Locale.T("RebirthReqTitle")
	-- Строки требований/наград пересоздаются при каждом render (их 1–4)
	local reqHolder = create("Frame", {
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 11,
		Parent = scroll,
	}, { create("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }) })

	local rewardsTitle = line(20, 16, COLORS.Muted)
	rewardsTitle.Text = Locale.T("RebirthRewardsTitle")
	local rewardHolder = create("Frame", {
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 21,
		Parent = scroll,
	}, { create("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }) })

	local floorHint = line(30, 14, COLORS.Muted)
	local cashReset = line(31, 14, COLORS.Muted)
	cashReset.Text = Locale.T("RebirthCashReset")

	local function setLines(holder: Frame, lines: { { Text: string, Color: Color3 } })
		for _, child in holder:GetChildren() do
			if child:IsA("TextLabel") then
				child:Destroy()
			end
		end
		for order, item in lines do
			UiKit.text({
				Text = item.Text,
				TextSize = 17,
				TextWrapped = true,
				TextColor3 = item.Color,
				AutomaticSize = Enum.AutomaticSize.Y,
				Size = UDim2.new(1, 0, 0, 21),
				LayoutOrder = order,
				Parent = holder,
			})
		end
	end

	local lastKey = ""
	local function render()
		local status = RebirthWindow.Status()
		local rebirths = status.Rebirths
		local tier = status.Tier
		local progress = math.clamp(status.Coins / status.Cost, 0, 1)

		nextLabel.Text = Locale.T("RebirthNext", { Count = rebirths + 1 })
		cost.Text = Locale.T("RebirthCost", { Price = status.Cost })
		TweenService:Create(fill, TweenInfo.new(0.25), { Size = UDim2.fromScale(progress, 1) }):Play()
		fill.BackgroundColor3 = if status.CashOk then COLORS.Green else COLORS.Gold
		barText.Text = "$" .. Format.Number(status.Coins) .. " / $" .. Format.Number(status.Cost)
			.. "  (" .. math.floor(progress * 100) .. "%)"

		-- Требования (строки пересоздаём, только если текст поменялся)
		local reqLines = {}
		if #status.Reqs == 0 then
			table.insert(reqLines, { Text = Locale.T("RebirthReqNone"), Color = COLORS.Green })
		end
		for _, state in status.Reqs do
			table.insert(reqLines, { Text = requirementText(state), Color = if state.Met then COLORS.Green else COLORS.Red })
		end

		-- Награды
		local rewardLines = {}
		table.insert(rewardLines, {
			Text = Locale.T("RebirthRewardIncome", {
				Percent = math.floor(Config.Rebirth.IncomeBonus * 100 + 0.5),
				Mult = Config.IncomeMult(rebirths + 1),
			}),
			Color = COLORS.Text,
		})
		local rewards = if tier then tier.Rewards or {} else {}
		if type(rewards.Floor) == "number" then
			table.insert(rewardLines, {
				Text = Locale.T("RebirthRewardFloor", { Floor = rewards.Floor, Slots = Config.Plot.FloorSlots }),
				Color = COLORS.Gold,
			})
		end
		if type(rewards.Spins) == "number" and rewards.Spins > 0 then
			table.insert(rewardLines, { Text = Locale.T("RebirthRewardSpins", { Count = rewards.Spins }), Color = COLORS.Text })
		end
		local item = if type(rewards.Item) == "string" then Config.GetItem(rewards.Item) else nil
		if item then
			table.insert(rewardLines, {
				Text = Locale.T("RebirthRewardItem", { Face = item.Face, Name = Locale.Name(item) }),
				Color = COLORS.Text,
			})
		end

		local key = rebirths .. "|"
		for _, entry in reqLines do
			key ..= entry.Text .. "|"
		end
		if key ~= lastKey then
			lastKey = key
			setLines(reqHolder, reqLines)
			setLines(rewardHolder, rewardLines)
		end

		-- Подсказка про этажи / бесконечные перерождения
		local floorIndex, floorRebirth = nextLockedFloor(rebirths + 1)
		if not tier then
			floorHint.Text = Locale.T("RebirthEndless", { Mult = Config.Rebirth.CostMult })
		elseif floorIndex and rewards.Floor ~= floorIndex then
			floorHint.Text = Locale.T("RebirthNextFloor", { Floor = floorIndex, Rebirth = floorRebirth })
		else
			floorHint.Text = ""
		end
		floorHint.Visible = floorHint.Text ~= ""

		-- Кнопка: активна, только когда хватает и денег, и мемов (сервер всё равно проверит)
		local ready = status.CashOk and status.MemesOk
		go.Text = if ready
			then Locale.T("RebirthButton")
			elseif not status.MemesOk then Locale.T("RebirthBtnNeedMemes")
			else Locale.T("RebirthBtnNeedCash")
		go.BackgroundColor3 = if ready then COLORS.Green else COLORS.PanelLight
		go.TextColor3 = if ready then COLORS.Text else COLORS.Muted
		go.AutoButtonColor = ready
	end

	player:GetAttributeChangedSignal("Coins"):Connect(function()
		if window.Visible then
			render()
		end
	end)
	player:GetAttributeChangedSignal("Rebirths"):Connect(render)
	window:GetPropertyChangedSignal("Visible"):Connect(render)
	render()

	-- Мемы на базе меняются часто (покупки, кражи, продажи) — пока окно открыто, перепроверяем
	task.spawn(function()
		while true do
			task.wait(0.5)
			if window.Visible then
				render()
			end
		end
	end)

	local busy = false
	go.Activated:Connect(function()
		local status = RebirthWindow.Status()
		if busy or not (status.CashOk and status.MemesOk) then
			return
		end
		busy = true
		local rebirths = status.Rebirths
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
				if success then "success" else "error",
				if success then "Rebirth" else nil
			)
		end
		if success then
			window.Visible = false
		end
	end)
end

return RebirthWindow
