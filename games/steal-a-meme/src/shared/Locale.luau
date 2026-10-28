-- Тексты игры на английском и русском. Язык выбирается по языку Roblox у игрока (только на клиенте).
-- Сервер шлёт в Notify ключ и аргументы; аргумент Meme — Id мема, он переводится в имя,
-- аргументы Coins/Price форматируются как числа ($1.2K).
local LocalizationService = game:GetService("LocalizationService")
local RunService = game:GetService("RunService")

local Config = require(script.Parent.Config)
local Format = require(script.Parent.Format)

local Locale = {}

Locale.IsRussian = false
if RunService:IsClient() then
	local ok, localeId = pcall(function()
		return LocalizationService.RobloxLocaleId
	end)
	Locale.IsRussian = ok and string.sub(localeId, 1, 2) == "ru"
end

-- [key] = { en, ru }
local STRINGS: { [string]: { string } } = {
	-- уведомления сервера
	NotEnoughCash = { "Not enough cash! Need {Price}", "Не хватает денег! Нужно {Price}" },
	BaseFull = { "Your base is full! Sell or merge memes, or rebirth for more slots.", "База заполнена! Продай или слей мемов, либо переродись ради слотов." },
	Bought = { "You bought {Meme}!", "Ты купил: {Meme}!" },
	AlreadyTaken = { "Someone was faster!", "Кто-то оказался быстрее!" },
	BaseLocked = { "This base is locked!", "Эта база закрыта!" },
	AlreadyCarrying = { "You are already carrying a meme!", "Ты уже несёшь мема!" },
	StealStarted = { "You stole {Meme}! Run to your base!", "Ты украл: {Meme}! Беги на свою базу!" },
	BeingStolen = { "{Player} is stealing your {Meme}! Slap them!", "{Player} ворует твоего мема {Meme}! Бей тапком!" },
	Delivered = { "{Meme} is yours now!", "{Meme} теперь твой!" },
	MemeLost = { "{Player} stole your {Meme}...", "{Player} украл твоего мема {Meme}..." },
	StealFailed = { "You dropped {Meme}! It went back home.", "Ты уронил мема {Meme}! Он вернулся к хозяину." },
	MemeReturned = { "{Meme} came back to your base!", "{Meme} вернулся на твою базу!" },
	Sold = { "Sold {Meme} for {Coins}", "{Meme} продан за {Coins}" },
	Merged = { "VIRAL {Meme}! x{Mult} income!", "ВИРУСНЫЙ {Meme}! ×{Mult} дохода!" },
	NeedMoreToMerge = { "You need {Count} identical memes to merge", "Нужно {Count} одинаковых мема для слияния" },
	Locked = { "Base locked for {Seconds}s!", "База закрыта на {Seconds} сек!" },
	LockCooldown = { "Lock recharging: {Seconds}s", "Замок перезаряжается: {Seconds} сек" },
	Rebirthed = { "REBIRTH #{Count}! Income and slots increased!", "ПЕРЕРОЖДЕНИЕ №{Count}! Доход и слоты выросли!" },
	RebirthNeed = { "Rebirth costs {Price}", "Перерождение стоит {Price}" },
	GuardUpgraded = { "Sword Kitten guard is now level {Level}!", "Страж Kitten with a Sword — уровень {Level}!" },
	GuardMax = { "Guard is at max level!", "Страж уже максимального уровня!" },
	GuardHit = { "The Sword Kitten guard slapped you!", "Страж Kitten with a Sword огрел тебя!" },
	TrendNow = { "📈 TRENDING NOW: {Meme} — x{Mult} income!", "📈 В ТРЕНДЕ: {Meme} — ×{Mult} дохода!" },
	NightStart = { "🌙 SMILEY NIGHT! Lock your base and slap the Smiley!", "🌙 НОЧЬ SMILEY! Закрой базу и бей Smiley тапком!" },
	NightEnd = { "☀️ The night is over", "☀️ Ночь закончилась" },
	MonsterStole = { "😱 The Smiley is taking {Player}'s {Meme}!", "😱 Smiley утаскивает мема {Meme} у {Player}!" },
	MonsterEscaped = { "The Smiley ran away with {Meme}!", "Smiley убежал с мемом {Meme}!" },
	MonsterDefeated = { "The Smiley is defeated! Best slapper: {Player}", "Smiley побеждён! Лучший боец: {Player}" },
	NightReward = { "Reward for beating the Smiley: {Meme}!", "Награда за Smiley: {Meme}!" },
	NightRewardCoins = { "Reward for beating the Smiley: {Coins}!", "Награда за Smiley: {Coins}!" },
	Gift = { "🎁 Playtime gift: {Coins}!", "🎁 Подарок за игру: {Coins}!" },
	PassBought = { "Thanks for the purchase!", "Спасибо за покупку!" },
	ServerLuck = { "🍀 {Player} activated Server Luck x2!", "🍀 {Player} включил Удачу сервера ×2!" },
	GodSummoned = { "⚡ {Player} summoned a Meme God onto the carpet!", "⚡ {Player} призвал Мем-Бога на дорожку!" },
	CashBought = { "+{Coins}!", "+{Coins}!" },
	LockExtended = { "Lock extended!", "Замок продлён!" },
	SaveDisabled = { "Saving is unavailable (Studio: enable API Services in Game Settings → Security).", "Сохранение недоступно (Studio: включите API Services в Game Settings → Security)." },
	NotConfigured = { "This item is not set up yet", "Этот товар ещё не настроен" },
	ItemBought = { "Bought! Check your hotbar", "Куплено! Смотри в панели предметов" },
	ItemOwned = { "You already own this", "Уже куплено" },
	PassOnly = { "This item is sold for Robux only", "Этот предмет продаётся только за Robux" },
	NewIndex = { "New in Index: {Meme}! +1% income", "Новое в Индексе: {Meme}! +1% дохода" },
}

local function lookup(key: string): string
	local entry = STRINGS[key]
	if not entry then
		return key
	end
	return if Locale.IsRussian then entry[2] else entry[1]
end

-- Имя мема/редкости/мутации/товара на языке игрока (любая таблица с Name и NameRu)
function Locale.Name(item: any): string
	if not item then
		return "?"
	end
	if Locale.IsRussian and item.NameRu then
		return item.NameRu
	end
	return item.Name
end

function Locale.MemeName(id: string): string
	return Locale.Name(Config.GetCreature(id))
end

function Locale.T(key: string, args: { [string]: any }?): string
	local text = lookup(key)
	if args then
		text = string.gsub(text, "{(%w+)}", function(name)
			local value = args[name]
			if value == nil then
				return "{" .. name .. "}"
			elseif name == "Meme" then
				return Locale.MemeName(value)
			elseif name == "Coins" or name == "Price" then
				return "$" .. Format.Number(value)
			end
			return tostring(value)
		end)
	end
	return text
end

-- Строки фич из src/shared/Strings/*.luau (каждый модуль возвращает таблицу { Key = { en, ru } })
do
	local folder = script.Parent:FindFirstChild("Strings")
	if folder then
		for _, module in folder:GetChildren() do
			if module:IsA("ModuleScript") then
				for key, value in require(module) :: any do
					STRINGS[key] = value
				end
			end
		end
	end
end

-- Добавить свои строки (используется клиентским UI)
function Locale.Add(strings: { [string]: { string } })
	for key, value in strings do
		STRINGS[key] = value
	end
end

return Locale
