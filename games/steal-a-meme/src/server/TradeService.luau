-- Обмен мемами между игроками (только мемы, без монет).
-- Запрос -> ответ -> окно обмена: каждый выбирает свои слоты, оба жмут «Готово»,
-- идёт отсчёт Config.Trade.ConfirmDelay, затем сервер заново всё проверяет и меняет мемов разом.
-- Мемы в предложении заблокированы (PlotService.IsTradeLocked): их нельзя продать, слить, украсть.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local Remotes = require(script.Parent.Remotes)

local TradeService = {}

type Shown = { Slot: number, Id: string, Mut: string, Viral: boolean }
type Session = {
	Players: { Player }, -- два участника
	Offers: { [Player]: { Shown } }, -- что выставлено (копия записей на момент выбора)
	Ready: { [Player]: boolean },
	CountdownEndsAt: number,
	Token: number, -- меняется при любом изменении: отложенный обмен проверяет, что ничего не поменялось
	Closed: boolean,
}
type Request = { From: Player, Target: Player, ExpiresAt: number }

local sessionOf: { [Player]: Session } = {}
local outgoing: { [Player]: Request } = {} -- от кого -> его запрос (один на игрока)
local lastRequestAt: { [Player]: number } = {}
local lastOfferAt: { [Player]: number } = {}

local OFFER_MIN_INTERVAL = 0.1 -- защита от спама TradeSetOffer

local function now(): number
	return workspace:GetServerTimeNow()
end

local function notify(player: Player, key: string, args: { [string]: any }?, kind: string?)
	if player.Parent then
		Remotes.Notify:FireClient(player, key, args, kind)
	end
end

-- Игрок в игре, данные загружены, есть база
local function isReady(player: Player): boolean
	return player.Parent ~= nil and DataService.IsLoaded(player) and PlotService.GetPlot(player) ~= nil
end

local function partnerOf(session: Session, player: Player): Player
	return if session.Players[1] == player then session.Players[2] else session.Players[1]
end

-- ===== Состояние для клиента =====

local function stateFor(session: Session, player: Player)
	local partner = partnerOf(session, player)
	local myOffer = {}
	for _, item in session.Offers[player] do
		table.insert(myOffer, { Slot = item.Slot, Id = item.Id, Mut = item.Mut, Viral = item.Viral })
	end
	local theirOffer = {}
	for _, item in session.Offers[partner] do
		-- номера чужих слотов клиенту не нужны
		table.insert(theirOffer, { Id = item.Id, Mut = item.Mut, Viral = item.Viral })
	end
	return {
		PartnerUserId = partner.UserId,
		PartnerName = partner.DisplayName,
		MyOffer = myOffer,
		TheirOffer = theirOffer,
		MyReady = session.Ready[player] == true,
		TheirReady = session.Ready[partner] == true,
		CountdownEndsAt = session.CountdownEndsAt,
	}
end

local function push(session: Session)
	for _, player in session.Players do
		if player.Parent then
			Remotes.TradeState:FireClient(player, stateFor(session, player))
		end
	end
end

local function close(session: Session, key: string?, kind: string?)
	if session.Closed then
		return
	end
	session.Closed = true
	session.Token += 1
	for _, player in session.Players do
		if sessionOf[player] == session then
			sessionOf[player] = nil
		end
		if player.Parent then
			Remotes.TradeState:FireClient(player, nil)
			if key then
				notify(player, key, nil, kind)
			end
		end
	end
end

-- Любое изменение предложения или «Готово: нет» снимает обе галочки и отсчёт
local function resetReady(session: Session)
	session.Ready = {}
	session.CountdownEndsAt = 0
	session.Token += 1
end

-- ===== Проверки и сам обмен =====

-- Сколько свободных слотов у игрока (в пределах его лимита)
local function freeSlotCount(player: Player): number
	local maxSlots = PlotService.MaxSlots(player)
	local used = {}
	for _, entry in PlotService.GetEntries(player) do
		used[entry.Slot] = true
	end
	local free = 0
	for slot = 1, maxSlots do
		if not used[slot] then
			free += 1
		end
	end
	return free
end

-- Выставленные мемы на месте и не изменились с момента показа
local function offerStillValid(player: Player, offer: { Shown }): boolean
	for _, item in offer do
		local entry = PlotService.GetEntry(player, item.Slot)
		if not entry or entry.Id ~= item.Id or entry.Mut ~= item.Mut or entry.Viral ~= item.Viral then
			return false
		end
		if PlotService.IsAway(player, item.Slot) then
			return false
		end
	end
	return true
end

-- Хватит ли места: свободные + освободившиеся (свои отданные в пределах лимита) >= входящие
local function hasRoom(player: Player, ownOffer: { Shown }, incoming: number): boolean
	local maxSlots = PlotService.MaxSlots(player)
	local freed = 0
	for _, item in ownOffer do
		if item.Slot <= maxSlots then
			freed += 1
		end
	end
	return freeSlotCount(player) + freed >= incoming
end

local function execute(session: Session)
	local a, b = session.Players[1], session.Players[2]
	if not isReady(a) or not isReady(b) then
		close(session, "TradeCancelled", "error")
		return
	end
	local offerA, offerB = session.Offers[a], session.Offers[b]
	if not offerStillValid(a, offerA) or not offerStillValid(b, offerB) then
		close(session, "TradeFailed", "error")
		return
	end
	if not hasRoom(a, offerA, #offerB) or not hasRoom(b, offerB, #offerA) then
		close(session, "TradeNoSpace", "error")
		return
	end

	-- Без yield между проверкой и обменом: сначала убираем всё, потом раздаём
	local removedA, removedB = {}, {}
	for _, item in offerA do
		local entry = PlotService.RemoveEntry(a, item.Slot)
		if entry then
			table.insert(removedA, entry)
		end
	end
	for _, item in offerB do
		local entry = PlotService.RemoveEntry(b, item.Slot)
		if entry then
			table.insert(removedB, entry)
		end
	end
	local function give(to: Player, back: Player, entries: { any })
		for _, entry in entries do
			if not PlotService.AddMeme(to, entry.Id, entry.Mut, entry.Viral) then
				-- Не должно случаться (место проверено), но мем не теряем
				if not PlotService.AddMeme(back, entry.Id, entry.Mut, entry.Viral) then
					warn("[TradeService] Мем потерян при обмене", entry.Id, to.Name, back.Name)
				end
			end
		end
	end
	give(b, a, removedA)
	give(a, b, removedB)

	close(session, "TradeDone", "success")
	-- Сохраняем обоих сразу, чтобы сбой сервера не разделил обмен на «до» и «после»
	task.spawn(DataService.Save, a)
	task.spawn(DataService.Save, b)
end

local function checkBothReady(session: Session)
	if session.Closed then
		return
	end
	local a, b = session.Players[1], session.Players[2]
	if not (session.Ready[a] and session.Ready[b]) then
		return
	end
	session.Token += 1
	local token = session.Token
	session.CountdownEndsAt = now() + Config.Trade.ConfirmDelay
	task.delay(Config.Trade.ConfirmDelay, function()
		if not session.Closed and session.Token == token then
			execute(session)
		end
	end)
end

-- ===== Обработчики remotes =====

local function onRequest(player: Player, targetUserId: unknown)
	if typeof(targetUserId) ~= "number" or targetUserId ~= targetUserId or targetUserId % 1 ~= 0 then
		return
	end
	if not isReady(player) then
		return
	end
	local t = now()
	if t - (lastRequestAt[player] or -math.huge) < Config.Trade.RequestCooldown then
		notify(player, "TradeCooldown", { Seconds = math.ceil(Config.Trade.RequestCooldown - (t - lastRequestAt[player])) }, "error")
		return
	end
	local target = Players:GetPlayerByUserId(targetUserId)
	if not target or target == player or not isReady(target) then
		notify(player, "TradeNotAvailable", nil, "error")
		return
	end
	if sessionOf[player] or sessionOf[target] then
		notify(player, "TradeBusy", nil, "error")
		return
	end
	lastRequestAt[player] = t
	local request: Request = { From = player, Target = target, ExpiresAt = t + Config.Trade.RequestTimeout }
	outgoing[player] = request
	Remotes.TradeIncoming:FireClient(target, player.UserId, player.DisplayName)
	notify(player, "TradeRequestSent", { Player = target.DisplayName }, "info")

	task.delay(Config.Trade.RequestTimeout, function()
		if outgoing[player] == request then
			outgoing[player] = nil
			notify(player, "TradeExpired", { Player = target.DisplayName }, "info")
		end
	end)
end

local function onRespond(player: Player, fromUserId: unknown, accept: unknown)
	if typeof(fromUserId) ~= "number" or typeof(accept) ~= "boolean" then
		return
	end
	local from = Players:GetPlayerByUserId(fromUserId)
	if not from then
		return
	end
	local request = outgoing[from]
	if not request or request.Target ~= player or request.ExpiresAt < now() then
		return
	end
	outgoing[from] = nil
	if not accept then
		notify(from, "TradeDeclined", { Player = player.DisplayName }, "error")
		return
	end
	if not isReady(player) or not isReady(from) then
		notify(player, "TradeNotAvailable", nil, "error")
		return
	end
	if sessionOf[player] or sessionOf[from] then
		notify(player, "TradeBusy", nil, "error")
		return
	end
	-- Входящие запросы, отправленные самим участникам, больше не актуальны
	outgoing[player] = nil
	local session: Session = {
		Players = { from, player },
		Offers = { [from] = {}, [player] = {} },
		Ready = {},
		CountdownEndsAt = 0,
		Token = 0,
		Closed = false,
	}
	sessionOf[from] = session
	sessionOf[player] = session
	push(session)
end

-- Проверка формы: массив уникальных целых слотов, не больше MaxMemes
local function parseSlots(slots: unknown): { number }?
	if typeof(slots) ~= "table" then
		return nil
	end
	local list = slots :: { [any]: any }
	local count = 0
	for _ in list do
		count += 1
		if count > Config.Trade.MaxMemes then
			return nil
		end
	end
	local result = {}
	local seen = {}
	for i = 1, count do
		local slot = list[i]
		if typeof(slot) ~= "number" or slot % 1 ~= 0 or slot < 1 or slot > Config.AbsoluteMaxSlots or seen[slot] then
			return nil
		end
		seen[slot] = true
		table.insert(result, slot)
	end
	return result
end

local function onSetOffer(player: Player, slots: unknown)
	local session = sessionOf[player]
	if not session or session.Closed or not isReady(player) then
		return
	end
	local t = os.clock()
	if t - (lastOfferAt[player] or 0) < OFFER_MIN_INTERVAL then
		push(session) -- отбросили запрос — пусть клиент вернётся к правде
		return
	end
	lastOfferAt[player] = t

	local parsed = parseSlots(slots)
	if not parsed then
		notify(player, "TradeOfferInvalid", nil, "error")
		push(session)
		return
	end
	local offer: { Shown } = {}
	for _, slot in parsed do
		local entry = PlotService.GetEntry(player, slot)
		if not entry or PlotService.IsAway(player, slot) then
			notify(player, "TradeOfferInvalid", nil, "error")
			push(session)
			return
		end
		table.insert(offer, { Slot = slot, Id = entry.Id, Mut = entry.Mut, Viral = entry.Viral })
	end
	session.Offers[player] = offer
	resetReady(session)
	push(session)
end

local function onReady(player: Player, ready: unknown)
	if typeof(ready) ~= "boolean" then
		return
	end
	local session = sessionOf[player]
	if not session or session.Closed then
		return
	end
	if ready then
		local partner = partnerOf(session, player)
		if #session.Offers[player] == 0 and #session.Offers[partner] == 0 then
			notify(player, "TradeEmpty", nil, "error")
			return
		end
		if session.Ready[player] then
			return
		end
		session.Ready[player] = true
		checkBothReady(session)
	else
		if not session.Ready[player] and session.CountdownEndsAt == 0 then
			return
		end
		resetReady(session)
	end
	push(session)
end

local function onCancel(player: Player)
	local session = sessionOf[player]
	if session then
		close(session, "TradeCancelled", "info")
	end
end

-- ===== Публичное API =====

-- Слот выставлен в текущем обмене игрока
function TradeService.IsOffered(player: Player, slot: number): boolean
	local session = sessionOf[player]
	if not session or session.Closed then
		return false
	end
	for _, item in session.Offers[player] do
		if item.Slot == slot then
			return true
		end
	end
	return false
end

-- Отменить обмен игрока (например, он начал кражу) — без ошибки, если обмена нет
function TradeService.Cancel(player: Player)
	onCancel(player)
end

function TradeService.OnPlayerRemoving(player: Player)
	local session = sessionOf[player]
	if session then
		close(session, "TradeCancelled", "info")
	end
	outgoing[player] = nil
	for from, request in outgoing do
		if request.Target == player then
			outgoing[from] = nil
		end
	end
	lastRequestAt[player] = nil
	lastOfferAt[player] = nil
end

function TradeService.Start()
	PlotService.IsTradeLocked = TradeService.IsOffered

	Remotes.TradeRequest.OnServerEvent:Connect(onRequest)
	Remotes.TradeRespond.OnServerEvent:Connect(onRespond)
	Remotes.TradeSetOffer.OnServerEvent:Connect(onSetOffer)
	Remotes.TradeReady.OnServerEvent:Connect(onReady)
	Remotes.TradeCancel.OnServerEvent:Connect(onCancel)
end

return TradeService
