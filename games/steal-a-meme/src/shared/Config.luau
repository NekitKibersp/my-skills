-- Все игровые числа в одном месте: мемы, цены, доход, тайминги, монетизация.
-- Модуль общий: клиент рисует по нему Индекс и магазин, сервер по нему проверяет покупки.
local Config = {}

Config.StartCoins = 100
Config.StarterMeme = "ClapCat" -- бесплатный мем, который стоит на базе у новичка

-- Редкости по возрастанию. Weight — относительный шанс появления на дорожке.
Config.Rarities = {
	{ Id = "Common", Name = "Common", NameRu = "Обычный", Color = Color3.fromRGB(200, 205, 215), Weight = 60 },
	{ Id = "Rare", Name = "Rare", NameRu = "Редкий", Color = Color3.fromRGB(70, 160, 255), Weight = 25 },
	{ Id = "Epic", Name = "Epic", NameRu = "Эпический", Color = Color3.fromRGB(170, 90, 255), Weight = 10 },
	{ Id = "Legendary", Name = "Legendary", NameRu = "Легендарный", Color = Color3.fromRGB(255, 200, 40), Weight = 3.5 },
	{ Id = "Mythic", Name = "Mythic", NameRu = "Мифический", Color = Color3.fromRGB(255, 60, 80), Weight = 1.2 },
	{ Id = "God", Name = "Meme God", NameRu = "Мем-Бог", Color = Color3.fromRGB(255, 120, 230), Weight = 0.25 },
	{ Id = "Secret", Name = "SECRET", NameRu = "СЕКРЕТНЫЙ", Color = Color3.fromRGB(30, 30, 30), Weight = 0.05 },
	{ Id = "Halloween", Name = "Halloween", NameRu = "Хэллоуин", Color = Color3.fromRGB(255, 130, 20), Weight = 0 },
	{ Id = "Winter", Name = "Winter", NameRu = "Зимний", Color = Color3.fromRGB(120, 210, 255), Weight = 0 },
}

-- Мемы. Face — эмодзи-«лицо», Shape — форма тела (Ball/Block/Cylinder), Size — масштаб.
-- Event = true — сезонные: появляются только ночью и только в своём сезоне (Season),
-- EventWeight — шанс среди сезонных. Купленные сезонные мемы остаются у игроков навсегда.
-- ModelId — ID модели из Creator Store (0 = собрать из примитивов). Модель должна лежать
-- в инвентаре владельца игры; скрипты из неё вырезаются при загрузке.
-- Чтобы заменить или удалить персонажа (например, по жалобе правообладателя), правьте только этот список.
Config.Creatures = {
	{ Id = "ClapCat", Name = "Black Cat Clapping", Face = "👏🐈‍⬛", Rarity = "Common", Price = 25, Income = 1, Color = Color3.fromRGB(30, 30, 35), Shape = "Ball", Size = 1, ModelId = 0 },
	{ Id = "Pups", Name = "Sleepy Baby", Face = "😴", Rarity = "Common", Price = 60, Income = 2, Color = Color3.fromRGB(255, 205, 180), Shape = "Ball", Size = 0.9, ModelId = 0 },
	{ Id = "Kolobok", Name = "Kolobok", Face = "😏", Rarity = "Common", Price = 130, Income = 4, Color = Color3.fromRGB(240, 190, 60), Shape = "Ball", Size = 0.8, ModelId = 0 },
	{ Id = "Brdysh", Name = "Brdysh", Face = "🐟🐶", Rarity = "Common", Price = 250, Income = 7, Color = Color3.fromRGB(120, 170, 190), Shape = "Cylinder", Size = 1, ModelId = 0 },

	{ Id = "SixSeven", Name = "Six Seven", Face = "6️⃣7️⃣", Rarity = "Rare", Price = 500, Income = 12, Color = Color3.fromRGB(80, 200, 255), Shape = "Block", Size = 1.1, ModelId = 0 },
	{ Id = "Cheremsha", Name = "Cheremsha", Face = "🦁🐰", Rarity = "Rare", Price = 1300, Income = 26, Color = Color3.fromRGB(230, 170, 90), Shape = "Ball", Size = 1.15, ModelId = 0 },
	{ Id = "Semga", Name = "Semga", Face = "🐟😐", Rarity = "Rare", Price = 2500, Income = 45, Color = Color3.fromRGB(250, 130, 110), Shape = "Cylinder", Size = 1.2, ModelId = 0 },

	{ Id = "Tralalero", Name = "Tralalero Tralala", Face = "🦈👟", Rarity = "Epic", Price = 5000, Income = 80, Color = Color3.fromRGB(90, 140, 220), Shape = "Cylinder", Size = 1.25, ModelId = 0 },
	{ Id = "TungSahur", Name = "Tung Tung Tung Sahur", Face = "🪵🏏", Rarity = "Epic", Price = 13000, Income = 175, Color = Color3.fromRGB(170, 120, 70), Shape = "Cylinder", Size = 1.35, ModelId = 0 },
	{ Id = "SwordKitten", Name = "Kitten with a Sword", Face = "🐱⚔️", Rarity = "Epic", Price = 22000, Income = 280, Color = Color3.fromRGB(190, 190, 205), Shape = "Ball", Size = 1, ModelId = 0 },

	{ Id = "BossCapybara", Name = "Boss Capybara", Face = "😎", Rarity = "Legendary", Price = 50000, Income = 550, Color = Color3.fromRGB(160, 110, 70), Shape = "Block", Size = 1.4, ModelId = 0 },
	{ Id = "Bombardiro", Name = "Bombardiro Crocodilo", Face = "🐊✈️", Rarity = "Legendary", Price = 90000, Income = 900, Color = Color3.fromRGB(70, 130, 60), Shape = "Cylinder", Size = 1.5, ModelId = 0 },
	{ Id = "Ballerina", Name = "Ballerina Cappuccina", Face = "☕🩰", Rarity = "Legendary", Price = 150000, Income = 1400, Color = Color3.fromRGB(255, 170, 210), Shape = "Cylinder", Size = 1.3, ModelId = 0 },

	{ Id = "Verity", Name = "Verity", Face = "🙂", Rarity = "Mythic", Price = 400000, Income = 3500, Color = Color3.fromRGB(255, 220, 30), Shape = "Block", Size = 1.6, ModelId = 0 },
	{ Id = "DjCat", Name = "DJ Cat", Face = "😼🎧", Rarity = "Mythic", Price = 1200000, Income = 9000, Color = Color3.fromRGB(120, 60, 200), Shape = "Ball", Size = 1.7, ModelId = 0 },

	{ Id = "MegaSixSeven", Name = "MEGA 67", Face = "6️⃣7️⃣🔥", Rarity = "God", Price = 6700000, Income = 40000, Color = Color3.fromRGB(255, 80, 200), Shape = "Block", Size = 2.1, ModelId = 0 },

	{ Id = "GreatCheremsha", Name = "The Great Cheremsha", Face = "🦁🐰👑", Rarity = "Secret", Price = 30000000, Income = 150000, Color = Color3.fromRGB(15, 15, 15), Shape = "Ball", Size = 2.4, ModelId = 0 },

	{ Id = "PumpkinCat", Name = "Pumpkin Cat", Face = "🎃🐈‍⬛", Rarity = "Halloween", Price = 2500, Income = 60, Color = Color3.fromRGB(255, 120, 20), Shape = "Ball", Size = 1.1, Event = true, Season = "Halloween", EventWeight = 60, ModelId = 0 },
	{ Id = "SkeletonClap", Name = "Clapping Skeleton", Face = "💀👏", Rarity = "Halloween", Price = 25000, Income = 400, Color = Color3.fromRGB(235, 235, 225), Shape = "Block", Size = 1.3, Event = true, Season = "Halloween", EventWeight = 28, ModelId = 0 },
	{ Id = "WitchSixSeven", Name = "Witch 67", Face = "🧙‍♀️6️⃣7️⃣", Rarity = "Halloween", Price = 250000, Income = 2800, Color = Color3.fromRGB(90, 30, 120), Shape = "Cylinder", Size = 1.6, Event = true, Season = "Halloween", EventWeight = 10, ModelId = 0 },
	{ Id = "GhostCheremsha", Name = "Ghost Cheremsha", Face = "👻🦁", Rarity = "Halloween", Price = 2000000, Income = 18000, Color = Color3.fromRGB(200, 230, 255), Shape = "Ball", Size = 1.9, Event = true, Season = "Halloween", EventWeight = 2, ModelId = 0 },
	{ Id = "SnowCat", Name = "Snow Cat Clapping", Face = "❄️🐈‍⬛", Rarity = "Winter", Price = 2500, Income = 60, Color = Color3.fromRGB(230, 245, 255), Shape = "Ball", Size = 1.1, Event = true, Season = "Winter", EventWeight = 60, ModelId = 0 },
	{ Id = "GingerSahur", Name = "Gingerbread Sahur", Face = "🍪🏏", Rarity = "Winter", Price = 25000, Income = 400, Color = Color3.fromRGB(180, 110, 60), Shape = "Cylinder", Size = 1.3, Event = true, Season = "Winter", EventWeight = 28, ModelId = 0 },
	{ Id = "SantaSixSeven", Name = "Santa 67", Face = "🎅6️⃣7️⃣", Rarity = "Winter", Price = 250000, Income = 2800, Color = Color3.fromRGB(220, 40, 50), Shape = "Block", Size = 1.6, Event = true, Season = "Winter", EventWeight = 10, ModelId = 0 },
	{ Id = "FrostVerity", Name = "Frost Verity", Face = "🥶", Rarity = "Winter", Price = 2000000, Income = 18000, Color = Color3.fromRGB(140, 210, 255), Shape = "Block", Size = 1.9, Event = true, Season = "Winter", EventWeight = 2, ModelId = 0 },
}

-- Мутации умножают доход и цену. Event = true — только ночью и только в своём сезоне (Season).
Config.Mutations = {
	{ Id = "None", Name = "", NameRu = "", Mult = 1, Weight = 88 },
	{ Id = "Gold", Name = "Gold", NameRu = "Золотой", Mult = 1.5, Weight = 10, Color = Color3.fromRGB(255, 210, 60) },
	{ Id = "Diamond", Name = "Diamond", NameRu = "Алмазный", Mult = 3, Weight = 2, Color = Color3.fromRGB(120, 230, 255) },
	{ Id = "Pumpkin", Name = "Pumpkin", NameRu = "Тыквенный", Mult = 2, Weight = 15, Color = Color3.fromRGB(255, 120, 20), Event = true, Season = "Halloween" },
	{ Id = "Ghost", Name = "Ghost", NameRu = "Призрачный", Mult = 4, Weight = 5, Color = Color3.fromRGB(190, 255, 240), Event = true, Season = "Halloween" },
	{ Id = "Frozen", Name = "Frozen", NameRu = "Ледяной", Mult = 2, Weight = 15, Color = Color3.fromRGB(150, 220, 255), Event = true, Season = "Winter" },
	{ Id = "Festive", Name = "Festive", NameRu = "Новогодний", Mult = 4, Weight = 5, Color = Color3.fromRGB(255, 70, 90), Event = true, Season = "Winter" },
}

-- Дорожка с мемами
Config.Conveyor = {
	SpawnInterval = 2.2, -- секунд между мемами
	Speed = 7, -- studs/сек
	EventChance = 0.4, -- доля сезонных мемов Ночью Смайлика
	MaxOnCarpet = 30,
	LuckMult = 2, -- во сколько раз растут шансы Легендарных и выше при «Удаче сервера»
}

-- База игрока
Config.Plot = {
	BaseSlots = 10,
	SlotsPerRebirth = 2,
	MaxSlots = 20, -- без геймпасса
	PassSlots = 5, -- геймпасс «+5 слотов» (итого до 25)
	LockDuration = 60,
	LockCooldown = 30, -- после открытия нельзя сразу закрыть снова
}

-- Кража
Config.Steal = {
	HoldDuration = 1.6, -- сколько держать «Украсть»
	FastHoldDuration = 0.8, -- с геймпассом «Быстрая кража»
	CarryWalkSpeed = 11,
	CarryTimeout = 45, -- не донёс за это время — мем возвращается
	SellRefund = 0.5, -- продажа своего мема возвращает 50% цены
}

-- Тапок: выбивает украденного мема и отбрасывает
Config.Slap = {
	Range = 9,
	Cooldown = 0.9,
	Knockback = 70,
	GoldRange = 13, -- с геймпассом «Золотой тапок»
	GoldKnockback = 110,
}

-- «В ТРЕНДЕ»: раз в Interval секунд один вид мема получает ×Mult к доходу
Config.Trend = {
	Interval = 10 * 60,
	Mult = 3,
}

-- Вирусность: Count одинаковых мемов (тот же вид и мутация) сливаются в один ×Mult
Config.Viral = {
	Count = 3,
	Mult = 5,
}

-- Страж базы — Котёнок с мечом. Бьёт воров, которые несут мемов с его базы.
-- Уровни: цена, радиус (studs), перезарядка удара (сек).
Config.Guard = {
	{ Price = 5000, Range = 16, Cooldown = 8 },
	{ Price = 40000, Range = 19, Cooldown = 7 },
	{ Price = 300000, Range = 22, Cooldown = 6 },
	{ Price = 2500000, Range = 25, Cooldown = 5 },
	{ Price = 20000000, Range = 28, Cooldown = 4 },
}

-- Ночь Смайлика (сезонный ивент)
Config.Night = {
	Interval = 6 * 60, -- между ночами
	Duration = 100,
	MonsterSpeed = 12,
	MonsterHpPerPlayer = 12, -- ударов тапком на каждого игрока на сервере
	MonsterStealPause = 3, -- секунд «ворует» на базе, прежде чем унести
	RewardRarities = { "Epic", "Legendary", "Mythic" }, -- лучший по ударам получает мема одной из этих редкостей
	RewardWeights = { 70, 25, 5 },
}

-- Перерождение: цена ×4 каждый раз, +50% к доходу и +2 слота
Config.Rebirth = {
	BaseCost = 500000,
	CostMult = 4,
	IncomeBonus = 0.5,
}

-- Оффлайн-доход
Config.Offline = {
	Rate = 0.25,
	MaxSeconds = 3 * 3600,
	PassRate = 1, -- геймпасс «Оффлайн+»
	PassMaxSeconds = 12 * 3600,
}

-- Индекс: каждый открытый вид (с учётом мутации) даёт +1% к доходу
Config.IndexBonusPerEntry = 0.01

-- Подарки за время в сессии: минута -> сколько секунд дохода выдать (минимум MinCoins)
Config.PlaytimeGifts = {
	{ Minutes = 5, IncomeSeconds = 60, MinCoins = 150 },
	{ Minutes = 15, IncomeSeconds = 180, MinCoins = 500 },
	{ Minutes = 30, IncomeSeconds = 400, MinCoins = 1500 },
	{ Minutes = 60, IncomeSeconds = 900, MinCoins = 5000 },
}

-- Ежедневная награда: день стрика (1..7, потом по кругу) -> секунд дохода (минимум MinCoins * день)
Config.Daily = {
	IncomeSeconds = 120,
	MinCoins = 200,
	MaxDay = 7,
}

-- Монетизация. Id = 0 — ещё не создано: создайте геймпасс/продукт в Creator Hub
-- и впишите сюда его ID. Цены (Robux) здесь только для витрины — настоящая цена задаётся в Creator Hub.
Config.GamePasses = {
	VIP = { Id = 0, Robux = 249, Name = "VIP: x2 Cash", NameRu = "VIP: ×2 денег" },
	ExtraSlots = { Id = 0, Robux = 199, Name = "+5 Base Slots", NameRu = "+5 слотов на базе" },
	FastSteal = { Id = 0, Robux = 149, Name = "Fast Steal", NameRu = "Быстрая кража" },
	GoldSlipper = { Id = 0, Robux = 99, Name = "Golden Slipper", NameRu = "Золотой тапок" },
	OfflinePlus = { Id = 0, Robux = 199, Name = "Offline+ (100%, 12h)", NameRu = "Оффлайн+ (100%, 12ч)" },
}
Config.VipIncomeMult = 2

Config.Products = {
	ServerLuck = { Id = 0, Robux = 49, Name = "Server Luck x2 (15 min)", NameRu = "Удача сервера ×2 (15 мин)" },
	SummonGod = { Id = 0, Robux = 399, Name = "Summon a Meme God", NameRu = "Призвать Мем-Бога" },
	CashSmall = { Id = 0, Robux = 25, Name = "Cash Pack S", NameRu = "Пачка денег S", IncomeSeconds = 300, MinCoins = 1000 },
	CashMedium = { Id = 0, Robux = 99, Name = "Cash Pack M", NameRu = "Пачка денег M", IncomeSeconds = 1500, MinCoins = 6000 },
	CashLarge = { Id = 0, Robux = 299, Name = "Cash Pack L", NameRu = "Пачка денег L", IncomeSeconds = 6000, MinCoins = 30000 },
	LockExtend = { Id = 0, Robux = 19, Name = "Lock +60s", NameRu = "Замок +60 сек" },
}
Config.ServerLuckDuration = 15 * 60

-- Сезоны: определяются по дате на сервере (месяц/день включительно, может переходить через Новый год).
-- От сезона зависят ночные мемы и мутации, декор карты и цвет монстра. Override = "Winter" — включить вручную.
Config.SeasonOverride = nil :: string?
Config.Seasons = {
	{ Id = "Halloween", From = { 10, 1 }, To = { 11, 5 }, MonsterColor = Color3.fromRGB(255, 220, 30) },
	{ Id = "Winter", From = { 11, 6 }, To = { 2, 28 }, MonsterColor = Color3.fromRGB(150, 220, 255) },
}

-- Сезон для даты (month 1..12, day 1..31); "None" — вне сезонов (ночные мемы не появляются)
function Config.SeasonFor(month: number, day: number): string
	if Config.SeasonOverride then
		return Config.SeasonOverride
	end
	local value = month * 100 + day
	for _, season in Config.Seasons do
		local from = season.From[1] * 100 + season.From[2]
		local to = season.To[1] * 100 + season.To[2]
		local inside = if from <= to then value >= from and value <= to else value >= from or value <= to
		if inside then
			return season.Id
		end
	end
	return "None"
end

-- Предметы: оружие (бьёт игроков и монстра) и гаджеты. Покупаются за монеты навсегда.
-- Weapon: Range — дальность, Cooldown — перезарядка, Knockback — сила отброса, Stun — сколько
-- секунд жертва лежит, Area = true — бьёт всех вокруг, а не одного.
-- Gadget: Duration — сколько действует, Cooldown — перезарядка.
Config.Items = {
	{ Id = "Slipper", Kind = "Weapon", Name = "Slipper", NameRu = "Тапок", Face = "🩴", Price = 0,
		Desc = "Slap thieves to make them drop memes", DescRu = "Выбивает украденных мемов",
		Range = 9, Cooldown = 0.9, Knockback = 70, Stun = 0.6 },
	{ Id = "Bat", Kind = "Weapon", Name = "Tung Tung Bat", NameRu = "Бита Tung Tung", Face = "🏏", Price = 25000,
		Desc = "Huge knockback, slower swing", DescRu = "Отбрасывает дальше, бьёт медленнее",
		Range = 10, Cooldown = 1.6, Knockback = 135, Stun = 1 },
	{ Id = "Pan", Kind = "Weapon", Name = "Frying Pan", NameRu = "Сковородка", Face = "🍳", Price = 120000,
		Desc = "Stuns the target for 2.5s", DescRu = "Оглушает цель на 2,5 сек",
		Range = 9, Cooldown = 1.4, Knockback = 50, Stun = 2.5 },
	{ Id = "BanHammer", Kind = "Weapon", Name = "Ban Hammer", NameRu = "Бан-молот", Face = "🔨", Price = 2500000,
		Desc = "Hits everyone around you", DescRu = "Бьёт всех вокруг",
		Range = 14, Cooldown = 2.4, Knockback = 150, Stun = 1.5, Area = true },
	{ Id = "Energy", Kind = "Gadget", Name = "Energy Drink", NameRu = "Энергетик", Face = "🥤", Price = 8000,
		Desc = "+12 speed for 6s", DescRu = "+12 к скорости на 6 сек",
		Duration = 6, Cooldown = 25, Speed = 12 },
	{ Id = "Banana", Kind = "Gadget", Name = "Banana Peel", NameRu = "Банановая кожура", Face = "🍌", Price = 50000,
		Desc = "Drop a trap: enemies slip and drop memes", DescRu = "Ловушка: враги падают и роняют мемов",
		Duration = 60, Cooldown = 12, Stun = 2, MaxActive = 3 },
	{ Id = "InvisHat", Kind = "Gadget", Name = "Invisibility Hat", NameRu = "Шапка-невидимка", Face = "🎩", Price = 400000,
		Desc = "Invisible for 8s (ends when you steal)", DescRu = "Невидимость на 8 сек (пропадает при краже)",
		Duration = 8, Cooldown = 45 },
}

local itemById = {}
for _, item in Config.Items do
	itemById[item.Id] = item
end

function Config.GetItem(id: string)
	return itemById[id]
end

-- ===== Функции-помощники (общие для сервера и клиента) =====

local creatureById = {}
for _, creature in Config.Creatures do
	creatureById[creature.Id] = creature
end

function Config.GetCreature(id: string)
	return creatureById[id]
end

function Config.GetRarity(id: string)
	for _, rarity in Config.Rarities do
		if rarity.Id == id then
			return rarity
		end
	end
	return Config.Rarities[1]
end

function Config.GetMutation(id: string?)
	for _, mutation in Config.Mutations do
		if mutation.Id == id then
			return mutation
		end
	end
	return Config.Mutations[1]
end

-- Ключ записи Индекса: вид + мутация
function Config.IndexKey(id: string, mutationId: string?): string
	return id .. "|" .. (mutationId or "None")
end

-- Базовый доход мема (без тренда, перерождений, VIP и Индекса)
function Config.BaseIncome(id: string, mutationId: string?, viral: boolean?): number
	local creature = creatureById[id]
	if not creature then
		return 0
	end
	return creature.Income * Config.GetMutation(mutationId).Mult * (if viral then Config.Viral.Mult else 1)
end

function Config.PriceOf(id: string, mutationId: string?): number
	local creature = creatureById[id]
	if not creature then
		return 0
	end
	return math.floor(creature.Price * Config.GetMutation(mutationId).Mult)
end

function Config.MaxSlots(rebirths: number, hasExtraSlotsPass: boolean?): number
	local base = math.min(Config.Plot.BaseSlots + rebirths * Config.Plot.SlotsPerRebirth, Config.Plot.MaxSlots)
	return base + (if hasExtraSlotsPass then Config.Plot.PassSlots else 0)
end

Config.AbsoluteMaxSlots = Config.Plot.MaxSlots + Config.Plot.PassSlots

function Config.RebirthCost(rebirths: number): number
	return Config.Rebirth.BaseCost * Config.Rebirth.CostMult ^ rebirths
end

function Config.IncomeMult(rebirths: number): number
	return 1 + rebirths * Config.Rebirth.IncomeBonus
end

return Config
