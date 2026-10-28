-- Колесо удачи: одно бесплатное вращение в UTC-день, остальные — из запаса Spins (Robux, пропуск, коды).
-- Клиент зовёт Remotes.Spin() -> (ok, key, segmentIndex), крутит колесо до сегмента,
-- а награду показывает Popup "Spin", который приходит после анимации.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Grant = require(script.Parent.Grant)
local Remotes = require(script.Parent.Remotes)

local SpinService = {}

local SECONDS_PER_DAY = 86400
local SPIN_COOLDOWN = 2 -- сек между вращениями (защита от спама)
local POPUP_DELAY = 4 -- сек: столько клиент крутит колесо
local REFRESH_INTERVAL = 60

local lastSpin: { [Player]: number } = {}

local function today(): number
	return os.time() // SECONDS_PER_DAY
end

local function isReady(player: Player): boolean
	return player.Parent ~= nil and player:GetAttribute("DataLoaded") == true and DataService.IsLoaded(player)
end

local function freeReady(player: Player): boolean
	return DataService.Get(player, "LastFreeSpinDay") ~= today()
end

local function refresh(player: Player)
	if DataService.IsLoaded(player) then
		player:SetAttribute("FreeSpinReady", freeReady(player))
	end
end

-- Случайный сегмент с учётом весов
local function pickSegment(): number
	local segments = Config.Spin.Segments
	local total = 0
	for _, segment in segments do
		total += segment.Weight
	end
	local roll = math.random() * total
	for index, segment in segments do
		roll -= segment.Weight
		if roll <= 0 then
			return index
		end
	end
	return #segments
end

local function spin(player: Player): (boolean, string, number?)
	if not isReady(player) then
		return false, "SpinNotReady"
	end
	local now = os.clock()
	if lastSpin[player] and now - lastSpin[player] < SPIN_COOLDOWN then
		return false, "SpinTooFast"
	end

	if freeReady(player) then
		DataService.Set(player, "LastFreeSpinDay", today())
		refresh(player)
	elseif DataService.Get(player, "Spins") >= 1 then
		DataService.Increment(player, "Spins", -1)
	else
		return false, "NoSpins"
	end
	lastSpin[player] = now

	local index = pickSegment()
	local result = Grant.Give(player, Config.Spin.Segments[index].Reward)
	-- Награда уже выдана; показываем её, когда колесо на клиенте остановится
	task.delay(POPUP_DELAY, function()
		if player.Parent then
			Remotes.Popup:FireClient(player, "Spin", result)
		end
	end)
	return true, "SpinDone", index
end

-- Добавить вращения (покупка Spins3/Spins10). false — данные не загружены, покупку повторить позже.
function SpinService.AddSpins(player: Player, n: number): boolean
	if not DataService.IsLoaded(player) then
		return false
	end
	if type(n) == "number" and n == n and n >= 1 then
		DataService.Increment(player, "Spins", math.floor(n))
	end
	return true
end

-- Вызывается из init.server после загрузки данных
function SpinService.OnLoaded(player: Player)
	refresh(player)
end

function SpinService.Start()
	Remotes.Spin.OnServerInvoke = function(player: Player)
		local ok, result, key, index = pcall(spin, player)
		if not ok then
			warn("[SpinService] Ошибка вращения колеса:", result)
			return false, "SpinNotReady"
		end
		return result, key, index
	end

	Players.PlayerRemoving:Connect(function(player)
		lastSpin[player] = nil
	end)

	-- Полночь UTC: бесплатное вращение снова доступно
	task.spawn(function()
		while true do
			task.wait(REFRESH_INTERVAL)
			for _, player in Players:GetPlayers() do
				refresh(player)
			end
		end
	end)
end

return SpinService
