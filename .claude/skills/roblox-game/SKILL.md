---
name: roblox-game
description: "Build a complete Roblox game mode or place from scratch as a Rojo project (Luau) and ship a ready .rbxlx file — simulator, obby, tycoon, PvP round arena, tower defense, horror. Use when the user asks to make/create a Roblox game, place, mode or experience (\"сделай плейс\", \"режим в роблоксе\", \"игру для Roblox\", симулятор, обби, тайкун), or to add a large feature (shop, rebirths, zones, rounds, saving) to a Rojo project. For editing a single script or Roblox API questions, use roblox-luau and the other roblox-* skills instead."
user-invocable: true
argument-hint: "[жанр и идея игры]"
---

# Roblox: целый режим под ключ

Ты делаешь игру без Roblox Studio: весь код, карта и интерфейс создаются скриптами в Rojo-проекте,
а на выходе получается `.rbxlx`, который пользователь открывает в Studio и сразу нажимает Play.
Перед написанием кода прочитай `references/checklist.md` (устаревшие API и частые ошибки) и
скиллы по нужным темам:

| Тема | Скилл |
|---|---|
| Основы: сервисы, Script vs LocalScript, Remotes | `roblox-luau` |
| Защита remotes, валидация, rate limit | `roblox-networking` |
| Сохранение прогресса, лидерборды | `roblox-datastores` |
| Интерфейс, адаптивность под телефон | `roblox-ui` |
| Персонажи, инструменты, респавн, анимации | `roblox-characters` |
| Коллизии, рейкасты, движущиеся детали | `roblox-physics` |
| Геймпассы и покупки за Robux | `roblox-monetization` |
| ИИ врагов и NPC | `game-ai` |

## 1. Понять, что строим

Если жанр и ключевая идея не названы — задай **один** вопрос с вариантами (симулятор, обби, тайкун,
PvP-арена, tower defense, хоррор) и куда положить результат. Остальное реши сам по разумным
умолчаниям и перечисли их в итоге. Открой `references/genres.md` для выбранного жанра.

Для симулятора есть полная эталонная реализация — `examples/crystal-simulator/`. Для других
жанров тоже смотри её как образец стиля и устройства сервисов.

## 2. Инструменты

```bash
scripts/setup.sh            # rojo + selene; через cargo — несколько минут, запускай в фоне сразу
```
Без rojo проект всё равно можно написать, но не собрать `.rbxlx` — тогда скажи об этом прямо и
дай команду `rojo build -o Game.rbxlx`.

## 3. Создать проект

```bash
scripts/new-project.sh <папка> <ИмяИгры>
```
Шаблон уже содержит:

| Файл | Что даёт |
|---|---|
| `default.project.json` | `src/shared` → ReplicatedStorage.Shared, `src/server` → ServerScriptService.Server, `src/client` → StarterPlayerScripts.Client |
| `src/shared/Config.luau` | место для всего баланса |
| `src/shared/Format.luau` | `Format.Number(1234) → "1.23K"` |
| `src/server/init.server.luau` | запуск сервисов и обработка входа игрока (с гонкой CharacterAdded/загрузка данных) |
| `src/server/DataService.luau` | DataStore с ретраями, автосохранение, BindToClose, leaderstats, зеркало данных в атрибутах игрока, событие `Changed`; не перезаписывает прогресс, если загрузка упала |
| `src/server/Remotes.luau` | создание RemoteEvent/RemoteFunction в `ReplicatedStorage.Remotes` |
| `src/client/UiKit.luau` | `create`, `text`, `button`, `window`, `toaster`, палитра |
| `src/client/init.client.luau` | UI-заготовка: счётчик монет из атрибута, уведомления |

`init.server.luau` / `init.client.luau` превращают папку в Script/LocalScript, а соседние `.luau`
становятся его дочерними ModuleScript: `require(script.DataService)`.

## 4. Архитектура

- **Config first.** Сначала опиши в `Config.luau` все каталоги, цены, награды, тайминги. Сервер
  проверяет по ним покупки, клиент по ним рисует магазин.
- **Сервисы на сервере** — по одному модулю на механику (`MapBuilder`, `ShopService`, `RoundService`...),
  у каждого `Start()`; связи между ними — через колбэки из `init.server.luau` или `DataService.Changed`,
  без циклических `require`.
- **Состояние → атрибуты.** Данные игрока сервер пишет в `player:SetAttribute`, общее состояние
  игры — в атрибуты `ReplicatedStorage`/`workspace`. Клиент слушает `GetAttributeChangedSignal`.
  Remotes нужны только для действий игрока (купить, переродиться) и разовых эффектов.
  Добавляя поле в данные — добавь его в `DEFAULT_DATA` в DataService.
- **Сервер решает всё.** Клиент только просит; сервер проверяет деньги, дистанцию, кулдауны, номер
  этапа и т.д. (подробности — roblox-networking).
- **Карта кодом.** `MapBuilder.Build()` создаёт `workspace.Map`: земля, границы (невидимые стены),
  спавн, зоны, интерактивные объекты. Используй `Random.new(seed)` — карта одинакова при каждом
  запуске. Ставь `Parent` последним. Пиши в README, что в режиме редактирования мир пустой.
- **UI кодом** через `UiKit`. Обязательно: `ResetOnSpawn = false`, кнопки через `.Activated`,
  размеры через Scale + `UISizeConstraint`, чтобы влезало на телефон. Панель статистики слева сверху
  с отступом от системных кнопок, основные кнопки — слева по центру.
- **Ощущения:** всплывающие «+N», твины, частицы, уведомления — без них игра кажется сломанной.
- Тексты в игре — на языке пользователя.

## 5. Проверить

```bash
scripts/check.sh <папка>    # rojo build + selene
```
- Исправь всё, что нашёл selene. Если std урезанный (нет сети), предупреждение про `warn`/известный
  Roblox-глобал можно игнорировать — но новые undefined_variable проверь.
- Перечитай свой код по чек-листу из `references/checklist.md`: гонки загрузки, `WaitForChild`
  на клиенте, дебаунс `Touched`, утечки при выходе игрока.
- Studio у тебя нет: **никогда не говори, что игра протестирована.** Скажи, что код собран и
  проверен линтером, и попроси прислать красные строки из View → Output, если что-то не так.

## 6. Сдать

- Положи собранный `.rbxlx` рядом с проектом и `README.md` (на языке пользователя):
  как открыть (File → Open from File → Play), что в режиме мир пустой, как включить сохранение
  (Game Settings → Security → Enable Studio Access to API Services, игра должна быть опубликована),
  как опубликовать (File → Publish to Roblox, Permissions → Public), таблица механик, структура файлов,
  где менять баланс, идеи развития.
- Отправь `.rbxlx` пользователю файлом, если есть инструмент для этого.
- Коммить/пушить — если работа в git-репозитории и пользователь это просил.
