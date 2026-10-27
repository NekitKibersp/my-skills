-- Все игровые числа в одном месте: мемы, цены, доход, тайминги. Баланс меняется только здесь.
-- Модуль общий: клиент рисует по нему Индекс и подсказки, сервер по нему проверяет покупки.
local Config = {}

Config.StartCoins = 100

-- Редкости в порядке возрастания. Weight — шанс появления на дорожке (относительный).
Config.Rarities = {
	{ Id = "Common", Name = "Обычный", Color = Color3.fromRGB(200, 205, 215), Weight = 60 },
	{ Id = "Rare", Name = "Редкий", Color = Color3.fromRGB(70, 160, 255), Weight = 25 },
	{ Id = "Epic", Name = "Эпический", Color = Color3.fromRGB(170, 90, 255), Weight = 10 },
	{ Id = "Legendary", Name = "Легендарный", Color = Color3.fromRGB(255, 200, 40), Weight = 3.5 },
	{ Id = "Mythic", Name = "Мифический", Color = Color3.fromRGB(255, 60, 80), Weight = 1.2 },
	{ Id = "God", Name = "Мем-Бог", Color = Color3.fromRGB(255, 120, 230), Weight = 0.25 },
	{ Id = "Secret", Name = "СЕКРЕТНЫЙ", Color = Color3.fromRGB(20, 20, 20), Weight = 0.05 },
	{ Id = "Halloween", Name = "Хэллоуин", Color = Color3.fromRGB(255, 130, 20), Weight = 0 },
}

-- Мемы. Face — эмодзи-«лицо» над телом, Shape — форма тела (Ball/Block/Cylinder),
-- Size — масштаб. Event = true — появляются только во время Кровавой Луны.
-- Чтобы обновить тему под новый тренд, достаточно поменять этот список.
Config.Creatures = {
	{ Id = "ClapCat", Name = "Хлопающий Кот", Face = "👏🐈‍⬛", Rarity = "Common", Price = 25, Income = 1, Color = Color3.fromRGB(30, 30, 35), Shape = "Ball", Size = 1 },
	{ Id = "Pups", Name = "Сонный Пупс", Face = "😴", Rarity = "Common", Price = 60, Income = 2, Color = Color3.fromRGB(255, 205, 180), Shape = "Ball", Size = 0.9 },
	{ Id = "Kolobok", Name = "Колобок", Face = "😏", Rarity = "Common", Price = 130, Income = 4, Color = Color3.fromRGB(240, 190, 60), Shape = "Ball", Size = 0.8 },

	{ Id = "SixSeven", Name = "Шесть-Семь", Face = "6️⃣7️⃣", Rarity = "Rare", Price = 500, Income = 12, Color = Color3.fromRGB(80, 200, 255), Shape = "Block", Size = 1.1 },
	{ Id = "Cheremsha", Name = "Черемша", Face = "🦁🐰", Rarity = "Rare", Price = 1300, Income = 26, Color = Color3.fromRGB(230, 170, 90), Shape = "Ball", Size = 1.15 },

	{ Id = "SharkSneakers", Name = "Акулёнок в Кроссах", Face = "🦈👟", Rarity = "Epic", Price = 5000, Income = 80, Color = Color3.fromRGB(90, 140, 220), Shape = "Cylinder", Size = 1.2 },
	{ Id = "TungStick", Name = "Тунг-Тунг Палка", Face = "🪵😠", Rarity = "Epic", Price = 13000, Income = 175, Color = Color3.fromRGB(150, 100, 60), Shape = "Cylinder", Size = 1.3 },

	{ Id = "BossCapybara", Name = "Капибара-Босс", Face = "😎", Rarity = "Legendary", Price = 50000, Income = 550, Color = Color3.fromRGB(160, 110, 70), Shape = "Block", Size = 1.4 },
	{ Id = "NinjaBanana", Name = "Банан-Ниндзя", Face = "🍌🥷", Rarity = "Legendary", Price = 125000, Income = 1200, Color = Color3.fromRGB(255, 230, 70), Shape = "Cylinder", Size = 1.4 },

	{ Id = "DjCat", Name = "Кот-Диджей", Face = "😼🎧", Rarity = "Mythic", Price = 400000, Income = 3500, Color = Color3.fromRGB(120, 60, 200), Shape = "Ball", Size = 1.6 },
	{ Id = "SigmaPenguin", Name = "Сигма-Пингвин", Face = "🐧🗿", Rarity = "Mythic", Price = 1200000, Income = 9000, Color = Color3.fromRGB(40, 50, 70), Shape = "Ball", Size = 1.7 },

	{ Id = "MegaSixSeven", Name = "МЕГА 67", Face = "6️⃣7️⃣🔥", Rarity = "God", Price = 6700000, Income = 40000, Color = Color3.fromRGB(255, 80, 200), Shape = "Block", Size = 2.1 },

	{ Id = "GreatCheremsha", Name = "Великий Черемшище", Face = "🦁🐰👑", Rarity = "Secret", Price = 30000000, Income = 150000, Color = Color3.fromRGB(15, 15, 15), Shape = "Ball", Size = 2.4 },

	{ Id = "PumpkinCat", Name = "Тыквенный Кот", Face = "🎃🐈‍⬛", Rarity = "Halloween", Price = 2500, Income = 60, Color = Color3.fromRGB(255, 120, 20), Shape = "Ball", Size = 1.1, Event = true, EventWeight = 60 },
	{ Id = "SkeletonClap", Name = "Скелет-Хлопушка", Face = "💀👏", Rarity = "Halloween", Price = 25000, Income = 400, Color = Color3.fromRGB(235, 235, 225), Shape = "Block", Size = 1.3, Event = true, EventWeight = 28 },
	{ Id = "WitchSixSeven", Name = "Ведьма 67", Face = "🧙‍♀️6️⃣7️⃣", Rarity = "Halloween", Price = 250000, Income = 2800, Color = Color3.fromRGB(90, 30, 120), Shape = "Cylinder", Size = 1.6, Event = true, EventWeight = 10 },
	{ Id = "GhostCheremsha", Name = "Призрак Черемши", Face = "👻🦁", Rarity = "Halloween", Price = 2000000, Income = 18000, Color = Color3.fromRGB(200, 230, 255), Shape = "Ball", Size = 1.9, Event = true, EventWeight = 2 },
}

-- Мутации умножают и доход, и цену. Event = true — только во время Кровавой Луны.
Config.Mutations = {
	{ Id = "None", Name = "", Mult = 1, Weight = 88 },
	{ Id = "Gold", Name = "Золотой", Mult = 1.5, Weight = 10, Color = Color3.fromRGB(255, 210, 60) },
	{ Id = "Diamond", Name = "Алмазный", Mult = 3, Weight = 2, Color = Color3.fromRGB(120, 230, 255) },
	{ Id = "Pumpkin", Name = "Тыквенный", Mult = 2, Weight = 15, Color = Color3.fromRGB(255, 120, 20), Event = true },
	{ Id = "Ghost", Name = "Призрачный", Mult = 4, Weight = 5, Color = Color3.fromRGB(190, 255, 240), Event = true },
}

-- Дорожка с мемами
Config.Conveyor = {
	SpawnInterval = 2.2, -- секунд между мемами
	Speed = 7, -- studs/сек
	EventChance = 0.4, -- доля хэллоуинских мемов во время Кровавой Луны
	MaxOnCarpet = 30,
}

-- База игрока
Config.Plot = {
	BaseSlots = 10,
	SlotsPerRebirth = 2,
	MaxSlots = 20,
	LockDuration = 60, -- секунд база закрыта
	LockCooldown = 30, -- после открытия нельзя сразу закрыть снова
}

-- Кража
Config.Steal = {
	HoldDuration = 1.6, -- сколько держать кнопку «Украсть»
	CarryWalkSpeed = 11,
	CarryTimeout = 45, -- не донёс за это время — мем возвращается
	SellRefund = 0.5, -- продажа своего мема возвращает 50% цены
}

-- Тапок: выбивает украденного мема и отбрасывает
Config.Slap = {
	Range = 9,
	Cooldown = 0.9,
	Knockback = 70,
}

-- Перерождение: цена растёт ×4, каждое даёт +50% к доходу и +2 слота
Config.Rebirth = {
	BaseCost = 500000,
	CostMult = 4,
	IncomeBonus = 0.5,
}

-- Оффлайн-доход: 25% от обычного, максимум за 3 часа
Config.Offline = {
	Rate = 0.25,
	MaxSeconds = 3 * 3600,
}

-- Кровавая Луна (хэллоуинский ивент)
Config.Event = {
	Interval = 6 * 60, -- между ивентами
	Duration = 100,
}

function Config.GetCreature(id: string)
	for _, creature in Config.Creatures do
		if creature.Id == id then
			return creature
		end
	end
	return nil
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

-- Доход в секунду конкретного мема с мутацией (без множителя перерождений)
function Config.IncomeOf(id: string, mutationId: string?): number
	local creature = Config.GetCreature(id)
	if not creature then
		return 0
	end
	return creature.Income * Config.GetMutation(mutationId).Mult
end

function Config.PriceOf(id: string, mutationId: string?): number
	local creature = Config.GetCreature(id)
	if not creature then
		return 0
	end
	return math.floor(creature.Price * Config.GetMutation(mutationId).Mult)
end

function Config.MaxSlots(rebirths: number): number
	return math.min(Config.Plot.BaseSlots + rebirths * Config.Plot.SlotsPerRebirth, Config.Plot.MaxSlots)
end

function Config.RebirthCost(rebirths: number): number
	return Config.Rebirth.BaseCost * Config.Rebirth.CostMult ^ rebirths
end

function Config.IncomeMult(rebirths: number): number
	return 1 + rebirths * Config.Rebirth.IncomeBonus
end

return Config
