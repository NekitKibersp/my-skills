-- Тексты «фундамента» v5 (сервер): перерождения с требованиями, этажи, скорость, «Домой», Lucky Blocks
return {
	-- перерождение (Rebirthed переопределяет старую строку: слоты теперь дают этажи)
	Rebirthed = { "REBIRTH #{Count}! Income boosted!", "ПЕРЕРОЖДЕНИЕ №{Count}! Доход вырос!" },
	RebirthNeedMemes = { "You need {Count}× {Rarity} (or better) meme on your base to rebirth", "Для перерождения нужно {Count}× мем {Rarity} (или выше) на базе" },
	RebirthNeedMemeId = { "You need {Count}× {Meme} on your base to rebirth", "Для перерождения нужно {Count}× {Meme} на базе" },
	RebirthSpins = { "Rebirth reward: +{Count} wheel spins!", "Награда за перерождение: +{Count} вращ. колеса!" },
	RebirthItem = { "Rebirth reward: new item {Item}! Check your hotbar", "Награда за перерождение: новый предмет {Item}! Смотри в панели предметов" },
	FloorUnlocked = { "🏗️ Floor {Floor} of your base is open! Take the ramp up", "🏗️ Открыт {Floor}-й этаж базы! Поднимайся по пандусу" },

	-- скорость
	SpeedUpgraded = { "👟 Speed level {Level}! +{Bonus} walk speed", "👟 Скорость, уровень {Level}! +{Bonus} к скорости" },
	SpeedMax = { "Your speed is already maxed!", "Скорость уже на максимуме!" },
	TooFast = { "Too fast! Try again", "Слишком быстро! Попробуй ещё раз" },

	-- «Домой»
	HomeCarrying = { "You can't go home while carrying a meme!", "Нельзя домой с мемом в руках!" },
	HomeCooldown = { "Home is ready in {Seconds}s", "«Домой» через {Seconds} сек" },

	-- Lucky Blocks
	LuckyOpened = { "🎁 Your Lucky Block opened: {Meme}!", "🎁 Lucky Block открылся: {Meme}!" },

	-- Мем-пропуск на максимуме: вместо уровней — вращения
	PassMaxedSpins = { "Meme Pass is already maxed — you got +{Count} wheel spins instead!", "Мем-пропуск уже на максимуме — вместо уровней +{Count} вращ. колеса!" },
}
