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
	{ Id = "Limited", Name = "LIMITED", NameRu = "ЛИМИТ", Color = Color3.fromRGB(0, 255, 170), Weight = 0 },
	{ Id = "Exclusive", Name = "EXCLUSIVE", NameRu = "ЭКСКЛЮЗИВ", Color = Color3.fromRGB(255, 215, 0), Weight = 0 },
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
	{ Id = "Doge", Name = "Doge", Face = "🐕", Rarity = "Common", Price = 90, Income = 3, Color = Color3.fromRGB(225, 180, 110), Shape = "Ball", Size = 0.95, ModelId = 0 },
	{ Id = "Kolobok", Name = "Kolobok", Face = "😏", Rarity = "Common", Price = 130, Income = 4, Color = Color3.fromRGB(240, 190, 60), Shape = "Ball", Size = 0.8, ModelId = 0 },
	{ Id = "Lirili", Name = "Lirili Larila", Face = "🌵🐘", Rarity = "Common", Price = 180, Income = 5, Color = Color3.fromRGB(110, 170, 90), Shape = "Cylinder", Size = 1, ModelId = 0 },
	{ Id = "Brdysh", Name = "Brdysh", Face = "🐟🐶", Rarity = "Common", Price = 250, Income = 7, Color = Color3.fromRGB(120, 170, 190), Shape = "Cylinder", Size = 1, ModelId = 0 },
	{ Id = "Bobritto", Name = "Bobritto Bandito", Face = "🦫🎩", Rarity = "Common", Price = 350, Income = 9, Color = Color3.fromRGB(130, 90, 60), Shape = "Ball", Size = 1, ModelId = 0 },

	{ Id = "SixSeven", Name = "Six Seven", Face = "6️⃣7️⃣", Rarity = "Rare", Price = 500, Income = 12, Color = Color3.fromRGB(80, 200, 255), Shape = "Block", Size = 1.1, ModelId = 0 },
	{ Id = "Chimpanzini", Name = "Chimpanzini Bananini", Face = "🐒🍌", Rarity = "Rare", Price = 800, Income = 18, Color = Color3.fromRGB(240, 220, 80), Shape = "Cylinder", Size = 1.1, ModelId = 0 },
	{ Id = "Cheremsha", Name = "Cheremsha", Face = "🦁🐰", Rarity = "Rare", Price = 1300, Income = 26, Color = Color3.fromRGB(230, 170, 90), Shape = "Ball", Size = 1.15, ModelId = 0 },
	{ Id = "SadHamster", Name = "Sad Hamster", Face = "🐹🎻", Rarity = "Rare", Price = 1800, Income = 34, Color = Color3.fromRGB(230, 190, 140), Shape = "Ball", Size = 0.95, ModelId = 0 },
	{ Id = "Semga", Name = "Semga", Face = "🐟😐", Rarity = "Rare", Price = 2500, Income = 45, Color = Color3.fromRGB(250, 130, 110), Shape = "Cylinder", Size = 1.2, ModelId = 0 },
	{ Id = "TrippiTroppi", Name = "Trippi Troppi", Face = "🦐🐱", Rarity = "Rare", Price = 3500, Income = 60, Color = Color3.fromRGB(255, 150, 120), Shape = "Ball", Size = 1.15, ModelId = 0 },

	{ Id = "Tralalero", Name = "Tralalero Tralala", Face = "🦈👟", Rarity = "Epic", Price = 5000, Income = 80, Color = Color3.fromRGB(90, 140, 220), Shape = "Cylinder", Size = 1.25, ModelId = 0 },
	{ Id = "Patapim", Name = "Brr Brr Patapim", Face = "🌳🐒", Rarity = "Epic", Price = 8000, Income = 120, Color = Color3.fromRGB(90, 140, 70), Shape = "Cylinder", Size = 1.3, ModelId = 0 },
	{ Id = "TungSahur", Name = "Tung Tung Tung Sahur", Face = "🪵🏏", Rarity = "Epic", Price = 13000, Income = 175, Color = Color3.fromRGB(170, 120, 70), Shape = "Cylinder", Size = 1.35, ModelId = 0 },
	{ Id = "SwordKitten", Name = "Kitten with a Sword", Face = "🐱⚔️", Rarity = "Epic", Price = 22000, Income = 280, Color = Color3.fromRGB(190, 190, 205), Shape = "Ball", Size = 1, ModelId = 0 },
	{ Id = "Cappuccino", Name = "Cappuccino Assassino", Face = "☕🗡️", Rarity = "Epic", Price = 30000, Income = 370, Color = Color3.fromRGB(120, 80, 50), Shape = "Cylinder", Size = 1.2, ModelId = 0 },
	{ Id = "TimCheese", Name = "Tim Cheese", Face = "🐭🧀", Rarity = "Epic", Price = 38000, Income = 450, Color = Color3.fromRGB(255, 210, 80), Shape = "Ball", Size = 1.1, ModelId = 0 },

	{ Id = "BossCapybara", Name = "Boss Capybara", Face = "😎", Rarity = "Legendary", Price = 50000, Income = 550, Color = Color3.fromRGB(160, 110, 70), Shape = "Block", Size = 1.4, ModelId = 0 },
	{ Id = "ChillGuy", Name = "Chill Guy", Face = "🐶😌", Rarity = "Legendary", Price = 70000, Income = 730, Color = Color3.fromRGB(200, 170, 140), Shape = "Block", Size = 1.4, ModelId = 0 },
	{ Id = "Bombardiro", Name = "Bombardiro Crocodilo", Face = "🐊✈️", Rarity = "Legendary", Price = 90000, Income = 900, Color = Color3.fromRGB(70, 130, 60), Shape = "Cylinder", Size = 1.5, ModelId = 0 },
	{ Id = "Ballerina", Name = "Ballerina Cappuccina", Face = "☕🩰", Rarity = "Legendary", Price = 150000, Income = 1400, Color = Color3.fromRGB(255, 170, 210), Shape = "Cylinder", Size = 1.3, ModelId = 0 },
	{ Id = "FrigoCamelo", Name = "Frigo Camelo", Face = "🐫🧊", Rarity = "Legendary", Price = 220000, Income = 1950, Color = Color3.fromRGB(210, 230, 240), Shape = "Block", Size = 1.5, ModelId = 0 },

	{ Id = "Verity", Name = "Verity", Face = "🙂", Rarity = "Mythic", Price = 400000, Income = 3500, Color = Color3.fromRGB(255, 220, 30), Shape = "Block", Size = 1.6, ModelId = 0 },
	{ Id = "Odin", Name = "Odin Din Din Dun", Face = "🗿🔔", Rarity = "Mythic", Price = 650000, Income = 5300, Color = Color3.fromRGB(120, 120, 130), Shape = "Block", Size = 1.7, ModelId = 0 },
	{ Id = "DjCat", Name = "DJ Cat", Face = "😼🎧", Rarity = "Mythic", Price = 1200000, Income = 9000, Color = Color3.fromRGB(120, 60, 200), Shape = "Ball", Size = 1.7, ModelId = 0 },
	{ Id = "VaccaSaturno", Name = "La Vacca Saturno Saturnita", Face = "🐄🪐", Rarity = "Mythic", Price = 2000000, Income = 14000, Color = Color3.fromRGB(240, 240, 240), Shape = "Ball", Size = 1.8, ModelId = 0 },

	{ Id = "MegaSixSeven", Name = "MEGA 67", Face = "6️⃣7️⃣🔥", Rarity = "God", Price = 6700000, Income = 40000, Color = Color3.fromRGB(255, 80, 200), Shape = "Block", Size = 2.1, ModelId = 0 },
	{ Id = "Tralaleritos", Name = "Los Tralaleritos", Face = "🦈🦈🦈", Rarity = "God", Price = 12000000, Income = 65000, Color = Color3.fromRGB(90, 140, 230), Shape = "Cylinder", Size = 2.2, ModelId = 0 },
	{ Id = "Gigachad", Name = "Gigachad", Face = "🗿💪", Rarity = "God", Price = 20000000, Income = 100000, Color = Color3.fromRGB(90, 90, 100), Shape = "Block", Size = 2.3, ModelId = 0 },

	{ Id = "GreatCheremsha", Name = "The Great Cheremsha", Face = "🦁🐰👑", Rarity = "Secret", Price = 30000000, Income = 150000, Color = Color3.fromRGB(15, 15, 15), Shape = "Ball", Size = 2.4, ModelId = 0 },
	{ Id = "StrawberryElephant", Name = "Strawberry Elephant", Face = "🍓🐘", Rarity = "Secret", Price = 67000000, Income = 300000, Color = Color3.fromRGB(255, 80, 110), Shape = "Ball", Size = 2.5, ModelId = 0 },

	{ Id = "PumpkinCat", Name = "Pumpkin Cat", Face = "🎃🐈‍⬛", Rarity = "Halloween", Price = 2500, Income = 60, Color = Color3.fromRGB(255, 120, 20), Shape = "Ball", Size = 1.1, Event = true, Season = "Halloween", EventWeight = 60, ModelId = 0 },
	{ Id = "SkeletonClap", Name = "Clapping Skeleton", Face = "💀👏", Rarity = "Halloween", Price = 25000, Income = 400, Color = Color3.fromRGB(235, 235, 225), Shape = "Block", Size = 1.3, Event = true, Season = "Halloween", EventWeight = 28, ModelId = 0 },
	{ Id = "WitchSixSeven", Name = "Witch 67", Face = "🧙‍♀️6️⃣7️⃣", Rarity = "Halloween", Price = 250000, Income = 2800, Color = Color3.fromRGB(90, 30, 120), Shape = "Cylinder", Size = 1.6, Event = true, Season = "Halloween", EventWeight = 10, ModelId = 0 },
	{ Id = "GhostCheremsha", Name = "Ghost Cheremsha", Face = "👻🦁", Rarity = "Halloween", Price = 2000000, Income = 18000, Color = Color3.fromRGB(200, 230, 255), Shape = "Ball", Size = 1.9, Event = true, Season = "Halloween", EventWeight = 2, ModelId = 0 },
	{ Id = "SnowCat", Name = "Snow Cat Clapping", Face = "❄️🐈‍⬛", Rarity = "Winter", Price = 2500, Income = 60, Color = Color3.fromRGB(230, 245, 255), Shape = "Ball", Size = 1.1, Event = true, Season = "Winter", EventWeight = 60, ModelId = 0 },
	{ Id = "GingerSahur", Name = "Gingerbread Sahur", Face = "🍪🏏", Rarity = "Winter", Price = 25000, Income = 400, Color = Color3.fromRGB(180, 110, 60), Shape = "Cylinder", Size = 1.3, Event = true, Season = "Winter", EventWeight = 28, ModelId = 0 },
	{ Id = "SantaSixSeven", Name = "Santa 67", Face = "🎅6️⃣7️⃣", Rarity = "Winter", Price = 250000, Income = 2800, Color = Color3.fromRGB(220, 40, 50), Shape = "Block", Size = 1.6, Event = true, Season = "Winter", EventWeight = 10, ModelId = 0 },
	{ Id = "FrostVerity", Name = "Frost Verity", Face = "🥶", Rarity = "Winter", Price = 2000000, Income = 18000, Color = Color3.fromRGB(140, 210, 255), Shape = "Block", Size = 1.9, Event = true, Season = "Winter", EventWeight = 2, ModelId = 0 },
	-- Лимитированные мемы недели: на дорожке только свою неделю (Config.Weekly), потом пропадают навсегда
	{ Id = "AuraFarmer", Name = "Aura Farmer", Face = "🚣✨", Rarity = "Limited", Price = 180000, Income = 1700, Color = Color3.fromRGB(70, 120, 200), Shape = "Cylinder", Size = 1.4, Limited = true, ModelId = 0 },
	{ Id = "PedroRaccoon", Name = "Pedro Raccoon", Face = "🦝🎶", Rarity = "Limited", Price = 180000, Income = 1700, Color = Color3.fromRGB(120, 120, 130), Shape = "Ball", Size = 1.3, Limited = true, ModelId = 0 },
	{ Id = "MooDeng", Name = "Moo Deng", Face = "🦛💢", Rarity = "Limited", Price = 180000, Income = 1700, Color = Color3.fromRGB(150, 110, 130), Shape = "Ball", Size = 1.4, Limited = true, ModelId = 0 },
	{ Id = "MewingCat", Name = "Mewing Cat", Face = "😼🤫", Rarity = "Limited", Price = 180000, Income = 1700, Color = Color3.fromRGB(240, 200, 160), Shape = "Ball", Size = 1.2, Limited = true, ModelId = 0 },
	-- Эксклюзивы боевого пропуска и колеса (на дорожке не появляются)
	{ Id = "Golden67", Name = "Golden 67", Face = "🥇6️⃣7️⃣", Rarity = "Exclusive", Price = 900000, Income = 7000, Color = Color3.fromRGB(255, 205, 50), Shape = "Block", Size = 1.7, Exclusive = true, ModelId = 0 },
	{ Id = "DiamondSahur", Name = "Diamond Sahur", Face = "💎🏏", Rarity = "Exclusive", Price = 5000000, Income = 32000, Color = Color3.fromRGB(130, 230, 255), Shape = "Cylinder", Size = 2, Exclusive = true, ModelId = 0 },
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
	EmotePack = { Id = 0, Robux = 199, Name = "Meme Emote Pack", NameRu = "Пак мем-эмоций" },
	ConfettiCannon = { Id = 0, Robux = 349, Name = "Confetti Cannon", NameRu = "Конфетти-пушка" },
	BattlePass = { Id = 0, Robux = 399, Name = "Premium Meme Pass", NameRu = "Премиум Мем-пропуск" },
}
Config.VipIncomeMult = 2

Config.Products = {
	ServerLuck = { Id = 0, Robux = 49, Name = "Server Luck x2 (15 min)", NameRu = "Удача сервера ×2 (15 мин)" },
	SummonGod = { Id = 0, Robux = 399, Name = "Summon a Meme God", NameRu = "Призвать Мем-Бога" },
	CashSmall = { Id = 0, Robux = 25, Name = "Cash Pack S", NameRu = "Пачка денег S", IncomeSeconds = 300, MinCoins = 1000 },
	CashMedium = { Id = 0, Robux = 99, Name = "Cash Pack M", NameRu = "Пачка денег M", IncomeSeconds = 1500, MinCoins = 6000 },
	CashLarge = { Id = 0, Robux = 299, Name = "Cash Pack L", NameRu = "Пачка денег L", IncomeSeconds = 6000, MinCoins = 30000 },
	LockExtend = { Id = 0, Robux = 19, Name = "Lock +60s", NameRu = "Замок +60 сек" },
	MysteryBox = { Id = 0, Robux = 79, Name = "Mystery Meme Box", NameRu = "Мистери-бокс мемов" },
	MemeRain = { Id = 0, Robux = 299, Name = "Start Meme Rain (whole server)", NameRu = "Запустить Мем-дождь (весь сервер)" },
	Spins3 = { Id = 0, Robux = 49, Name = "3 Wheel Spins", NameRu = "3 вращения колеса", Spins = 3 },
	Spins10 = { Id = 0, Robux = 129, Name = "10 Wheel Spins", NameRu = "10 вращений колеса", Spins = 10 },
	PassLevels = { Id = 0, Robux = 99, Name = "Meme Pass +5 levels", NameRu = "Мем-пропуск +5 уровней", Levels = 5 },
}
-- Мистери-бокс: редкость случайного мема
Config.MysteryBox = {
	Rarities = { "Legendary", "Mythic", "God" },
	Weights = { 75, 22, 3 },
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

-- Предметы: оружие (бьёт игроков и монстра) и гаджеты. Покупаются за монеты навсегда;
-- предмет с Pass = "Key" не продаётся за монеты — он есть у владельцев геймпасса Config.GamePasses[Key].
-- Ranged = true — дальний бой: попадает в первого врага в конусе перед персонажем.
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
	{ Id = "RubberChicken", Kind = "Weapon", Name = "Rubber Chicken", NameRu = "Резиновая курица", Face = "🐔", Price = 8000,
		Desc = "Super fast, weak hits", DescRu = "Очень быстрые слабые удары",
		Range = 8, Cooldown = 0.45, Knockback = 45, Stun = 0.4 },
	{ Id = "Snowball", Kind = "Weapon", Name = "Snowball Launcher", NameRu = "Снежкомёт", Face = "☃️", Price = 600000,
		Desc = "Ranged: hits the first enemy in front of you", DescRu = "Дальний бой: попадает в первого врага впереди",
		Ranged = true, Range = 45, Cooldown = 2, Knockback = 60, Stun = 1.2 },
	{ Id = "ConfettiCannon", Kind = "Weapon", Name = "Confetti Cannon", NameRu = "Конфетти-пушка", Face = "🎉", Price = 0, Pass = "ConfettiCannon",
		Desc = "Ranged blast with huge knockback", DescRu = "Дальний залп с огромным отбросом",
		Ranged = true, Range = 55, Cooldown = 1.5, Knockback = 140, Stun = 1.5 },
	{ Id = "RocketBoots", Kind = "Gadget", Name = "Rocket Boots", NameRu = "Ракетные ботинки", Face = "🚀", Price = 90000,
		Desc = "Super jump forward", DescRu = "Суперпрыжок вперёд",
		Cooldown = 10, Jump = 110, Forward = 45 },
	{ Id = "FreezeBomb", Kind = "Gadget", Name = "Freeze Bomb", NameRu = "Ледяная бомба", Face = "🧊", Price = 300000,
		Desc = "Freezes enemies around you for 2s, they drop memes", DescRu = "Замораживает врагов рядом на 2 сек, они роняют мемов",
		Cooldown = 30, Range = 14, Stun = 2 },
}
local itemById = {}
for _, item in Config.Items do
	itemById[item.Id] = item
end

function Config.GetItem(id: string)
	return itemById[id]
end

-- ===== Ежедневная награда: календарь на 7 дней (стрик сбрасывается, если пропустить день) =====
-- Kind: "Coins" (IncomeSeconds секунд дохода, минимум MinCoins), "Meme" (случайный мем редкости Rarity),
-- "Item" (предмет ItemId; если уже есть — монеты Fallback).
Config.DailyCalendar = {
	{ Kind = "Coins", IncomeSeconds = 120, MinCoins = 300 },
	{ Kind = "Coins", IncomeSeconds = 300, MinCoins = 800 },
	{ Kind = "Meme", Rarity = "Rare" },
	{ Kind = "Coins", IncomeSeconds = 600, MinCoins = 2500 },
	{ Kind = "Meme", Rarity = "Epic" },
	{ Kind = "Item", ItemId = "Energy", Fallback = { IncomeSeconds = 900, MinCoins = 6000 } },
	{ Kind = "Meme", Rarity = "Legendary" },
}

-- ===== Ежедневные квесты: PerDay случайных из пула, сброс в полночь UTC =====
-- Stat — событие, которое двигает прогресс (см. Hooks на сервере):
--   Buy, Steal, Slap, MonsterHit, Merge, Lock, Earn (сумма денег), Play (секунды), Defend (выбил вора со своим мемом)
Config.Quests = {
	PerDay = 3,
	Pool = {
		{ Id = "Buy5", Stat = "Buy", Goal = 5, IncomeSeconds = 120, MinCoins = 300, Desc = "Buy {Goal} memes", DescRu = "Купи {Goal} мемов" },
		{ Id = "Buy15", Stat = "Buy", Goal = 15, IncomeSeconds = 400, MinCoins = 1500, Desc = "Buy {Goal} memes", DescRu = "Купи {Goal} мемов" },
		{ Id = "Steal1", Stat = "Steal", Goal = 1, IncomeSeconds = 180, MinCoins = 500, Desc = "Steal a meme", DescRu = "Укради мема" },
		{ Id = "Steal3", Stat = "Steal", Goal = 3, IncomeSeconds = 600, MinCoins = 2000, Desc = "Steal {Goal} memes", DescRu = "Укради {Goal} мемов" },
		{ Id = "Slap10", Stat = "Slap", Goal = 10, IncomeSeconds = 150, MinCoins = 400, Desc = "Hit players {Goal} times", DescRu = "Ударь игроков {Goal} раз" },
		{ Id = "Monster15", Stat = "MonsterHit", Goal = 15, IncomeSeconds = 300, MinCoins = 1000, Desc = "Hit the Smiley {Goal} times", DescRu = "Ударь Smiley {Goal} раз" },
		{ Id = "Merge1", Stat = "Merge", Goal = 1, IncomeSeconds = 400, MinCoins = 1500, Desc = "Make a VIRAL meme", DescRu = "Сделай ВИРУСНОГО мема" },
		{ Id = "Lock3", Stat = "Lock", Goal = 3, IncomeSeconds = 100, MinCoins = 300, Desc = "Lock your base {Goal} times", DescRu = "Закрой базу {Goal} раза" },
		{ Id = "Earn", Stat = "Earn", Goal = 0, GoalIncomeSeconds = 900, IncomeSeconds = 300, MinCoins = 800, Desc = "Earn {Goal} cash", DescRu = "Заработай {Goal}" },
		{ Id = "Play15", Stat = "Play", Goal = 900, IncomeSeconds = 200, MinCoins = 600, Desc = "Play for 15 minutes", DescRu = "Поиграй 15 минут" },
		{ Id = "Defend2", Stat = "Defend", Goal = 2, IncomeSeconds = 400, MinCoins = 1200, Desc = "Knock {Goal} thieves off your memes", DescRu = "Отбей своих мемов у воров {Goal} раза" },
	},
	-- Бонус за выполнение всех квестов дня
	AllDoneIncomeSeconds = 900,
	AllDoneMinCoins = 5000,
}

-- ===== Админ-ивенты по выходным =====
-- Идут на всех серверах одновременно по расписанию (UTC). Days — дни недели os.date wday (1 = вс, 7 = сб).
-- Admins — UserId, которые могут запускать ивенты командой в чате "/event <Id>" (создатель игры может всегда).
Config.AdminEvents = {
	Days = { 7, 1 },
	Hours = { 12, 15, 18, 21 },
	Duration = 10 * 60,
	Admins = {} :: { number },
	Types = {
		{ Id = "MemeRain", Name = "MEME RAIN", NameRu = "МЕМ-ДОЖДЬ", Face = "🌧️", SpawnMult = 4, LuckMult = 2,
			Desc = "Memes everywhere! x4 spawn, x2 luck", DescRu = "Мемы повсюду! ×4 появление, ×2 удача" },
		{ Id = "LuckyHour", Name = "LUCKY HOUR", NameRu = "ЧАС УДАЧИ", Face = "🍀", LuckMult = 4,
			Desc = "x4 chance of rare memes", DescRu = "×4 шанс редких мемов" },
		{ Id = "DoubleCash", Name = "DOUBLE CASH", NameRu = "ДВОЙНЫЕ ДЕНЬГИ", Face = "💸", IncomeMult = 2,
			Desc = "All memes earn x2", DescRu = "Все мемы приносят ×2" },
		{ Id = "MutationStorm", Name = "MUTATION STORM", NameRu = "ШТОРМ МУТАЦИЙ", Face = "🧬", MutationChance = 1,
			Desc = "Every meme is mutated", DescRu = "Каждый мем с мутацией" },
		{ Id = "SecretDrop", Name = "SECRET DROP", NameRu = "СЕКРЕТНЫЙ ДРОП", Face = "🤫", LuckMult = 2, SecretDrops = 3,
			Desc = "Secret memes on the carpet!", DescRu = "Секретные мемы на дорожке!" },
	},
	MemeRainDuration = 3 * 60, -- длительность Мем-дождя за Robux
}

-- ===== Защита базы (покупается за монеты, уровни навсегда) =====
-- Turret: стреляет в воров, которые несут мемов с этой базы, и в чужаков на базе.
-- LaserGate: лазер на входе — вор с твоим мемом, проходя через вход, падает и роняет мема.
Config.Defense = {
	Turret = {
		{ Price = 20000, Range = 30, Cooldown = 6, Stun = 1.2 },
		{ Price = 150000, Range = 36, Cooldown = 4.5, Stun = 1.5 },
		{ Price = 1200000, Range = 42, Cooldown = 3, Stun = 2 },
	},
	LaserGate = {
		{ Price = 60000, Cooldown = 20, Stun = 1 },
		{ Price = 400000, Cooldown = 14, Stun = 1.5 },
		{ Price = 3000000, Cooldown = 8, Stun = 2 },
	},
}

-- ===== Эмоции =====
-- Proc — процедурная анимация (клиент двигает руки/тело), Pass — нужен геймпасс.
Config.Emotes = {
	{ Id = "Wave", Name = "Wave", NameRu = "Привет", Face = "👋", Proc = "Wave" },
	{ Id = "Clap", Name = "Clap", NameRu = "Хлопать", Face = "👏", Proc = "Clap" },
	{ Id = "SixSeven", Name = "Six Seven", NameRu = "Six Seven", Face = "6️⃣7️⃣", Proc = "SixSeven" },
	{ Id = "Spin", Name = "Spin", NameRu = "Крутиться", Face = "🌀", Proc = "Spin" },
	{ Id = "Gigachad", Name = "Gigachad", NameRu = "Gigachad", Face = "🗿", Proc = "Flex", Pass = "EmotePack" },
	{ Id = "Floss", Name = "Floss", NameRu = "Флосс", Face = "🕺", Proc = "Floss", Pass = "EmotePack" },
	{ Id = "Dab", Name = "Dab", NameRu = "Дэб", Face = "😎", Proc = "Dab", Pass = "EmotePack" },
	{ Id = "Cry", Name = "Cry", NameRu = "Плакать", Face = "😭", Proc = "Cry", Pass = "EmotePack" },
}
Config.EmoteDuration = 3
Config.EmoteCooldown = 4

-- ===== Обмен мемами =====
Config.Trade = {
	MaxMemes = 6, -- мемов с каждой стороны
	RequestTimeout = 20, -- сек на ответ на запрос
	ConfirmDelay = 3, -- отсчёт после того, как оба нажали «Готово»
	RequestCooldown = 5,
}

-- ===== Коды (вводятся в окне «Коды», регистр не важен). Expires — os.time() окончания или nil =====
-- Reward.Kind: "Coins" (IncomeSeconds/MinCoins), "Meme" (Rarity), "Spins" (Amount), "Item" (ItemId)
Config.Codes = {
	RELEASE = { Reward = { Kind = "Coins", IncomeSeconds = 600, MinCoins = 2500 } },
	SIXSEVEN = { Reward = { Kind = "Meme", Rarity = "Rare" } },
	MEMEGOD = { Reward = { Kind = "Spins", Amount = 2 } },
	SLIPPER = { Reward = { Kind = "Item", ItemId = "RubberChicken" } },
}

-- ===== Друзья и группа =====
Config.Social = {
	FriendBoostPer = 0.1, -- +10% дохода за каждого друга на сервере
	FriendBoostMax = 0.3,
	GroupId = 0, -- ID вашей Roblox-группы (0 — бонус выключен)
	GroupBoost = 0.1, -- +10% дохода участникам группы
	FavoritePromptAfter = 10 * 60, -- через сколько секунд игры попросить добавить игру в избранное
}

-- ===== Анти-чит переноски =====
Config.AntiCheat = {
	CarrySpeedSlack = 1.6, -- во сколько раз можно превысить скорость (пинг, физика)
	CarryExtraStuds = 8, -- запас в studs на тик
	MaxStrikes = 3, -- столько нарушений за переноску — мем возвращается хозяину
}

-- ===== Мем-пропуск (боевой пропуск сезона) =====
-- XP за события (Hooks): за каждую единицу Stat. Play — за каждые 60 секунд.
-- Награда уровня: Free для всех, Premium — с геймпассом BattlePass. Kind как у кодов + "Skin" (SkinId).
Config.BattlePass = {
	Season = "S1",
	Name = "Season 1: Meme Wars",
	NameRu = "Сезон 1: Мем-войны",
	EndsAt = 1798761600, -- 2027-01-01 00:00 UTC; после — пропуск нового сезона (смените Season)
	XpPerLevel = 150,
	Xp = { Buy = 5, Steal = 30, Slap = 2, MonsterHit = 2, Merge = 30, Defend = 25, Lock = 3, Play = 3, Quest = 60 },
	Levels = {
		{ Free = { Kind = "Coins", IncomeSeconds = 120, MinCoins = 500 }, Premium = { Kind = "Spins", Amount = 1 } },
		{ Free = { Kind = "Coins", IncomeSeconds = 180, MinCoins = 800 }, Premium = { Kind = "Coins", IncomeSeconds = 600, MinCoins = 3000 } },
		{ Free = { Kind = "Spins", Amount = 1 }, Premium = { Kind = "Meme", Rarity = "Epic" } },
		{ Free = { Kind = "Coins", IncomeSeconds = 240, MinCoins = 1200 }, Premium = { Kind = "Skin", SkinId = "SlipperFire" } },
		{ Free = { Kind = "Meme", Rarity = "Rare" }, Premium = { Kind = "Spins", Amount = 2 } },
		{ Free = { Kind = "Coins", IncomeSeconds = 300, MinCoins = 2000 }, Premium = { Kind = "Coins", IncomeSeconds = 900, MinCoins = 6000 } },
		{ Free = { Kind = "Spins", Amount = 1 }, Premium = { Kind = "Meme", Rarity = "Legendary" } },
		{ Free = { Kind = "Coins", IncomeSeconds = 360, MinCoins = 3000 }, Premium = { Kind = "Skin", SkinId = "BaseNeon" } },
		{ Free = { Kind = "Meme", Rarity = "Epic" }, Premium = { Kind = "Spins", Amount = 2 } },
		{ Free = { Kind = "Coins", IncomeSeconds = 420, MinCoins = 4000 }, Premium = { Kind = "Meme", Id = "Golden67" } },
		{ Free = { Kind = "Coins", IncomeSeconds = 480, MinCoins = 5000 }, Premium = { Kind = "Coins", IncomeSeconds = 1200, MinCoins = 10000 } },
		{ Free = { Kind = "Spins", Amount = 1 }, Premium = { Kind = "Meme", Rarity = "Legendary" } },
		{ Free = { Kind = "Coins", IncomeSeconds = 540, MinCoins = 6000 }, Premium = { Kind = "Skin", SkinId = "SlipperRainbow" } },
		{ Free = { Kind = "Meme", Rarity = "Legendary" }, Premium = { Kind = "Spins", Amount = 3 } },
		{ Free = { Kind = "Coins", IncomeSeconds = 600, MinCoins = 8000 }, Premium = { Kind = "Meme", Rarity = "Mythic" } },
		{ Free = { Kind = "Spins", Amount = 2 }, Premium = { Kind = "Coins", IncomeSeconds = 1800, MinCoins = 20000 } },
		{ Free = { Kind = "Coins", IncomeSeconds = 720, MinCoins = 10000 }, Premium = { Kind = "Skin", SkinId = "BaseGalaxy" } },
		{ Free = { Kind = "Meme", Rarity = "Legendary" }, Premium = { Kind = "Meme", Rarity = "Mythic" } },
		{ Free = { Kind = "Coins", IncomeSeconds = 900, MinCoins = 15000 }, Premium = { Kind = "Spins", Amount = 3 } },
		{ Free = { Kind = "Meme", Rarity = "Mythic" }, Premium = { Kind = "Meme", Id = "DiamondSahur" } },
	},
}

-- ===== Колесо удачи: 1 бесплатное вращение в день, остальные — за Robux, из пропуска и кодов =====
Config.Spin = {
	FreePerDay = 1,
	Segments = {
		{ Weight = 30, Reward = { Kind = "Coins", IncomeSeconds = 120, MinCoins = 300 } },
		{ Weight = 22, Reward = { Kind = "Coins", IncomeSeconds = 300, MinCoins = 800 } },
		{ Weight = 14, Reward = { Kind = "Meme", Rarity = "Rare" } },
		{ Weight = 12, Reward = { Kind = "Coins", IncomeSeconds = 900, MinCoins = 3000 } },
		{ Weight = 9, Reward = { Kind = "Meme", Rarity = "Epic" } },
		{ Weight = 6, Reward = { Kind = "Item", ItemId = "Energy" } },
		{ Weight = 4, Reward = { Kind = "Meme", Rarity = "Legendary" } },
		{ Weight = 2.5, Reward = { Kind = "Meme", Rarity = "Mythic" } },
		{ Weight = 0.5, Reward = { Kind = "Meme", Id = "Golden67" } },
	},
}

-- ===== Лимитированный мем недели =====
-- Неделя = os.time() // 604800; мем недели = Weekly.Memes[неделя % #Memes + 1]. На дорожке с шансом Chance.
Config.Weekly = {
	Memes = { "AuraFarmer", "PedroRaccoon", "MooDeng", "MewingCat" },
	Chance = 0.025,
}

-- ===== Скины (база и тапок). Price > 0 — за монеты; Source = "Pass"/"Spin" — только из пропуска/колеса =====
Config.Skins = {
	{ Id = "BaseDefault", Kind = "Base", Name = "Classic", NameRu = "Классика", Price = 0 },
	{ Id = "BaseCandy", Kind = "Base", Name = "Candy", NameRu = "Конфетная", Price = 150000, Floor = Color3.fromRGB(255, 170, 210), Wall = Color3.fromRGB(255, 255, 255), Material = "SmoothPlastic" },
	{ Id = "BaseGold", Kind = "Base", Name = "Golden", NameRu = "Золотая", Price = 2000000, Floor = Color3.fromRGB(255, 200, 60), Wall = Color3.fromRGB(200, 150, 30), Material = "Foil" },
	{ Id = "BaseNeon", Kind = "Base", Name = "Neon", NameRu = "Неоновая", Price = 0, Source = "Pass", Floor = Color3.fromRGB(30, 20, 60), Wall = Color3.fromRGB(0, 255, 200), Material = "Neon" },
	{ Id = "BaseGalaxy", Kind = "Base", Name = "Galaxy", NameRu = "Галактика", Price = 0, Source = "Pass", Floor = Color3.fromRGB(40, 10, 80), Wall = Color3.fromRGB(150, 60, 255), Material = "Glass" },
	{ Id = "SlipperDefault", Kind = "Slipper", Name = "Classic", NameRu = "Классика", Price = 0 },
	{ Id = "SlipperCamo", Kind = "Slipper", Name = "Camo", NameRu = "Камуфляж", Price = 40000, Color = Color3.fromRGB(80, 110, 60), Material = "Fabric" },
	{ Id = "SlipperFire", Kind = "Slipper", Name = "Fire", NameRu = "Огненный", Price = 0, Source = "Pass", Color = Color3.fromRGB(255, 90, 20), Material = "Neon" },
	{ Id = "SlipperRainbow", Kind = "Slipper", Name = "Rainbow", NameRu = "Радужный", Price = 0, Source = "Pass", Color = Color3.fromRGB(255, 80, 200), Material = "Neon", Rainbow = true },
}

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

local emoteById = {}
for _, emote in Config.Emotes do
	emoteById[emote.Id] = emote
end

function Config.GetEmote(id: string)
	return emoteById[id]
end

function Config.GetQuest(id: string)
	for _, quest in Config.Quests.Pool do
		if quest.Id == id then
			return quest
		end
	end
	return nil
end

function Config.GetAdminEvent(id: string)
	for _, event in Config.AdminEvents.Types do
		if event.Id == id then
			return event
		end
	end
	return nil
end

function Config.GetSkin(id: string)
	for _, skin in Config.Skins do
		if skin.Id == id then
			return skin
		end
	end
	return nil
end

-- Мем текущей недели (Config.Weekly) и время её окончания (os.time)
function Config.WeeklyMeme(time: number): (string, number)
	local week = time // 604800
	return Config.Weekly.Memes[week % #Config.Weekly.Memes + 1], (week + 1) * 604800
end

return Config
