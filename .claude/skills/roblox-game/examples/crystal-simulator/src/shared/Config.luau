-- Все игровые числа в одном месте: меняйте баланс здесь.
local Config = {}

-- Кирки: Power — урон по кристаллу и руда за удар, Cooldown — секунды между ударами.
Config.Tools = {
	{ Name = "Деревянная кирка", Price = 0, Power = 1, Cooldown = 0.5, Color = Color3.fromRGB(150, 105, 60), Material = Enum.Material.Wood },
	{ Name = "Каменная кирка", Price = 150, Power = 3, Cooldown = 0.45, Color = Color3.fromRGB(130, 130, 135), Material = Enum.Material.Slate },
	{ Name = "Железная кирка", Price = 1200, Power = 8, Cooldown = 0.4, Color = Color3.fromRGB(200, 200, 210), Material = Enum.Material.Metal },
	{ Name = "Золотая кирка", Price = 9000, Power = 20, Cooldown = 0.35, Color = Color3.fromRGB(255, 200, 40), Material = Enum.Material.Metal },
	{ Name = "Алмазная кирка", Price = 60000, Power = 55, Cooldown = 0.3, Color = Color3.fromRGB(90, 230, 255), Material = Enum.Material.Glass },
	{ Name = "Космическая кирка", Price = 400000, Power = 150, Cooldown = 0.25, Color = Color3.fromRGB(190, 90, 255), Material = Enum.Material.Neon },
}

-- Рюкзаки: Capacity — сколько руды помещается до продажи.
Config.Backpacks = {
	{ Name = "Мешочек", Price = 0, Capacity = 25 },
	{ Name = "Сумка", Price = 300, Capacity = 100 },
	{ Name = "Рюкзак", Price = 2500, Capacity = 400 },
	{ Name = "Большой рюкзак", Price = 18000, Capacity = 1500 },
	{ Name = "Сундук за спиной", Price = 120000, Capacity = 6000 },
	{ Name = "Чёрная дыра", Price = 900000, Capacity = 30000 },
}

-- Зоны идут друг за другом; каждая следующая открывается за монеты.
Config.Zones = {
	{
		Name = "Луг",
		Price = 0,
		Multiplier = 1,
		CrystalHP = 5,
		CrystalCount = 18,
		GroundColor = Color3.fromRGB(90, 160, 70),
		GroundMaterial = Enum.Material.Grass,
		CrystalColor = Color3.fromRGB(80, 170, 255),
		Decor = "Trees",
	},
	{
		Name = "Пещеры",
		Price = 2000,
		Multiplier = 4,
		CrystalHP = 30,
		CrystalCount = 16,
		GroundColor = Color3.fromRGB(80, 75, 85),
		GroundMaterial = Enum.Material.Slate,
		CrystalColor = Color3.fromRGB(170, 90, 255),
		Decor = "Rocks",
	},
	{
		Name = "Вулкан",
		Price = 30000,
		Multiplier = 15,
		CrystalHP = 150,
		CrystalCount = 14,
		GroundColor = Color3.fromRGB(60, 35, 30),
		GroundMaterial = Enum.Material.Basalt,
		CrystalColor = Color3.fromRGB(255, 90, 40),
		Decor = "Lava",
	},
	{
		Name = "Космос",
		Price = 400000,
		Multiplier = 60,
		CrystalHP = 800,
		CrystalCount = 12,
		GroundColor = Color3.fromRGB(25, 20, 45),
		GroundMaterial = Enum.Material.Glass,
		CrystalColor = Color3.fromRGB(255, 255, 140),
		Decor = "Stars",
	},
}

Config.ZoneSize = 140 -- сторона квадратной зоны в стадах
Config.MineRange = 10 -- насколько близко нужно стоять к кристаллу
Config.CrystalRespawn = 8 -- секунды до появления разбитого кристалла

-- Перерождение: сбрасывает монеты, руду, кирку и рюкзак; открытые зоны остаются.
Config.Rebirth = {
	BaseCost = 50000,
	CostGrowth = 2.5,
	MultiplierPerRebirth = 0.5,
}

function Config.RebirthCost(rebirths: number): number
	return math.floor(Config.Rebirth.BaseCost * Config.Rebirth.CostGrowth ^ rebirths)
end

function Config.Multiplier(rebirths: number): number
	return 1 + rebirths * Config.Rebirth.MultiplierPerRebirth
end

return Config
