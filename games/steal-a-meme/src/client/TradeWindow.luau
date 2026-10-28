-- Обмен мемами между игроками. Клиент только показывает состояние и шлёт намерения; что можно
-- отдать, кто готов и сам обмен решает сервер (TradeService).
--  * Окно выбора игрока ("TradePick") -> Remotes.TradeRequest(userId).
--  * Входящий запрос (Remotes.TradeIncoming(fromUserId, fromName)) — карточка справа
--    «Принять / Отказать» -> Remotes.TradeRespond(fromUserId, accept); пропадает через Config.Trade.RequestTimeout.
--  * Окно обмена — пока Remotes.TradeState присылает state (nil — обмен закрыт). Слева свои мемы
--    (модели в Memes своей базы: CreatureId, Mutation, Viral, Slot; несомых State == "Carried" пропускаем),
--    нажатие добавляет/убирает слот -> Remotes.TradeSetOffer(slots); справа state.TheirOffer.
--    «Готов» -> Remotes.TradeReady(bool), «Отмена» / крестик -> Remotes.TradeCancel().
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Locale = require(Shared:WaitForChild("Locale"))
local UiKit = require(script.Parent:WaitForChild("UiKit"))
local Util = require(script.Parent:WaitForChild("Util"))

local COLORS = UiKit.Colors
local create = UiKit.create
local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local SELECTED_COLOR = Color3.fromRGB(40, 95, 60)
local VIRAL_COLOR = Color3.fromRGB(255, 80, 220)

local TradeWindow = {}

local function remote(name: string): RemoteEvent
	return Remotes:WaitForChild(name) :: RemoteEvent
end

-- Список с прокруткой; grid = true — две колонки карточек мемов
local function scroller(parent: Instance, position: UDim2, size: UDim2, grid: boolean): ScrollingFrame
	local layout = if grid
		then create("UIGridLayout", {
			CellSize = UDim2.new(0.5, -4, 0, 62),
			CellPadding = UDim2.fromOffset(6, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		})
		else create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })
	return create("ScrollingFrame", {
		Position = position,
		Size = size,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = parent,
	}, { layout, create("UIPadding", { PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 2) }) })
end

-- Карточка мема: эмодзи, имя (всегда по-английски), мутация/вирусный, доход в секунду
local function memeCard(parent: Instance, order: number, id: string, mutation: string, viral: boolean): TextButton
	local creature = Config.GetCreature(id)
	local card = UiKit.button({
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = COLORS.PanelLight,
		LayoutOrder = order,
		Parent = parent,
	})
	create("UIStroke", {
		Name = "Selected",
		Color = COLORS.Green,
		Thickness = 3,
		Enabled = false,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = card,
	})
	UiKit.text({
		Text = if creature then creature.Face else "❓",
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(4, 7),
		Size = UDim2.fromOffset(46, 46),
		Parent = card,
	})
	UiKit.text({
		Text = if creature then creature.Name else id,
		TextScaled = true,
		Position = UDim2.fromOffset(54, 4),
		Size = UDim2.new(1, -58, 0, 20),
		Parent = card,
	}, { create("UITextSizeConstraint", { MaxTextSize = 15, MinTextSize = 7 }) })
	local mut = Config.GetMutation(mutation)
	local tags = {}
	if mut.Id ~= "None" then
		table.insert(tags, Locale.Name(mut))
	end
	if viral then
		table.insert(tags, Locale.T("BbViral"))
	end
	UiKit.text({
		Text = table.concat(tags, " · "),
		TextScaled = true,
		TextColor3 = if viral then VIRAL_COLOR else (mut.Color or COLORS.Muted),
		Position = UDim2.fromOffset(54, 24),
		Size = UDim2.new(1, -58, 0, 16),
		Parent = card,
	}, { create("UITextSizeConstraint", { MaxTextSize = 13, MinTextSize = 7 }) })
	UiKit.text({
		Text = Locale.T("BbIncome", { Coins = Config.BaseIncome(id, mutation, viral) }),
		TextScaled = true,
		TextColor3 = COLORS.Green,
		Position = UDim2.fromOffset(54, 41),
		Size = UDim2.new(1, -58, 0, 16),
		Parent = card,
	}, { create("UITextSizeConstraint", { MaxTextSize = 13, MinTextSize = 7 }) })
	return card
end

-- ===== Выбор игрока =====
local function buildPicker(ctx)
	local window, body = UiKit.window(ctx.Gui, Locale.T("TradePickTitle"), Vector2.new(420, 420))
	window.Name = "TradePickWindow"
	ctx.Register("TradePick", window)
	local list = scroller(body, UDim2.new(), UDim2.fromScale(1, 1), false)

	local function render()
		for _, child in list:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local others = {}
		for _, other in Players:GetPlayers() do
			if other ~= player then
				table.insert(others, other)
			end
		end
		table.sort(others, function(a, b)
			return a.DisplayName:lower() < b.DisplayName:lower()
		end)
		if #others == 0 then
			UiKit.text({
				Text = Locale.T("TradePickEmpty"),
				TextSize = 16,
				TextColor3 = COLORS.Muted,
				TextXAlignment = Enum.TextXAlignment.Center,
				Size = UDim2.new(1, 0, 0, 40),
				Parent = list,
			})
			return
		end
		for order, other in others do
			local button = UiKit.button({
				Text = "",
				BackgroundColor3 = COLORS.PanelLight,
				Size = UDim2.new(1, 0, 0, 52),
				LayoutOrder = order,
				Parent = list,
			})
			UiKit.text({
				Text = other.DisplayName,
				TextScaled = true,
				Position = UDim2.fromOffset(12, 4),
				Size = UDim2.new(1, -70, 0, 26),
				Parent = button,
			}, { create("UITextSizeConstraint", { MaxTextSize = 18, MinTextSize = 10 }) })
			UiKit.text({
				Text = "@" .. other.Name,
				TextSize = 13,
				Font = Enum.Font.Gotham,
				TextColor3 = COLORS.Muted,
				Position = UDim2.fromOffset(12, 30),
				Size = UDim2.new(1, -70, 0, 16),
				Parent = button,
			})
			UiKit.text({
				Text = "🤝",
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Center,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -8, 0.5, 0),
				Size = UDim2.fromOffset(40, 40),
				Parent = button,
			})
			local userId = other.UserId
			button.Activated:Connect(function()
				-- Ответ (отправлено / занят / перезарядка) пришлёт сервер через Notify
				remote("TradeRequest"):FireServer(userId)
				window.Visible = false
			end)
		end
	end

	window:GetPropertyChangedSignal("Visible"):Connect(function()
		if window.Visible then
			render()
		end
	end)
	Players.PlayerAdded:Connect(function()
		if window.Visible then
			render()
		end
	end)
	Players.PlayerRemoving:Connect(function()
		if window.Visible then
			task.defer(render)
		end
	end)
end

-- ===== Входящие запросы =====
local function buildIncoming(ctx)
	local holder = create("Frame", {
		Name = "TradeRequests",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.42, 0),
		Size = UDim2.fromOffset(300, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		ZIndex = 15,
		Parent = ctx.Gui,
	}, {
		create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	ctx.Scale(holder)

	local cards: { [number]: Frame } = {}
	local count = 0

	local function dismiss(userId: number)
		local card = cards[userId]
		if card then
			cards[userId] = nil
			card:Destroy()
		end
	end

	local function show(fromUserId: number, fromName: string)
		dismiss(fromUserId)
		count += 1
		local card = create("Frame", {
			Size = UDim2.fromOffset(300, 112),
			BackgroundColor3 = COLORS.Panel,
			BackgroundTransparency = 0.05,
			LayoutOrder = count,
			Parent = holder,
		}, {
			UiKit.corner(12),
			UiKit.padding(10),
			create("UIStroke", { Color = COLORS.Purple, Thickness = 2 }),
		})
		UiKit.text({
			Text = Locale.T("TradeIncomingText", { Player = fromName }),
			TextScaled = true,
			TextWrapped = true,
			Size = UDim2.new(1, 0, 0, 36),
			Parent = card,
		}, { create("UITextSizeConstraint", { MaxTextSize = 18, MinTextSize = 10 }) })
		local timer = create("Frame", {
			Position = UDim2.fromOffset(0, 40),
			Size = UDim2.new(1, 0, 0, 4),
			BackgroundColor3 = COLORS.Purple,
			BorderSizePixel = 0,
			Parent = card,
		})
		local accept = UiKit.button({
			Text = Locale.T("TradeAccept"),
			TextSize = 18,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(0.5, -4, 0, 44),
			BackgroundColor3 = COLORS.Green,
			Parent = card,
		})
		local decline = UiKit.button({
			Text = Locale.T("TradeDecline"),
			TextSize = 18,
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.fromScale(1, 1),
			Size = UDim2.new(0.5, -4, 0, 44),
			BackgroundColor3 = COLORS.Red,
			Parent = card,
		})
		cards[fromUserId] = card

		local timeout = Config.Trade.RequestTimeout
		TweenService:Create(timer, TweenInfo.new(timeout, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 0, 4) }):Play()
		accept.Activated:Connect(function()
			dismiss(fromUserId)
			remote("TradeRespond"):FireServer(fromUserId, true)
		end)
		decline.Activated:Connect(function()
			dismiss(fromUserId)
			remote("TradeRespond"):FireServer(fromUserId, false)
		end)
		task.delay(timeout, function()
			if cards[fromUserId] == card then
				dismiss(fromUserId)
			end
		end)
	end

	task.spawn(function()
		remote("TradeIncoming").OnClientEvent:Connect(function(fromUserId, fromName)
			if type(fromUserId) ~= "number" then
				return
			end
			show(fromUserId, if type(fromName) == "string" then fromName else "?")
		end)
	end)

	-- Начался обмен — старые запросы больше не нужны
	return function()
		for userId in cards do
			dismiss(userId)
		end
	end
end

-- ===== Окно обмена =====
local function buildTrade(ctx, clearRequests: () -> ())
	-- Окно не регистрируется в ctx: другие окна не должны закрывать идущий обмен
	local window, body = UiKit.window(ctx.Gui, "", Vector2.new(760, 460))
	window.Name = "TradeWindow"
	window.ZIndex = 8
	local title = window:FindFirstChildWhichIsA("TextLabel") :: TextLabel

	local left = create("Frame", {
		Size = UDim2.new(0.5, -4, 1, -60),
		BackgroundColor3 = COLORS.Panel,
		BackgroundTransparency = 1,
		Parent = body,
	})
	local right = create("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.5, -4, 1, -60),
		BackgroundTransparency = 1,
		Parent = body,
	})
	local myHeader = UiKit.text({ TextScaled = true, TextColor3 = COLORS.Gold, Size = UDim2.new(1, 0, 0, 22), Parent = left }, {
		create("UITextSizeConstraint", { MaxTextSize = 18 }),
	})
	local tip = UiKit.text({
		Text = Locale.T("TradeTip"),
		TextScaled = true,
		Font = Enum.Font.Gotham,
		TextColor3 = COLORS.Muted,
		Position = UDim2.fromOffset(0, 22),
		Size = UDim2.new(1, 0, 0, 16),
		Parent = left,
	}, { create("UITextSizeConstraint", { MaxTextSize = 13 }) })
	local myList = scroller(left, UDim2.fromOffset(0, 40), UDim2.new(1, 0, 1, -40), true)
	local theirHeader = UiKit.text({ TextScaled = true, TextColor3 = COLORS.Gold, Size = UDim2.new(1, 0, 0, 22), Parent = right }, {
		create("UITextSizeConstraint", { MaxTextSize = 18 }),
	})
	local theirList = scroller(right, UDim2.fromOffset(0, 40), UDim2.new(1, 0, 1, -40), true)

	local status = UiKit.text({
		TextScaled = true,
		TextWrapped = true,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, -280, 0, 50),
		Parent = body,
	}, { create("UITextSizeConstraint", { MaxTextSize = 18, MinTextSize = 9 }) })
	local ready = UiKit.button({
		TextSize = 20,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -132, 1, 0),
		Size = UDim2.fromOffset(140, 50),
		BackgroundColor3 = COLORS.Green,
		Parent = body,
	})
	local cancel = UiKit.button({
		Text = Locale.T("TradeBtnCancel"),
		TextSize = 18,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.fromOffset(124, 50),
		BackgroundColor3 = COLORS.Red,
		Parent = body,
	})

	local state: any = nil
	local pending: { number } = {} -- свои выбранные слоты (сразу после нажатия, до ответа сервера)

	local function isPending(slot: number): boolean
		return table.find(pending, slot) ~= nil
	end

	-- Свои мемы на базе: { Slot, Id, Mut, Viral }, сначала самые доходные
	local function myMemes()
		local result = {}
		local plot = Util.myPlot()
		local folder = plot and plot:FindFirstChild("Memes")
		if not folder then
			return result
		end
		for _, model in folder:GetChildren() do
			local id = Util.str(model, "CreatureId")
			local slot = Util.num(model, "Slot")
			if id ~= "" and slot > 0 and Util.str(model, "State") ~= "Carried" and Config.GetCreature(id) then
				table.insert(result, { Slot = slot, Id = id, Mut = Util.str(model, "Mutation"), Viral = Util.bool(model, "Viral") })
			end
		end
		table.sort(result, function(a, b)
			local ia, ib = Config.BaseIncome(a.Id, a.Mut, a.Viral), Config.BaseIncome(b.Id, b.Mut, b.Viral)
			if ia == ib then
				return a.Slot < b.Slot
			end
			return ia > ib
		end)
		return result
	end

	local function clear(frame: Instance)
		for _, child in frame:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
	end

	local function emptyNote(parent: Instance, key: string)
		UiKit.text({
			Text = Locale.T(key),
			TextSize = 14,
			TextWrapped = true,
			TextColor3 = COLORS.Muted,
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = parent,
		})
	end

	local render: () -> ()

	local function toggle(slot: number)
		if not state then
			return
		end
		local slots = table.clone(pending)
		local index = table.find(slots, slot)
		if index then
			table.remove(slots, index)
		elseif #slots >= Config.Trade.MaxMemes then
			ctx.Toast(Locale.T("TradeMaxMemes", { Count = Config.Trade.MaxMemes }), "error")
			return
		else
			table.insert(slots, slot)
		end
		pending = slots
		remote("TradeSetOffer"):FireServer(slots)
		render()
	end

	local function renderMine()
		clear(myList)
		local memes = myMemes()
		if #memes == 0 then
			emptyNote(myList, "TradeNoMemes")
		end
		for order, meme in memes do
			local card = memeCard(myList, order, meme.Id, meme.Mut, meme.Viral)
			local selected = isPending(meme.Slot)
			card.BackgroundColor3 = if selected then SELECTED_COLOR else COLORS.PanelLight
			local stroke = card:FindFirstChild("Selected") :: UIStroke
			stroke.Enabled = selected
			card.Activated:Connect(function()
				toggle(meme.Slot)
			end)
		end
	end

	local function renderTheirs()
		clear(theirList)
		local offer = if state and type(state.TheirOffer) == "table" then state.TheirOffer else {}
		if #offer == 0 then
			emptyNote(theirList, "TradeNothing")
		end
		for order, meme in offer do
			if type(meme) == "table" and type(meme.Id) == "string" then
				memeCard(theirList, order, meme.Id, if type(meme.Mut) == "string" then meme.Mut else "None", meme.Viral == true)
			end
		end
	end

	local function renderStatus()
		if not state then
			return
		end
		local endsAt = if type(state.CountdownEndsAt) == "number" then state.CountdownEndsAt else 0
		if endsAt > 0 then
			status.Text = "⏳ " .. Locale.T("TradeCountdown", { Seconds = math.max(0, math.ceil(endsAt - Util.now())) })
			status.TextColor3 = COLORS.Green
		else
			status.Text = Locale.T("TradeWaiting")
			status.TextColor3 = COLORS.Muted
		end
	end

	render = function()
		if not state then
			return
		end
		local partner = if type(state.PartnerName) == "string" then state.PartnerName else "?"
		title.Text = Locale.T("TradeTitle", { Player = partner })
		myHeader.Text = Locale.T("TradeYourOffer", { Count = #pending, Max = Config.Trade.MaxMemes })
			.. (if state.MyReady then "  ✅" else "")
		theirHeader.Text = Locale.T("TradeTheirOffer", { Player = partner }) .. (if state.TheirReady then "  ✅" else "")
		ready.Text = if state.MyReady then "✅ " .. Locale.T("TradeBtnReady") else Locale.T("TradeBtnReady")
		ready.BackgroundColor3 = if state.MyReady then COLORS.Purple else COLORS.Green
		tip.Visible = not state.MyReady
		renderMine()
		renderTheirs()
		renderStatus()
	end

	-- Следим за папкой мемов своей базы, пока открыт обмен
	local memesConnections: { RBXScriptConnection } = {}
	local function watchMemes()
		for _, connection in memesConnections do
			connection:Disconnect()
		end
		table.clear(memesConnections)
		local plot = Util.myPlot()
		local folder = plot and plot:FindFirstChild("Memes")
		if not folder then
			return
		end
		local function changed()
			if state then
				task.defer(render)
			end
		end
		table.insert(memesConnections, folder.ChildAdded:Connect(changed))
		table.insert(memesConnections, folder.ChildRemoved:Connect(changed))
	end

	local closingByServer = false
	local function onState(newState: any)
		if type(newState) ~= "table" then
			state = nil
			pending = {}
			closingByServer = true
			window.Visible = false
			closingByServer = false
			for _, connection in memesConnections do
				connection:Disconnect()
			end
			table.clear(memesConnections)
			return
		end
		local opening = state == nil
		state = newState
		pending = {}
		if type(newState.MyOffer) == "table" then
			for _, item in newState.MyOffer do
				if type(item) == "table" and type(item.Slot) == "number" then
					table.insert(pending, item.Slot)
				end
			end
		end
		if opening then
			clearRequests()
			-- Прячем остальные окна, чтобы обмен был на виду
			for _, other in ctx.Windows do
				other.Visible = false
			end
			watchMemes()
		end
		window.Visible = true
		render()
	end

	ready.Activated:Connect(function()
		if state then
			remote("TradeReady"):FireServer(not state.MyReady)
		end
	end)
	cancel.Activated:Connect(function()
		if state then
			remote("TradeCancel"):FireServer()
		end
	end)
	-- Крестик окна = отмена обмена
	window:GetPropertyChangedSignal("Visible"):Connect(function()
		if not window.Visible and state and not closingByServer then
			remote("TradeCancel"):FireServer()
			window.Visible = true -- окно закроет ответ сервера (TradeState nil)
		end
	end)

	task.spawn(function()
		remote("TradeState").OnClientEvent:Connect(onState)
	end)
	task.spawn(function()
		while true do
			if state and window.Visible then
				renderStatus()
			end
			task.wait(0.2)
		end
	end)
end

function TradeWindow.Start(ctx)
	buildPicker(ctx)
	local clearRequests = buildIncoming(ctx)
	buildTrade(ctx, clearRequests)
end

return TradeWindow
