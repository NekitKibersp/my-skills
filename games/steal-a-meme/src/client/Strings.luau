--!strict
-- Строки клиентского интерфейса (англ. + рус.). Добавляются в общий Locale через Locale.Add,
-- чтобы не трогать Shared/Locale.luau. Подключается первым в init.client.luau.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Locale = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Locale"))

Locale.Add({
	-- HUD
	UiIncome = { "+{Coins}/s", "+{Coins}/сек" },
	UiSlots = { "📦 {Used}/{Max}", "📦 {Used}/{Max}" },
	UiRebirths = { "♻️ {Count}", "♻️ {Count}" },
	UiIndexBonus = { "📖 +{Percent}%", "📖 +{Percent}%" },
	UiGiftIn = { "🎁 Gift in {Time}", "🎁 Подарок через {Time}" },
	UiGiftsDone = { "🎁 All gifts claimed!", "🎁 Все подарки получены!" },

	-- боковые кнопки
	BtnShop = { "Shop", "Магазин" },
	BtnIndex = { "Index", "Индекс" },
	BtnRebirth = { "Rebirth", "Рестарт" },
	BtnLock = { "Lock", "Замок" },
	BtnGuard = { "Guard", "Страж" },
	BtnMax = { "MAX", "МАКС" },

	-- баннеры
	BannerTrend = { "📈 TRENDING: {Meme} x{Mult} — {Time}", "📈 В ТРЕНДЕ: {Meme} ×{Mult} — {Time}" },
	BannerNight = { "🌙 SMILEY NIGHT {Time}", "🌙 НОЧЬ СМАЙЛИКА {Time}" },
	BannerNextNight = { "🌙 Next night in {Time}", "🌙 Ночь через {Time}" },
	BannerLuck = { "🍀 SERVER LUCK x2 — {Time}", "🍀 УДАЧА СЕРВЕРА ×2 — {Time}" },
	BannerCarry = { "Carrying {Meme}! Run to your base! {Time}", "Несёшь: {Meme}! Беги на свою базу! {Time}" },

	-- табличка мема
	BbViral = { "VIRAL", "ВИРУСНЫЙ" },
	BbIncome = { "{Coins}/s", "{Coins}/сек" },

	-- подсказки (ProximityPrompt)
	PromptBuy = { "Buy", "Купить" },
	PromptSteal = { "Steal", "Украсть" },
	PromptSell = { "Sell", "Продать" },
	PromptMerge = { "Make VIRAL ({Count} → 1)", "Сделать ВИРУСНЫМ ({Count} → 1)" },
	PromptLock = { "Lock base", "Закрыть базу" },
	PromptLockObject = { "{Seconds}s", "{Seconds} сек" },

	-- таблички баз
	SignFree = { "Free", "Свободно" },
	SignYours = { "YOUR BASE", "ТВОЯ БАЗА" },
	YourBaseArrow = { "YOUR BASE ⬇", "ТВОЯ БАЗА ⬇" },

	-- магазин
	ShopTitle = { "🛒 Shop", "🛒 Магазин" },
	ShopPasses = { "Game Passes (forever)", "Геймпассы (навсегда)" },
	ShopProducts = { "Boosts and Cash", "Бусты и деньги" },
	ShopOwned = { "Owned", "Куплено" },
	ShopCashHint = { "~{Coins}", "~{Coins}" },

	-- индекс
	IndexTitle = { "📖 Index", "📖 Индекс" },
	IndexHeader = { "Discovered {Count} — +{Percent}% income", "Открыто {Count} — +{Percent}% дохода" },
	IndexSub = { "Memes: {Found}/{Total} · Mutated: {Mutated}", "Мемы: {Found}/{Total} · С мутацией: {Mutated}" },
	IndexUnknown = { "???", "???" },
	IndexEvent = { "Night only", "Только ночью" },

	-- перерождение
	RebirthTitle = { "♻️ Rebirth", "♻️ Перерождение" },
	RebirthCost = { "Cost: {Price}", "Цена: {Price}" },
	RebirthPerkIncome = { "✅ +{Percent}% income forever (now x{Mult})", "✅ +{Percent}% дохода навсегда (сейчас ×{Mult})" },
	RebirthPerkSlots = { "✅ +{Count} base slots", "✅ +{Count} слота на базе" },
	RebirthPerkSlotsMax = { "Slots are already at max", "Слотов уже максимум" },
	RebirthCashReset = { "Your cash resets to $0, memes stay", "Деньги обнулятся, мемы останутся" },
	RebirthButton = { "REBIRTH", "ПЕРЕРОДИТЬСЯ" },

	-- страж
	GuardTitle = { "🐱⚔️ Sword Kitten Guard", "🐱⚔️ Страж: Kitten with a Sword" },
	GuardInfo = { "Slaps thieves who carry memes away from your base.", "Бьёт воров, которые уносят мемов с твоей базы." },
	GuardLevelNow = { "Level {Level}/{Max}", "Уровень {Level}/{Max}" },
	GuardNext = { "Next: range {Range} · hit every {Cooldown}s", "Дальше: радиус {Range} · удар раз в {Cooldown} сек" },
	GuardBuy = { "Hire for {Price}", "Нанять за {Price}" },
	GuardUpgrade = { "Upgrade for {Price}", "Улучшить за {Price}" },
	GuardMaxed = { "MAX LEVEL", "МАКС. УРОВЕНЬ" },

	-- всплывающие окна
	PopupOfflineTitle = { "Welcome back!", "С возвращением!" },
	PopupOffline = { "While you were away ({Time}) you earned {Coins}", "Пока тебя не было ({Time}), ты заработал {Coins}" },
	PopupDailyTitle = { "Daily reward", "Ежедневная награда" },
	PopupDaily = { "Day {Day} reward: {Coins}", "Награда за день {Day}: {Coins}" },
	PopupOk = { "OK", "OK" },

	-- ответы сервера без своей строки в Locale
	NotLoaded = { "Loading your data, try again in a moment", "Загружаем твои данные, попробуй через секунду" },

	-- эффекты
	FxRebirth = { "REBIRTH!", "ПЕРЕРОЖДЕНИЕ!" },
	MonsterName = { "😃 Smiley", "😃 Smiley" },
})

return Locale
