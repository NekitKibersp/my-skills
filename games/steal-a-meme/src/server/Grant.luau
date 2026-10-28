-- Выдача награды по описанию из конфига (коды, колесо удачи, Мем-пропуск, календарь).
-- reward = { Kind = "Coins" | "Meme" | "Spins" | "Item" | "Skin", ... } — см. Config.Codes.
-- Возвращает таблицу для Popup: { Coins?, Meme?, Spins?, Item?, Skin? }.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)

local Grant = {}

-- Колбэки из init.server: предмет выдан (перевыдать рюкзак), скин выдан (обновить SkinsJson)
Grant.OnItemGranted = nil :: ((Player) -> ())?
Grant.OnSkinGranted = nil :: ((Player) -> ())?

local function incomeCoins(player: Player, incomeSeconds: number?, minCoins: number?): number
	return math.max(minCoins or 0, math.floor(PlotService.IncomeOf(player) * (incomeSeconds or 0)))
end

local function coins(player: Player, amount: number, result: { [string]: any })
	PlotService.AddCoins(player, amount)
	result.Coins = (result.Coins or 0) + amount
end

-- Случайный обычный мем редкости (без сезонных, лимитированных и эксклюзивов)
function Grant.RandomMeme(rarity: string): string?
	local pool = {}
	for _, creature in Config.Creatures do
		if creature.Rarity == rarity and not creature.Event and not creature.Limited and not creature.Exclusive then
			table.insert(pool, creature.Id)
		end
	end
	if #pool == 0 then
		return nil
	end
	return pool[math.random(1, #pool)]
end

function Grant.Give(player: Player, reward: any): { [string]: any }
	local result: { [string]: any } = {}
	if not DataService.IsLoaded(player) or type(reward) ~= "table" then
		return result
	end
	local kind = reward.Kind
	if kind == "Coins" then
		coins(player, incomeCoins(player, reward.IncomeSeconds, reward.MinCoins), result)
	elseif kind == "Spins" then
		DataService.Increment(player, "Spins", reward.Amount or 1)
		result.Spins = reward.Amount or 1
	elseif kind == "Meme" then
		local id = reward.Id or Grant.RandomMeme(reward.Rarity)
		if id and Config.GetCreature(id) then
			if PlotService.AddMeme(player, id, "None", false) then
				result.Meme = id
			else
				-- База заполнена — половина цены мема деньгами
				coins(player, math.max(1, math.floor(Config.PriceOf(id, "None") * 0.5)), result)
			end
		end
	elseif kind == "Item" then
		local item = Config.GetItem(reward.ItemId)
		local items = DataService.GetTable(player, "Items")
		if item and not item.Pass and not items[item.Id] then
			items[item.Id] = true
			result.Item = item.Id
			if Grant.OnItemGranted then
				task.spawn(Grant.OnItemGranted, player)
			end
		else
			coins(player, incomeCoins(player, 600, 2500), result)
		end
	elseif kind == "Skin" then
		local skin = Config.GetSkin(reward.SkinId)
		local skins = DataService.GetTable(player, "Skins")
		skins.Owned = skins.Owned or {}
		if skin and not skins.Owned[skin.Id] then
			skins.Owned[skin.Id] = true
			result.Skin = skin.Id
			if Grant.OnSkinGranted then
				task.spawn(Grant.OnSkinGranted, player)
			end
		else
			coins(player, incomeCoins(player, 600, 2500), result)
		end
	end
	return result
end

return Grant
