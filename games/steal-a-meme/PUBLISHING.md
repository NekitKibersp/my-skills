# Чек-лист публикации «Steal a Meme»

Идите сверху вниз. Пункты с ⚠️ без исключений: без них игра либо не откроется для всех, либо сломается.

## 1. Тест (до публикации)
- [ ] Открыть `StealAMeme.rbxlx` в Studio → **Play**: ошибок в **View → Output** нет (или прислать их разработчику).
- [ ] **Test → Clients and Servers → 2 Players**: купить мема, украсть у второго игрока, ударить тапком, обмен, эмоции.
- [ ] Включить зиму для проверки: `Config.SeasonOverride = "Winter"`, потом вернуть `nil`.
- [ ] Ивент: в чате `/event MemeRain 2`.
- [ ] **Device Emulator** (иконка телефона на вкладке Test): интерфейс помещается на iPhone SE и маленьком Android.

## 2. Публикация
- [ ] ⚠️ **File → Publish to Roblox** → новое место. Название: `Steal a Meme 🎃 [NEW]` (зимой — `❄️`).
- [ ] ⚠️ **Game Settings → Security → Enable Studio Access to API Services** — включить (сохранения, лидерборды).
- [ ] ⚠️ **Game Settings → Places → Server Size = 8** (на карте 8 баз).
- [ ] Game Settings → Avatar: **R15** (эмоции рассчитаны на R15, R6 тоже работает).
- [ ] Game Settings → Communication: чат включён (команда `/event`, общение при обмене).

## 3. Монетизация (Creator Hub → ваша игра → Monetization)
- [ ] **Passes**: создать 8 геймпассов из `Config.GamePasses` (VIP, ExtraSlots, FastSteal, GoldSlipper,
      OfflinePlus, EmotePack, ConfettiCannon, BattlePass), картинка — яркий мем + надпись.
- [ ] **Developer Products**: создать 11 продуктов из `Config.Products`.
- [ ] Вписать все ID в `src/shared/Config.luau` → пересобрать (`rojo build -o StealAMeme.rbxlx`) → опубликовать снова.
- [ ] Проверить в Studio одну покупку (в Studio покупки тестовые, Robux не списываются).

## 4. Сообщество
- [ ] Создать Roblox-группу игры → вписать её ID в `Config.Social.GroupId` (бонус +10% за вступление).
- [ ] Выпустить коды из `Config.Codes` в описании игры, в группе, в Discord/TikTok. Новые коды — в каждом обновлении.
- [ ] Ваш UserId (и модераторов) — в `Config.AdminEvents.Admins` (создатель игры может и так).

## 5. ⚠️ Обязательные анкеты Roblox
- [ ] **Experience Questionnaire** (Creator Hub → игра → Audience → Questionnaire): честно ответить про насилие
      (мультяшные удары тапком — «Mild/Unrealistic»), покупки, чат. Без анкеты игра не появится в поиске/рекомендациях.
- [ ] Audience → **Public** когда всё готово.

## 6. Страница игры
- [ ] **Иконка 512×512**: один яркий мем крупно, контрастный фон, без мелкого текста.
- [ ] **Превью 1920×1080** (3–5 штук): кража с мемом над головой, Ночь Smiley, Мем-дождь, база с вирусными мемами.
- [ ] **Описание** (EN + RU): 1 строка о сути («Buy memes, steal memes, become the MEME KING!»), список фишек, коды, «👍 Like for more updates».
- [ ] Жанр: **Simulation** / теги: steal, memes, brainrot, tycoon.

## 7. Старт
- [ ] Roblox Ads: стартовая рекламная кампания (Sponsored Experiences) на 2–3 дня, бюджет от 1000–3000 Robux в день,
      сравнить CTR 2–3 иконок.
- [ ] Написать Roblox-ютуберам/тиктокерам: эксклюзивный код и запуск Мем-дождя для их видео (`/event MemeRain`).
- [ ] Смотреть **Creator Hub → Analytics**: удержание D1/D7, воронка новичка (Joined → FirstBuy → FirstSteal →
      TutorialDone → FirstRebirth), экономика и покупки. Где обрыв — туда первое улучшение.

## 8. После запуска
- [ ] Обновление каждые 1–2 недели: новые мемы (`Config.Creatures`), новый код, новый мем недели (`Config.Weekly`).
- [ ] Новый сезон Мем-пропуска: поменять `Config.BattlePass.Season`, `EndsAt`, награды.
- [ ] Сезоны карты сами переключаются по дате (Хэллоуин → Зима 6 ноября).
