-- Тексты зон большой карты (ZoneService, ItemService, клиент: Status, Zones, Popups)
return {
	-- уведомления сервера
	ZoneTpCarrying = { "You can't teleport while carrying a meme!", "Нельзя телепортироваться с мемом в руках!" },
	TowerLava = { "🔥 Hot! Back to the checkpoint", "🔥 Горячо! Назад на чекпоинт" },
	TowerCheckpoint = { "✅ Checkpoint {Tier} saved!", "✅ Чекпоинт {Tier} сохранён!" },
	TowerPrizeTaken = { "You already took this prize today. Come back tomorrow!", "Этот приз ты уже забрал сегодня. Приходи завтра!" },
	SafeZoneDrop = { "No stealing in the Trade Plaza! {Meme} went back home.", "На Торговой площади не воруют! {Meme} вернулся к хозяину." },
	SafeZoneNoAttack = { "🛡️ No fighting in the safe zone!", "🛡️ В безопасной зоне не дерутся!" },
	ParkLimit = { "You collected a lot of treats! Rest a bit.", "Ты собрал кучу сладостей! Передохни немного." },
	SecretFound = { "🤫 You found the secret cave! Reward: {Meme}", "🤫 Ты нашёл секретную пещеру! Награда: {Meme}" },
	SecretFoundCoins = { "🤫 You found the secret cave! Reward: {Coins}", "🤫 Ты нашёл секретную пещеру! Награда: {Coins}" },
	SecretEmpty = { "The chest is empty... come back tomorrow.", "Сундук пуст... загляни завтра." },

	-- клиент
	ZoneSafeChip = { "🛡️ Safe zone", "🛡️ Безопасная зона" },
	ZoneTradePrompt = { "Trade", "Обмен" },
	ZoneChestPrompt = { "Open", "Открыть" },
	PopupTowerTitle = { "🗼 Meme Tower — tier {Tier} prize!", "🗼 Башня мемов — приз яруса {Tier}!" },
	PopupCaveTitle = { "🤫 Secret chest!", "🤫 Секретный сундук!" },
}
