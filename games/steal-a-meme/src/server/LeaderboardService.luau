-- Глобальные таблицы лидеров на карте: «Богачи» (всего заработано) и «Воры» (успешные кражи).
-- OrderedDataStore работает только в опубликованной игре (или в Studio с включёнными API Services).
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local DataService = require(script.Parent.DataService)

local LeaderboardService = {}

local UPDATE_INTERVAL = 120
local TOP = 10

local function getStore(name: string): OrderedDataStore?
	local ok, store = pcall(function()
		return DataStoreService:GetOrderedDataStore(name)
	end)
	return if ok then store else nil
end

local names: { [number]: string } = {}
local function nameOf(userId: number): string
	if names[userId] then
		return names[userId]
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	names[userId] = if ok then name else "?"
	return names[userId]
end

local function refresh(store: OrderedDataStore, key: string, board: BasePart, prefix: string)
	for _, player in Players:GetPlayers() do
		if DataService.IsLoaded(player) then
			local value = math.floor(DataService.Get(player, key))
			pcall(function()
				store:SetAsync(tostring(player.UserId), value)
			end)
		end
	end
	local ok, pages = pcall(function()
		return store:GetSortedAsync(false, TOP)
	end)
	local list = board:FindFirstChild("Board") and (board:FindFirstChild("Board") :: SurfaceGui):FindFirstChild("List") :: TextLabel?
	if not list then
		return
	end
	if not ok then
		list.Text = "Publish the game to see the leaderboard\nОпубликуйте игру, чтобы увидеть рейтинг"
		return
	end
	local lines = {}
	for rank, item in pages:GetCurrentPage() do
		table.insert(lines, string.format("%d. %s — %s%s", rank, nameOf(tonumber(item.key) or 0), prefix, Format.Number(item.value)))
	end
	list.Text = if #lines > 0 then table.concat(lines, "\n") else "..."
end

function LeaderboardService.Start(boards: { Earned: BasePart, Stolen: BasePart })
	local earnedStore = getStore("TopEarned_v1")
	local stolenStore = getStore("TopStolen_v1")
	task.spawn(function()
		task.wait(15)
		while true do
			if earnedStore then
				refresh(earnedStore, "TotalEarned", boards.Earned, "$")
			end
			if stolenStore then
				refresh(stolenStore, "Stolen", boards.Stolen, "")
			end
			task.wait(UPDATE_INTERVAL)
		end
	end)
end

return LeaderboardService
