-- Продажа руды, магазин, открытие зон и перерождения.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local DataService = require(script.Parent.DataService)
local Remotes = require(script.Parent.Remotes)

local ShopService = {}

local CATALOGS = {
	Tool = Config.Tools,
	Backpack = Config.Backpacks,
}

local lastSell: { [Player]: number } = {}

function ShopService.Sell(player: Player)
	if not DataService.IsLoaded(player) then
		return
	end

	local now = os.clock()
	if now - (lastSell[player] or 0) < 1 then
		return
	end
	lastSell[player] = now

	local ore = DataService.Get(player, "Ore")
	if ore <= 0 then
		return
	end

	DataService.Set(player, "Ore", 0)
	DataService.Increment(player, "Coins", ore)
	Remotes.Notify:FireClient(player, "+" .. Format.Number(ore) .. " монет", "success")
end

function ShopService.Buy(player: Player, kind: any, tier: any): (boolean, string)
	if not DataService.IsLoaded(player) then
		return false, "Данные ещё загружаются"
	end

	local catalog = CATALOGS[kind]
	if not catalog or type(tier) ~= "number" or not catalog[tier] then
		return false, "Такого товара нет"
	end

	local key = kind .. "Tier"
	if tier <= DataService.Get(player, key) then
		return false, "У тебя уже есть что-то не хуже"
	end

	local item = catalog[tier]
	if DataService.Get(player, "Coins") < item.Price then
		return false, "Не хватает монет"
	end

	DataService.Increment(player, "Coins", -item.Price)
	DataService.Set(player, key, tier)
	return true, "Куплено: " .. item.Name
end

function ShopService.UnlockZone(player: Player, zoneIndex: number)
	if not DataService.IsLoaded(player) then
		return
	end

	local zone = Config.Zones[zoneIndex]
	local maxZone = DataService.Get(player, "MaxZone")
	if maxZone >= zoneIndex then
		return
	end
	if maxZone < zoneIndex - 1 then
		Remotes.Notify:FireClient(player, "Сначала открой предыдущую зону", "error")
		return
	end
	if DataService.Get(player, "Coins") < zone.Price then
		Remotes.Notify:FireClient(player, "Нужно " .. Format.Number(zone.Price) .. " монет", "error")
		return
	end

	DataService.Increment(player, "Coins", -zone.Price)
	DataService.Set(player, "MaxZone", zoneIndex)
	Remotes.Notify:FireClient(player, "Открыта зона «" .. zone.Name .. "» ×" .. zone.Multiplier, "success")
end

function ShopService.Rebirth(player: Player): (boolean, string)
	if not DataService.IsLoaded(player) then
		return false, "Данные ещё загружаются"
	end

	local rebirths = DataService.Get(player, "Rebirths")
	local cost = Config.RebirthCost(rebirths)
	if DataService.Get(player, "Coins") < cost then
		return false, "Нужно " .. Format.Number(cost) .. " монет"
	end

	DataService.Set(player, "Coins", 0)
	DataService.Set(player, "Ore", 0)
	DataService.Set(player, "BackpackTier", 1)
	DataService.Set(player, "ToolTier", 1)
	DataService.Set(player, "Rebirths", rebirths + 1)
	return true, ("Перерождение! Множитель теперь ×%g"):format(Config.Multiplier(rebirths + 1))
end

function ShopService.Start()
	Remotes.Shop.OnServerInvoke = ShopService.Buy
	Remotes.Rebirth.OnServerInvoke = ShopService.Rebirth

	Players.PlayerRemoving:Connect(function(player)
		lastSell[player] = nil
	end)
end

return ShopService
