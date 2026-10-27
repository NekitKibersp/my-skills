---
name: roblox-monetization
description: "Roblox monetization in Luau: game passes (UserOwnsGamePassAsync with caching, in-game purchase handling) and developer products (an idempotent MarketplaceService.ProcessReceipt that never loses or double-grants a purchase). Use when adding Robux purchases, VIP passes, x2 boosts, currency packs or stage skips to a Roblox game (\"геймпасс\", \"донат\", \"покупка за робуксы\")."
user-invocable: true
---

# Монетизация: геймпассы и Developer Products

ID геймпассов и продуктов создаёт владелец игры (Creator Dashboard → игра → Monetization).
Никогда не выдумывай ID — вынеси их в `Config` с пометкой «вставьте свой ID».

## Геймпасс (покупается один раз)

```lua
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Config = require(game.ReplicatedStorage.Shared.Config) -- Config.GamePasses.DoubleCoins = 0 -- вставьте ID

local owned: { [Player]: { [number]: boolean } } = {}

local function ownsPass(player: Player, passId: number): boolean
	local cache = owned[player]
	if cache and cache[passId] ~= nil then
		return cache[passId]
	end
	local ok, result = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, passId)
	local has = ok and result or false
	if ok then
		owned[player] = owned[player] or {}
		owned[player][passId] = has
	end
	return has
end

-- Покупка прямо в игре: кэш обновляем сразу, без перезахода.
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if purchased then
		owned[player] = owned[player] or {}
		owned[player][passId] = true
		-- применить бонус немедленно (выдать предмет, обновить множитель)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	owned[player] = nil
end)
```

Открыть покупку с клиента: `MarketplaceService:PromptGamePassPurchase(player, passId)`.
Применять бонус всегда на сервере (`if ownsPass(player, id) then reward *= 2 end`).

## Developer Product (покупается много раз: валюта, скип этапа)

`ProcessReceipt` — **один** на всю игру, задаётся только на сервере. Roblox повторяет вызов,
пока не получит `PurchaseGranted`, поэтому обработка должна быть идемпотентной.

```lua
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local purchaseHistory = DataStoreService:GetDataStore("PurchaseHistory")

local handlers: { [number]: (Player) -> () } = {
	-- [Config.Products.Coins1000] = function(player) DataService.Increment(player, "Coins", 1000) end,
}

MarketplaceService.ProcessReceipt = function(receipt)
	local key = receipt.PlayerId .. "_" .. receipt.PurchaseId

	local okRead, alreadyGranted = pcall(purchaseHistory.GetAsync, purchaseHistory, key)
	if not okRead then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if alreadyGranted then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local handler = handlers[receipt.ProductId]
	if not player or not handler then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- выдадим при следующем входе
	end

	local okGrant = pcall(handler, player)
	if not okGrant then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- Сразу сохранить данные игрока, затем отметить покупку.
	-- DataService.Save(player)
	local okWrite = pcall(purchaseHistory.SetAsync, purchaseHistory, key, true)
	if not okWrite then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end
```

Открыть покупку с клиента: `MarketplaceService:PromptProductPurchase(player, productId)`.

## Правила
- Не возвращай `PurchaseGranted`, если выдача или сохранение не удались.
- Не продавай случайные награды (лутбоксы) за Robux без раскрытия шансов — это требование Roblox.
- Цены в Robux показывай через `MarketplaceService:GetProductInfo(id, Enum.InfoType.Product).PriceInRobux` (в `pcall`).
- В Studio покупки тестовые, Robux не списываются.
