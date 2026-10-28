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
	FxSlip = { "SLIP!", "БАЦ!" },
	MonsterName = { "😃 Smiley", "😃 Smiley" },

	-- предметы (ответы BuyItem + окно)
	ItemBought = { "Bought! Check your hotbar", "Куплено! Смотри в панели предметов" },
	ItemOwned = { "You already own this item", "Этот предмет уже есть" },
	BtnItems = { "Items", "Предметы" },
	ItemsTitle = { "🗡️ Items", "🗡️ Предметы" },
	ItemsWeapons = { "Weapons", "Оружие" },
	ItemsGadgets = { "Gadgets", "Гаджеты" },
	ItemStatsWeapon = { "📏 {Range} · ⏱ {Cooldown}s · 💫 {Stun}s", "📏 {Range} · ⏱ {Cooldown} сек · 💫 {Stun} сек" },
	ItemStatsGadget = { "⌛ {Duration}s · ⏱ {Cooldown}s", "⌛ {Duration} сек · ⏱ {Cooldown} сек" },
	ItemArea = { "💥 area", "💥 по площади" },
	ItemFree = { "Free", "Бесплатно" },

	-- состояние персонажа (над панелью предметов)
	StatusCooldown = { "⏳ {Seconds}s", "⏳ {Seconds} сек" },
	StatusInvisible = { "🎩 Invisible {Time}", "🎩 Невидимка {Time}" },
	StatusBoost = { "🥤 Boost {Time}", "🥤 Ускорение {Time}" },

	-- туториал
	TutorialStep = { "Tutorial {Step}/{Total}", "Обучение {Step}/{Total}" },
	TutorialBuy = { "Walk to the red carpet and buy a meme (press E)", "Подойди к красной дорожке и купи мема (нажми E)" },
	TutorialIncome = { "Nice! Memes earn cash every second. Buy more and watch your Cash grow", "Отлично! Мемы приносят деньги каждую секунду. Покупай ещё и смотри, как растут деньги" },
	TutorialSteal = { "Steal: go to another player's base and HOLD E on their meme, then run home", "Кража: иди на чужую базу, ЗАЖМИ E на меме и беги домой" },
	TutorialProtect = { "Protect: press 🔒 Lock when thieves come. Hit them with your Slipper!", "Защита: жми 🔒 Замок, когда идут воры. Бей их тапком!" },
	TutorialSkip = { "Skip", "Пропустить" },
	TutorialFinished = { "Tutorial complete! Go get rich! 🚀", "Обучение пройдено! Вперёд к богатству! 🚀" },

	-- сезоны
	IndexSeasonHalloween = { "Halloween night", "Ночь Хэллоуина" },
	IndexSeasonWinter = { "Winter night", "Зимняя ночь" },
})

-- v3: календарь, квесты, админ-ивенты, обмен, защита базы, эмоции, мистери-бокс
Locale.Add({
	-- боковые кнопки
	BtnDaily = { "Daily", "Награды" },
	BtnQuests = { "Quests", "Квесты" },
	BtnTrade = { "Trade", "Обмен" },
	BtnEmotes = { "Emotes", "Эмоции" },
	BtnDefense = { "Defense", "Защита" },

	-- календарь
	DailyTitle = { "📅 Daily Rewards", "📅 Ежедневные награды" },
	DailyHint = { "Come back every day! Miss a day and the streak resets.", "Заходи каждый день! Пропустишь день — серия сбросится." },
	DailyDayN = { "Day {Day}", "День {Day}" },
	DailyToday = { "TODAY", "СЕГОДНЯ" },
	DailyNext = { "NEXT", "ДАЛЬШЕ" },
	DailyCoins = { "~{Coins}", "~{Coins}" },
	DailyMeme = { "{Rarity} meme", "{Rarity} мем" },
	DailyClaim = { "CLAIM", "ЗАБРАТЬ" },
	DailyTomorrow = { "Come back tomorrow", "Приходи завтра" },

	-- всплывающее окно календаря
	PopupDailyHead = { "Day {Day} reward:", "Награда за день {Day}:" },
	PopupDailyMeme = { "{Face} {Name} joined your base!", "{Face} {Name} теперь на твоей базе!" },
	PopupDailyItem = { "{Face} {Name} is in your hotbar!", "{Face} {Name} — в панели предметов!" },

	-- квесты
	QuestsTitle = { "📜 Daily Quests", "📜 Ежедневные квесты" },
	QuestsResetIn = { "New quests in {Time}", "Новые квесты через {Time}" },
	QuestsEmpty = { "Quests are loading...", "Квесты загружаются..." },
	QuestRewardHint = { "🎁 ~{Coins}", "🎁 ~{Coins}" },
	QuestClaim = { "CLAIM", "ЗАБРАТЬ" },
	QuestDoneMark = { "✅ Done", "✅ Готово" },
	QuestAllBonus = { "🏆 All quests bonus", "🏆 Бонус за все квесты" },
	QuestAllHint = { "Claim every quest above to unlock", "Забери награды всех квестов выше" },

	-- админ-ивенты
	BannerAdminEvent = { "{Face} {Name} — {Time}", "{Face} {Name} — {Time}" },
	BannerNextAdminEvent = { "⭐ Next admin event in {Time}", "⭐ Админ-ивент через {Time}" },
	SplashAdminEvent = { "ADMIN EVENT!", "АДМИН-ИВЕНТ!" },

	-- обмен
	TradePickTitle = { "🤝 Trade with...", "🤝 Обмен с..." },
	TradePickEmpty = { "No other players on this server", "На сервере нет других игроков" },
	TradeIncomingText = { "🤝 {Player} wants to trade!", "🤝 {Player} предлагает обмен!" },
	TradeAccept = { "Accept", "Принять" },
	TradeDecline = { "Decline", "Отказать" },
	TradeTitle = { "🤝 Trade with {Player}", "🤝 Обмен: {Player}" },
	TradeYourOffer = { "Your offer {Count}/{Max}", "Ты отдаёшь {Count}/{Max}" },
	TradeTheirOffer = { "{Player} offers", "{Player} отдаёт" },
	TradeNothing = { "Nothing yet", "Пока ничего" },
	TradeNoMemes = { "You have no memes to trade", "Нет мемов для обмена" },
	TradeBtnReady = { "READY", "ГОТОВ" },
	TradeUnready = { "Not ready", "Не готов" },
	TradeBtnCancel = { "Cancel", "Отмена" },
	TradeCountdown = { "Trading in {Seconds}...", "Обмен через {Seconds}..." },
	TradeWaiting = { "Both players must press READY", "Оба игрока должны нажать ГОТОВ" },
	TradeMaxMemes = { "You can offer up to {Count} memes", "Можно предложить до {Count} мемов" },
	TradeTip = { "Tap your memes to add them", "Нажимай на своих мемов, чтобы добавить" },

	-- защита базы
	DefenseTitle = { "🛡️ Base Defense", "🛡️ Защита базы" },
	DefenseGuardName = { "🐱⚔️ Sword Kitten", "🐱⚔️ Kitten with a Sword" },
	DefenseTurretName = { "🔫 Turret", "🔫 Турель" },
	DefenseTurretInfo = { "Shoots thieves carrying your memes and strangers on your base.", "Стреляет в воров с твоими мемами и в чужаков на базе." },
	DefenseLaserName = { "🚨 Laser Gate", "🚨 Лазерные ворота" },
	DefenseLaserInfo = { "A thief with your meme who walks through the entrance falls and drops it.", "Вор с твоим мемом падает на входе и роняет его." },
	DefenseTurretNext = { "Next: range {Range} · shot every {Cooldown}s · stun {Stun}s", "Дальше: радиус {Range} · выстрел раз в {Cooldown} сек · оглушение {Stun} сек" },
	DefenseLaserNext = { "Next: recharge {Cooldown}s · stun {Stun}s", "Дальше: перезарядка {Cooldown} сек · оглушение {Stun} сек" },

	-- эмоции
	EmotesTitle = { "😀 Emotes", "😀 Эмоции" },
	EmotePackLocked = { "🔒 Emote Pack", "🔒 Пак эмоций" },
	EmoteWait = { "Wait {Seconds}s", "Подожди {Seconds} сек" },

	-- предметы за геймпасс
	ItemRobuxPass = { "Robux pass", "Геймпасс за Robux" },

	-- магазин: подсказки к новым товарам
	ShopHintMysteryBox = { "Legendary {A}% · Mythic {B}% · Meme God {C}%", "Легендарный {A}% · Мифический {B}% · Мем-Бог {C}%" },
	ShopHintMemeRain = { "x4 memes for everyone · {Time}", "×4 мемов для всех · {Time}" },
	ShopHintEmotePack = { "+{Count} emotes", "+{Count} эмоции" },

	-- мистери-бокс
	MysteryBoxYou = { "You got", "Тебе выпал" },
	MysteryBoxOther = { "📦 {Player} got {Meme} from a Mystery Box!", "📦 {Player} получил {Meme} из Мистери-бокса!" },
})

return Locale
