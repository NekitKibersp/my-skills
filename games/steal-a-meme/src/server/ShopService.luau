-- Покупки за Robux: геймпассы (проверка при входе и после покупки) и продукты (ProcessReceipt).
-- ID берутся из Config.GamePasses / Config.Products; с Id = 0 товар просто не работает.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local Remotes = require(script.Parent.Remotes)
local AnalyticsService = require(script.Parent.AnalyticsService)

local ShopService = {}

-- Колбэки из init.server
ShopService.OnSummonGod = nil :: (() -> ())?
-- Изменились геймпассы, от которых зависят предметы (золотой тапок, конфетти-пушка)
ShopService.OnToolsChanged = nil :: ((player: Player) -> ())?
-- Запустить Мем-дождь на сервере (продукт MemeRain): (player) -> boolean
ShopService.OnMemeRain = nil :: ((player: Player) -> boolean)?
-- Вращения колеса и уровни Мем-пропуска за Robux: (player, n) -> boolean (false — данные не загружены)
ShopService.OnSpins = nil :: ((player: Player, n: number) -> boolean)?
ShopService.OnPassLevels = nil :: ((player: Player, n: number) -> boolean)?
-- Мем-пропуск уже на максимуме: (player) -> boolean
ShopService.IsPassMaxed = nil :: ((player: Player) -> boolean)?

-- Сколько вращений колеса выдать вместо уровней пропуска, если он уже на максимуме
local PASS_MAXED_SPINS = 3
-- Куплен премиум Мем-пропуск
ShopService.OnBattlePass = nil :: ((player: Player) -> ())?

local function passKeyById(id: number): string?
	for key, pass in Config.GamePasses do
		if pass.Id ~= 0 and pass.Id == id then
			return key
		end
	end
	return nil
end

local function applyPass(player: Player, key: string)
	player:SetAttribute("Pass_" .. key, true)
	if not DataService.IsLoaded(player) then
		return
	end
	if key == "ExtraSlots" then
		PlotService.UpdateSlotsInfo(player)
	elseif key == "VIP" then
		PlotService.RefreshIncome(player)
	elseif (key == "GoldSlipper" or key == "ConfettiCannon") and ShopService.OnToolsChanged then
		ShopService.OnToolsChanged(player)
	elseif key == "BattlePass" and ShopService.OnBattlePass then
		ShopService.OnBattlePass(player)
	end
end

-- Проверить все геймпассы игрока (при входе, до загрузки базы)
function ShopService.CheckPasses(player: Player)
	for key, pass in Config.GamePasses do
		player:SetAttribute("Pass_" .. key, false)
		if pass.Id ~= 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.Id)
			end)
			if ok and owns then
				player:SetAttribute("Pass_" .. key, true)
			end
		end
	end
end

local function incomeCoins(player: Player, product: any): number
	return math.max(product.MinCoins or 0, math.floor(PlotService.IncomeOf(player) * (product.IncomeSeconds or 0)))
end

-- Мистери-бокс: случайный мем редкости из Config.MysteryBox. Нет места — монеты за полцены мема.
local function openMysteryBox(player: Player): boolean
	local box = Config.MysteryBox
	local total = 0
	for _, weight in box.Weights do
		total += weight
	end
	local roll = math.random() * total
	local rarity = box.Rarities[#box.Rarities]
	for i, weight in box.Weights do
		roll -= weight
		if roll <= 0 then
			rarity = box.Rarities[i]
			break
		end
	end
	local id = PlotService.RandomMeme(rarity)
	if not id then
		return false
	end
	if not PlotService.AddMeme(player, id, "None", false) then
		local coins = math.floor(Config.PriceOf(id, "None") * 0.5)
		PlotService.AddCoins(player, coins)
		Remotes.Notify:FireClient(player, "CashBought", { Coins = coins }, "success")
	end
	Remotes.Fx:FireAllClients("MysteryBox", { UserId = player.UserId, Meme = id })
	return true
end

-- Выдача продукта. Возвращает true, если выдано.
local function grantProduct(player: Player, key: string): boolean
	local product = Config.Products[key]
	if key == "ServerLuck" then
		local current = ReplicatedStorage:GetAttribute("LuckEndsAt") or 0
		local base = math.max(current, workspace:GetServerTimeNow())
		ReplicatedStorage:SetAttribute("LuckEndsAt", base + Config.ServerLuckDuration)
		Remotes.Notify:FireAllClients("ServerLuck", { Player = player.DisplayName }, "success")
		return true
	elseif key == "SummonGod" then
		if ShopService.OnSummonGod then
			ShopService.OnSummonGod()
		end
		Remotes.Notify:FireAllClients("GodSummoned", { Player = player.DisplayName }, "success")
		return true
	elseif key == "CashSmall" or key == "CashMedium" or key == "CashLarge" then
		local coins = incomeCoins(player, product)
		PlotService.AddCoins(player, coins)
		AnalyticsService.Economy(player, "Source", coins, "IAP", key)
		Remotes.Notify:FireClient(player, "CashBought", { Coins = coins }, "success")
		return true
	elseif key == "LockExtend" then
		if PlotService.Lock(player, Config.Plot.LockDuration, true) then
			Remotes.Notify:FireClient(player, "LockExtended", nil, "success")
			return true
		end
		return false
	elseif key == "MysteryBox" then
		return openMysteryBox(player)
	elseif key == "Spins3" or key == "Spins10" then
		return ShopService.OnSpins ~= nil and ShopService.OnSpins(player, product.Spins)
	elseif key == "PassLevels" then
		-- Пропуск уже на последнем уровне: уровни сгорели бы — даём вращения колеса
		if ShopService.IsPassMaxed and ShopService.IsPassMaxed(player) then
			if ShopService.OnSpins ~= nil and ShopService.OnSpins(player, PASS_MAXED_SPINS) then
				Remotes.Notify:FireClient(player, "PassMaxedSpins", { Count = PASS_MAXED_SPINS }, "success")
				return true
			end
			return false
		end
		return ShopService.OnPassLevels ~= nil and ShopService.OnPassLevels(player, product.Levels)
	elseif key == "MemeRain" then
		return ShopService.OnMemeRain ~= nil and ShopService.OnMemeRain(player)
	end
	return false
end

-- Чеки, которые выдаются прямо сейчас: выдача может ждать (загрузка модели Мем-Бога),
-- а повторный вызов ProcessReceipt с тем же PurchaseId не должен выдать товар второй раз
local inFlight: { [string]: boolean } = {}

local function processReceipt(receipt): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player or not DataService.IsLoaded(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseId = tostring(receipt.PurchaseId)
	if DataService.HasReceipt(player, purchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	if inFlight[purchaseId] then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local key: string? = nil
	for productKey, product in Config.Products do
		if product.Id ~= 0 and product.Id == receipt.ProductId then
			key = productKey
		end
	end
	if not key then
		warn("[ShopService] Неизвестный продукт", receipt.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	inFlight[purchaseId] = true
	local ok, granted = pcall(grantProduct, player, key)
	inFlight[purchaseId] = nil
	if not ok or not granted then
		warn("[ShopService] Не удалось выдать", key, granted)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if not DataService.IsLoaded(player) then
		-- Игрок вышел, пока шла выдача (ждёт только призыв Мем-Бога — он уже на дорожке):
		-- чек записать некуда, но повторять покупку нельзя
		warn("[ShopService] Выдано, игрок уже вышел", purchaseId)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	DataService.AddReceipt(player, purchaseId)
	AnalyticsService.Custom(player, "RobuxPurchase", 1, key)
	-- Сохраняем сразу, чтобы чек не потерялся при падении сервера
	if not DataService.Save(player) then
		warn("[ShopService] Покупка выдана, но не сохранена", player.Name, purchaseId)
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function ShopService.Start()
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		local key = passKeyById(passId)
		if key then
			applyPass(player, key)
			Remotes.Notify:FireClient(player, "PassBought", nil, "success")
		end
	end)
end

return ShopService
