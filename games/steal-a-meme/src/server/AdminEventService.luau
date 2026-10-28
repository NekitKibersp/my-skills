-- Админ-ивенты: по выходным по расписанию (UTC) на всех серверах сразу, вручную — командой в чате
-- "/event <Id> [минуты]" / "/event stop" (создатель игры, Config.AdminEvents.Admins, в Studio — все)
-- и за Robux (Мем-дождь, вызывает ShopService через AdminEventService.StartEvent).
-- Состояние — атрибуты ReplicatedStorage (см. CONTRACT.md): AdminEvent, AdminEventEndsAt, NextAdminEventAt
-- и множители EventIncomeMult / EventLuckMult / EventSpawnMult / EventMutationChance, их читают другие сервисы.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local PlotService = require(script.Parent.PlotService)
local Remotes = require(script.Parent.Remotes)

local AdminEventService = {}

-- Ивент «Секретный дроп» просит выложить мема редкости на дорожку (init.server связывает с ConveyorService)
AdminEventService.OnSpawnRarity = nil :: ((string) -> ())?

local SECONDS_PER_DAY = 86400
local SCHEDULE_TICK = 15
local SECRET_DROP_INTERVAL = 20
local SCAN_DAYS = 8
local MAX_MINUTES = 120

local running: string? = nil
local token = 0 -- номер текущего запуска: отложенные задачи старого ивента не трогают новый
local lastScheduledSlot = 0 -- начало слота расписания, который уже запускали на этом сервере

-- os.time() (UTC) -> время сервера для клиента
local function toServerTime(unixTime: number): number
	return workspace:GetServerTimeNow() + (unixTime - os.time())
end

local function isEventDay(day: number): boolean
	local wday = (os.date("!*t", day * SECONDS_PER_DAY) :: any).wday
	return table.find(Config.AdminEvents.Days, wday) ~= nil
end

-- Слот расписания, который идёт прямо сейчас: (начало, Id ивента) или nil
local function currentSlot(): (number?, string?)
	local now = os.time()
	local day = now // SECONDS_PER_DAY
	if not isEventDay(day) then
		return nil, nil
	end
	for _, hour in Config.AdminEvents.Hours do
		local slotStart = day * SECONDS_PER_DAY + hour * 3600
		if now >= slotStart and now < slotStart + Config.AdminEvents.Duration then
			-- Тип ивента зависит только от слота — на всех серверах он одинаковый
			local yday = (os.date("!*t", slotStart) :: any).yday
			local types = Config.AdminEvents.Types
			return slotStart, types[(yday * 24 + hour) % #types + 1].Id
		end
	end
	return nil, nil
end

-- Начало ближайшего будущего слота (os.time) или 0
local function nextSlotStart(): number
	local now = os.time()
	local today = now // SECONDS_PER_DAY
	local hours = table.clone(Config.AdminEvents.Hours)
	table.sort(hours)
	for day = today, today + SCAN_DAYS do
		if isEventDay(day) then
			for _, hour in hours do
				local slotStart = day * SECONDS_PER_DAY + hour * 3600
				if slotStart > now then
					return slotStart
				end
			end
		end
	end
	return 0
end

local function updateNext()
	local slotStart = nextSlotStart()
	ReplicatedStorage:SetAttribute("NextAdminEventAt", if slotStart > 0 then toServerTime(slotStart) else 0)
end

local function setMultipliers(event: any?)
	ReplicatedStorage:SetAttribute("EventIncomeMult", event and event.IncomeMult or 1)
	ReplicatedStorage:SetAttribute("EventLuckMult", event and event.LuckMult or 1)
	ReplicatedStorage:SetAttribute("EventSpawnMult", event and event.SpawnMult or 1)
	ReplicatedStorage:SetAttribute("EventMutationChance", event and event.MutationChance or 0)
	-- Доход зависит от EventIncomeMult — пересчитываем атрибут Income у всех
	PlotService.RefreshAllIncome()
end

-- Запустить ивент (идущий ивент заменяется). duration в секундах, по умолчанию Config.AdminEvents.Duration.
function AdminEventService.StartEvent(id: string, duration: number?, byPlayer: Player?): boolean
	local event = if type(id) == "string" then Config.GetAdminEvent(id) else nil
	if not event then
		return false
	end
	local seconds = Config.AdminEvents.Duration
	if type(duration) == "number" and duration == duration and duration > 0 then
		seconds = math.min(duration, MAX_MINUTES * 60)
	end

	token += 1
	local myToken = token
	running = event.Id
	setMultipliers(event)
	ReplicatedStorage:SetAttribute("AdminEvent", event.Id)
	ReplicatedStorage:SetAttribute("AdminEventEndsAt", workspace:GetServerTimeNow() + seconds)

	Remotes.Fx:FireAllClients("AdminEvent", { Id = event.Id })
	Remotes.Notify:FireAllClients("AdminEventStart_" .. event.Id, { Player = byPlayer and byPlayer.DisplayName or nil }, "info")

	if event.SecretDrops then
		task.spawn(function()
			for _ = 1, event.SecretDrops do
				if token ~= myToken then
					return
				end
				local callback = AdminEventService.OnSpawnRarity
				if callback then
					task.spawn(callback, "Secret")
				end
				task.wait(SECRET_DROP_INTERVAL)
			end
		end)
	end

	task.delay(seconds, function()
		if token == myToken then
			AdminEventService.Stop()
		end
	end)
	return true
end

-- Остановить текущий ивент (если идёт)
function AdminEventService.Stop()
	if not running then
		return
	end
	local id = running
	running = nil
	token += 1
	setMultipliers(nil)
	ReplicatedStorage:SetAttribute("AdminEvent", "")
	ReplicatedStorage:SetAttribute("AdminEventEndsAt", 0)
	Remotes.Notify:FireAllClients("AdminEventEnd_" .. id, nil, "info")
	updateNext()
end

-- ===== Чат-команда =====

local adminCache: { [Player]: boolean } = {}

local function isAdmin(player: Player): boolean
	if RunService:IsStudio() then
		return true
	end
	if adminCache[player] ~= nil then
		return adminCache[player]
	end
	local result = table.find(Config.AdminEvents.Admins, player.UserId) ~= nil
	if game.CreatorType == Enum.CreatorType.User then
		result = result or player.UserId == game.CreatorId
	elseif game.CreatorType == Enum.CreatorType.Group then
		local ok, rank = pcall(function()
			return player:GetRankInGroup(game.CreatorId)
		end)
		result = result or (ok and rank >= 254)
	end
	adminCache[player] = result
	return result
end

local function findEventId(name: string): string?
	for _, event in Config.AdminEvents.Types do
		if string.lower(event.Id) == string.lower(name) then
			return event.Id
		end
	end
	return nil
end

local function onChatted(player: Player, message: string)
	if type(message) ~= "string" or string.sub(message, 1, 6) ~= "/event" then
		return
	end
	if not isAdmin(player) then
		return
	end
	local words = string.split(message, " ")
	local name = words[2] or ""
	if string.lower(name) == "stop" then
		AdminEventService.Stop()
		return
	end
	local id = findEventId(name)
	if not id then
		Remotes.Notify:FireClient(player, "AdminEventUnknown", { Name = name }, "error")
		return
	end
	local minutes = tonumber(words[3])
	local duration = if minutes and minutes > 0 then math.min(minutes, MAX_MINUTES) * 60 else nil
	AdminEventService.StartEvent(id, duration, player)
end

local function watchPlayer(player: Player)
	player.Chatted:Connect(function(message)
		onChatted(player, message)
	end)
end

function AdminEventService.Start()
	ReplicatedStorage:SetAttribute("AdminEvent", "")
	ReplicatedStorage:SetAttribute("AdminEventEndsAt", 0)
	ReplicatedStorage:SetAttribute("EventIncomeMult", 1)
	ReplicatedStorage:SetAttribute("EventLuckMult", 1)
	ReplicatedStorage:SetAttribute("EventSpawnMult", 1)
	ReplicatedStorage:SetAttribute("EventMutationChance", 0)
	updateNext()

	Players.PlayerAdded:Connect(watchPlayer)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		adminCache[player] = nil
	end)

	-- Расписание: каждые SCHEDULE_TICK секунд смотрим, не начался ли слот
	task.spawn(function()
		while true do
			local slotStart, id = currentSlot()
			if slotStart and id and slotStart ~= lastScheduledSlot and not running then
				lastScheduledSlot = slotStart
				-- Конец по расписанию, а не «от старта»: серверы, подключившиеся позже, закончат одновременно
				local left = slotStart + Config.AdminEvents.Duration - os.time()
				AdminEventService.StartEvent(id, left)
			end
			updateNext()
			task.wait(SCHEDULE_TICK)
		end
	end)
end

return AdminEventService
