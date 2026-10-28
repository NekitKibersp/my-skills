-- Общие помощники для наград v4 (коды, Мем-пропуск, колесо): описание награды из Config
-- (Kind = Coins / Meme / Spins / Item / Skin), строки всплывающего окна по данным от сервера,
-- цвет редкости и «осталось N д M ч». Сумму награды всегда считает сервер, клиент пишет «~».
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Locale = require(Shared:WaitForChild("Locale"))
local UiKit = require(script.Parent:WaitForChild("UiKit"))
local Util = require(script.Parent:WaitForChild("Util"))

local COLORS = UiKit.Colors
local player = Players.LocalPlayer

local Rewards = {}

-- Пока колесо крутится, всплывашка «Spin» ждёт (os.clock(), см. SpinWindow и Popups)
Rewards.SpinHoldUntil = 0

-- Цвет редкости для текста: «Секретный» почти чёрный — рисуем белым
function Rewards.rarityColor(rarityId: string): Color3
	if rarityId == "Secret" then
		return Color3.new(1, 1, 1)
	end
	return Config.GetRarity(rarityId).Color
end

local function colored(text: string, color: Color3): string
	return '<font color="#' .. color:ToHex() .. '">' .. text .. "</font>"
end

-- 200000 -> "2д 7ч", 5000 -> "1ч 23м", 300 -> "5:00"
function Rewards.timeLeft(seconds: number): string
	local total = math.max(0, math.floor(seconds))
	if total >= 86400 then
		return Locale.T("TimeDH", { D = total // 86400, H = (total % 86400) // 3600 })
	elseif total >= 3600 then
		return Locale.T("TimeHM", { H = total // 3600, M = (total % 3600) // 60 })
	end
	return Util.clock(total)
end

-- Награда из Config (уровень пропуска, сегмент колеса): иконка, короткая подпись, цвет
function Rewards.describe(reward: any): (string, string, Color3)
	if type(reward) ~= "table" then
		return "❔", "?", COLORS.Muted
	end
	local kind = reward.Kind
	if kind == "Meme" then
		local creature = if type(reward.Id) == "string" then Config.GetCreature(reward.Id) else nil
		if creature then
			return creature.Face, creature.Name, Rewards.rarityColor(creature.Rarity)
		end
		local rarity = Config.GetRarity(reward.Rarity)
		return "🎲", Locale.T("DailyMeme", { Rarity = Locale.Name(rarity) }), Rewards.rarityColor(rarity.Id)
	elseif kind == "Spins" then
		return "🎡", Locale.T("RewardSpins", { Count = reward.Amount or 1 }), COLORS.Purple
	elseif kind == "Item" then
		local item = Config.GetItem(reward.ItemId)
		if item then
			return item.Face, Locale.Name(item), COLORS.Purple
		end
		return "🎁", "?", COLORS.Purple
	elseif kind == "Skin" then
		local skin = Config.GetSkin(reward.SkinId)
		local icon = if skin and skin.Kind == "Base" then "🏠" else "🩴"
		return icon, Locale.T("RewardSkin", { Name = Locale.Name(skin) }), Color3.fromRGB(0, 230, 200)
	end
	return "💰", Locale.T("RewardCoinsApprox", { Coins = Util.coinsFor(reward.IncomeSeconds, reward.MinCoins) }), COLORS.Gold
end

-- Строки RichText для всплывающего окна по данным Popup { Coins?, Meme?, Spins?, Item?, Skin? }
function Rewards.lines(data: { [string]: any }): { string }
	local lines = {}
	local creature = if type(data.Meme) == "string" then Config.GetCreature(data.Meme) else nil
	if creature then
		local color = Rewards.rarityColor(creature.Rarity)
		table.insert(lines, colored(Locale.T("PopupDailyMeme", { Face = creature.Face, Name = creature.Name }), color))
		table.insert(lines, colored(Locale.Name(Config.GetRarity(creature.Rarity)), color))
	end
	if type(data.Coins) == "number" and data.Coins > 0 then
		table.insert(lines, "💰 " .. Locale.T("RewardCoins", { Coins = data.Coins }))
	end
	if type(data.Spins) == "number" and data.Spins > 0 then
		table.insert(lines, "🎡 " .. Locale.T("RewardSpins", { Count = data.Spins }))
	end
	local item = if type(data.Item) == "string" then Config.GetItem(data.Item) else nil
	if item then
		table.insert(lines, Locale.T("PopupDailyItem", { Face = item.Face, Name = Locale.Name(item) }))
	end
	local skin = if type(data.Skin) == "string" then Config.GetSkin(data.Skin) else nil
	if skin then
		table.insert(lines, "🎨 " .. Locale.T("RewardSkin", { Name = Locale.Name(skin) }))
	end
	return lines
end

-- Вызов RemoteFunction -> (success, key, extra). Нет ремоута или ошибка сети -> (false, "NotLoaded")
function Rewards.invoke(name: string, ...: any): (boolean, any, any)
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild(name, 5)
	if not remote or not remote:IsA("RemoteFunction") then
		return false, "NotLoaded", nil
	end
	local args = table.pack(...)
	local ok, success, key, extra = pcall(function()
		return remote:InvokeServer(table.unpack(args, 1, args.n))
	end)
	if not ok then
		return false, "NotLoaded", nil
	end
	return success == true, key, extra
end

-- Купить продукт по ключу Config.Products; Id = 0 -> «не настроено»
function Rewards.promptProduct(key: string, toast: (string, string?) -> ())
	local product = Config.Products[key]
	if not product or product.Id == 0 then
		toast(Locale.T("NotConfigured"), "error")
		return
	end
	game:GetService("MarketplaceService"):PromptProductPurchase(player, product.Id)
end

return Rewards
