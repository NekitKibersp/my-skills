-- Коды, бонус за друзей на сервере и бонус участникам группы.
-- Коды: Remotes.RedeemCode(code) -> (ok, key); введённые коды — DataService.GetTable(player, "Codes") = { [CODE] = true }.
-- Друзья: атрибут FriendBoost (доля, 0..Config.Social.FriendBoostMax) пересчитывается при входе/выходе игроков.
-- Группа: атрибут InGroup; Remotes.CheckGroup перепроверяет после вступления.
-- Оба бонуса учитывает PlotService.IncomeOf.
local GroupService = game:GetService("GroupService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local Grant = require(script.Parent.Grant)
local AnalyticsService = require(script.Parent.AnalyticsService)
local Remotes = require(script.Parent.Remotes)

local SocialService = {}

local CODE_MAX_LENGTH = 30
local CODE_COOLDOWN = 1
local GROUP_COOLDOWN = 5

local active: { [Player]: boolean } = {} -- игроки с загруженными данными
local lastCode: { [Player]: number } = {}
local lastGroupCheck: { [Player]: number } = {}
-- Кеш дружбы по паре "меньшийId:большийId" (IsFriendsWith — запрос к сети)
local friendCache: { [string]: boolean } = {}

local function now(): number
	return os.clock()
end

-- ===== Коды =====

local function normalize(code: string): string
	return (string.upper(code):match("^%s*(.-)%s*$")) or ""
end

local function redeem(player: Player, code: unknown): (boolean, string)
	if not active[player] or not DataService.IsLoaded(player) then
		return false, "CodeInvalid"
	end
	local t = now()
	if t - (lastCode[player] or -math.huge) < CODE_COOLDOWN then
		return false, "CodeWait"
	end
	lastCode[player] = t
	if type(code) ~= "string" or #code > CODE_MAX_LENGTH then
		return false, "CodeInvalid"
	end
	local key = normalize(code)
	local entry = Config.Codes[key]
	if key == "" or type(entry) ~= "table" then
		return false, "CodeInvalid"
	end
	if entry.Expires and os.time() > entry.Expires then
		return false, "CodeExpired"
	end
	local used = DataService.GetTable(player, "Codes")
	if used[key] then
		return false, "CodeUsed"
	end
	-- Сначала помечаем код, потом выдаём: повторный запрос не получит награду дважды
	used[key] = true
	local result = Grant.Give(player, entry.Reward)
	if result.Coins then
		AnalyticsService.Economy(player, "Source", result.Coins, "Gameplay", "Code_" .. key)
	end
	result.Code = key
	Remotes.Popup:FireClient(player, "Code", result)
	return true, "CodeRedeemed"
end

-- ===== Друзья =====

local function pairKey(a: number, b: number): string
	if a > b then
		a, b = b, a
	end
	return a .. ":" .. b
end

local function areFriends(player: Player, other: Player): boolean
	local key = pairKey(player.UserId, other.UserId)
	local cached = friendCache[key]
	if cached ~= nil then
		return cached
	end
	local ok, result = pcall(function()
		return player:IsFriendsWith(other.UserId)
	end)
	if not ok then
		return false -- не кешируем ошибку: попробуем при следующем пересчёте
	end
	friendCache[key] = result == true
	return result == true
end

local function applyFriendBoost(player: Player, count: number)
	local social = Config.Social
	local boost = math.min(count * social.FriendBoostPer, social.FriendBoostMax)
	local old = player:GetAttribute("FriendBoost") or 0
	if math.abs(boost - old) < 1e-6 then
		return
	end
	player:SetAttribute("FriendBoost", boost)
	PlotService.RefreshIncome(player)
	if boost > old then
		Remotes.Notify:FireClient(player, "FriendBoost", { Percent = math.floor(boost * 100 + 0.5) }, "success")
	end
end

-- Пересчёт идёт в одном потоке: если состав сервера меняется во время пересчёта, просто повторяем
local recomputing = false
local dirty = false

local function recomputeAll()
	dirty = true
	if recomputing then
		return
	end
	recomputing = true
	while dirty do
		dirty = false
		local list = {}
		for player in active do
			table.insert(list, player)
		end
		for _, player in list do
			if active[player] then
				local count = 0
				for _, other in list do
					if other ~= player and active[other] and areFriends(player, other) then
						count += 1
					end
				end
				if active[player] then
					applyFriendBoost(player, count)
				end
			end
		end
	end
	recomputing = false
end

-- ===== Группа =====

local function setInGroup(player: Player, inGroup: boolean)
	local old = player:GetAttribute("InGroup") == true
	player:SetAttribute("InGroup", inGroup)
	if old ~= inGroup then
		PlotService.RefreshIncome(player)
		if inGroup then
			Remotes.Notify:FireClient(player, "GroupBoostOn", { Percent = math.floor(Config.Social.GroupBoost * 100 + 0.5) }, "success")
		end
	end
end

-- Свежая проверка: IsInGroup кеширует ответ на всю сессию, GetGroupsAsync — нет
local function checkGroupFresh(player: Player)
	local groupId = Config.Social.GroupId
	if groupId == 0 or not active[player] then
		return
	end
	local ok, groups = pcall(function()
		return GroupService:GetGroupsAsync(player.UserId)
	end)
	if not ok or type(groups) ~= "table" or not active[player] then
		return
	end
	local found = false
	for _, group in groups do
		if type(group) == "table" and group.Id == groupId then
			found = true
			break
		end
	end
	setInGroup(player, found)
end

-- ===== Жизненный цикл =====

function SocialService.OnLoaded(player: Player)
	if not DataService.IsLoaded(player) then
		return
	end
	active[player] = true
	player:SetAttribute("FriendBoost", 0)
	player:SetAttribute("InGroup", false)
	task.spawn(recomputeAll)

	local groupId = Config.Social.GroupId
	if groupId ~= 0 then
		task.spawn(function()
			local ok, inGroup = pcall(function()
				return player:IsInGroup(groupId)
			end)
			if ok and active[player] then
				setInGroup(player, inGroup == true)
			end
		end)
	end
end

function SocialService.OnPlayerRemoving(player: Player)
	local wasActive = active[player]
	active[player] = nil
	lastCode[player] = nil
	lastGroupCheck[player] = nil
	local prefix = player.UserId .. ":"
	local suffix = ":" .. player.UserId
	for key in friendCache do
		if string.sub(key, 1, #prefix) == prefix or string.sub(key, -#suffix) == suffix then
			friendCache[key] = nil
		end
	end
	if wasActive then
		task.spawn(recomputeAll)
	end
end

function SocialService.Start()
	Remotes.RedeemCode.OnServerInvoke = function(player, code)
		return redeem(player, code)
	end
	Remotes.CheckGroup.OnServerEvent:Connect(function(player)
		if Config.Social.GroupId == 0 or not active[player] then
			return
		end
		local t = now()
		if t - (lastGroupCheck[player] or -math.huge) < GROUP_COOLDOWN then
			return
		end
		lastGroupCheck[player] = t
		checkGroupFresh(player)
	end)
end

return SocialService
