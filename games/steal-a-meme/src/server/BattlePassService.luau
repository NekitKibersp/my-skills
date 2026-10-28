-- Мем-пропуск (боевой пропуск сезона): XP за игровые события (Hooks), уровни, награды Free/Premium.
-- Данные: DataService.GetTable(player, "BattlePass") = { Season, Xp, Free = { [level] = true }, Premium = { [level] = true } }.
-- Ключи уровней в Free/Premium хранятся строками ("1", "5"): разреженный массив с числовыми ключами
-- не переживёт сохранение в DataStore (JSON). Наружу (BPJson) уходят обычные массивы чисел.
-- Клиент читает атрибут BPJson и просит награду через Remotes.ClaimPass(level, "Free" | "Premium").
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Grant = require(script.Parent.Grant)
local Hooks = require(script.Parent.Hooks)
local Remotes = require(script.Parent.Remotes)

local BattlePassService = {}

local PASS = Config.BattlePass
local SYNC_INTERVAL = 1 -- не чаще раза в секунду обновляем BPJson
local PLAY_SECONDS = 60 -- Xp.Play даётся за каждую полную минуту в игре
local TRACKS = { Free = true, Premium = true }

local playSeconds: { [Player]: number } = {}
local lastSync: { [Player]: number } = {}
local pendingSync: { [Player]: boolean } = {}

local function maxXp(): number
	return #PASS.Levels * PASS.XpPerLevel
end

local function levelOf(xp: number): number
	return math.min(#PASS.Levels, xp // PASS.XpPerLevel)
end

-- Сезон ещё идёт (после EndsAt XP не копится, но заработанное можно забрать)
local function isActive(): boolean
	return os.time() < PASS.EndsAt
end

local function isReady(player: Player): boolean
	return player.Parent ~= nil and player:GetAttribute("DataLoaded") == true and DataService.IsLoaded(player)
end

-- Таблица забранных уровней: оставляем только корректные ключи "1".."N"
local function cleanClaims(saved: any): { [string]: boolean }
	local result = {}
	if type(saved) ~= "table" then
		return result
	end
	for key, value in saved do
		local level = tonumber(key)
		if value == true and level and level % 1 == 0 and level >= 1 and level <= #PASS.Levels then
			result[tostring(level)] = true
		end
	end
	return result
end

-- Данные пропуска текущего сезона; чужой сезон или испорченные данные — сброс
local function ensure(player: Player): { [string]: any }
	local data = DataService.GetTable(player, "BattlePass")
	if data.Season ~= PASS.Season then
		table.clear(data)
		data.Season = PASS.Season
		data.Xp = 0
		data.Free = {}
		data.Premium = {}
		return data
	end
	if type(data.Xp) ~= "number" or data.Xp ~= data.Xp then
		data.Xp = 0
	end
	data.Xp = math.clamp(math.floor(data.Xp), 0, maxXp())
	data.Free = cleanClaims(data.Free)
	data.Premium = cleanClaims(data.Premium)
	return data
end

local function claimedList(claims: { [string]: boolean }): { number }
	local list = {}
	for key in claims do
		table.insert(list, tonumber(key) :: number)
	end
	table.sort(list)
	return list
end

-- Сразу записать BPJson (ShopService зовёт после покупки премиума)
function BattlePassService.Sync(player: Player)
	if not DataService.IsLoaded(player) then
		return
	end
	local data = ensure(player)
	local level = levelOf(data.Xp)
	lastSync[player] = os.clock()
	player:SetAttribute("BPJson", HttpService:JSONEncode({
		Season = data.Season,
		Xp = data.Xp,
		Level = level,
		XpInLevel = data.Xp - level * PASS.XpPerLevel,
		Free = claimedList(data.Free),
		Premium = claimedList(data.Premium),
		EndsAt = PASS.EndsAt,
	}))
end

-- Синхронизация с ограничением частоты: лишние вызовы склеиваются в один отложенный
local function requestSync(player: Player)
	if pendingSync[player] then
		return
	end
	local waitTime = if lastSync[player] then lastSync[player] + SYNC_INTERVAL - os.clock() else 0
	if waitTime <= 0 then
		BattlePassService.Sync(player)
		return
	end
	pendingSync[player] = true
	task.delay(waitTime, function()
		pendingSync[player] = nil
		if player.Parent and DataService.IsLoaded(player) then
			BattlePassService.Sync(player)
		end
	end)
end

local function giveXp(player: Player, amount: number, ignoreSeason: boolean?)
	if not DataService.IsLoaded(player) or (not ignoreSeason and not isActive()) then
		return
	end
	local data = ensure(player)
	if data.Xp >= maxXp() then
		return
	end
	local oldLevel = levelOf(data.Xp)
	data.Xp = math.min(maxXp(), data.Xp + amount)
	local newLevel = levelOf(data.Xp)
	if newLevel > oldLevel then
		Remotes.Notify:FireClient(player, "PassLevelUp", { Level = newLevel }, "success")
	end
	requestSync(player)
end

-- XP пропуска (например, за забранный квест: Config.BattlePass.Xp.Quest)
function BattlePassService.AddXp(player: Player, amount: number)
	if type(amount) ~= "number" or amount ~= amount or amount <= 0 then
		return
	end
	giveXp(player, math.floor(amount))
end

-- Купленные за Robux уровни (продукт PassLevels). Работает и после конца сезона.
-- Возвращает false, только если данные игрока не загружены (покупку стоит повторить позже).
function BattlePassService.AddLevels(player: Player, n: number): boolean
	if not DataService.IsLoaded(player) then
		return false
	end
	if type(n) == "number" and n == n and n >= 1 then
		giveXp(player, math.floor(n) * PASS.XpPerLevel, true)
	end
	return true
end

local function onStat(player: Player, stat: string, amount: number)
	if not isReady(player) or not isActive() or type(amount) ~= "number" or amount ~= amount or amount <= 0 then
		return
	end
	if stat == "Play" then
		-- Время приходит кусками по 5 сек: копим и платим за каждую полную минуту
		local total = (playSeconds[player] or 0) + amount
		local minutes = total // PLAY_SECONDS
		playSeconds[player] = total - minutes * PLAY_SECONDS
		if minutes > 0 then
			giveXp(player, minutes * (PASS.Xp.Play or 0))
		end
		return
	end
	local perUnit = PASS.Xp[stat]
	if perUnit and perUnit > 0 then
		giveXp(player, math.floor(perUnit * amount))
	end
end

local function claim(player: Player, level: any, track: any): (boolean, string)
	if not isReady(player) then
		return false, "PassNotReady"
	end
	if type(level) ~= "number" or level ~= level or level % 1 ~= 0 or level < 1 or level > #PASS.Levels then
		return false, "PassInvalid"
	end
	if type(track) ~= "string" or not TRACKS[track] then
		return false, "PassInvalid"
	end
	local data = ensure(player)
	if levelOf(data.Xp) < level then
		return false, "PassLocked"
	end
	if track == "Premium" and player:GetAttribute("Pass_BattlePass") ~= true then
		return false, "PassPremiumOnly"
	end
	local claims = data[track]
	local key = tostring(level)
	if claims[key] then
		return false, "PassAlreadyClaimed"
	end
	-- Сначала отмечаем, потом выдаём: повторный запрос не получит награду дважды
	claims[key] = true
	local result = Grant.Give(player, PASS.Levels[level][track])
	result.Level = level
	result.Track = track
	requestSync(player)
	Remotes.Popup:FireClient(player, "Pass", result)
	return true, "PassClaimed"
end

-- Вызывается из init.server после загрузки данных
function BattlePassService.OnLoaded(player: Player)
	BattlePassService.Sync(player)
end

function BattlePassService.Start()
	Hooks.Connect(onStat)

	Remotes.ClaimPass.OnServerInvoke = function(player: Player, level: any, track: any)
		local ok, result, key = pcall(claim, player, level, track)
		if not ok then
			warn("[BattlePassService] Ошибка выдачи награды пропуска:", result)
			return false, "PassNotReady"
		end
		return result, key
	end

	Players.PlayerRemoving:Connect(function(player)
		playSeconds[player] = nil
		lastSync[player] = nil
		pendingSync[player] = nil
	end)
end

return BattlePassService
