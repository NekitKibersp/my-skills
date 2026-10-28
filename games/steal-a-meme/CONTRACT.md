# Контракт сервер ↔ клиент («Укради Мем»)

Сервер — источник правды. Клиент только рисует состояние и просит действия.

## Атрибуты `ReplicatedStorage`
| Атрибут | Тип | Смысл |
|---|---|---|
| `TrendingId` | string | Id мема «В ТРЕНДЕ» ("" — нет) |
| `TrendEndsAt` | number | `workspace:GetServerTimeNow()`, когда сменится тренд |
| `NightActive` | bool | идёт Ночь Смайлика |
| `NightEndsAt` | number | время конца ночи (если идёт) |
| `NextNightAt` | number | время начала следующей ночи |
| `LuckEndsAt` | number | до какого времени действует «Удача сервера ×2» (0 — нет) |

Время везде — `workspace:GetServerTimeNow()`.

## Атрибуты игрока (`player:GetAttribute`)
| Атрибут | Тип | Смысл |
|---|---|---|
| `DataLoaded` | bool | данные загружены |
| `Coins` | number | деньги |
| `Rebirths` | number | перерождения |
| `Stolen` | number | всего успешных краж |
| `TotalEarned` | number | всего заработано |
| `GuardLevel` | number | уровень стража 0..#Config.Guard |
| `IndexCount` | number | сколько записей в Индексе |
| `IndexJson` | string | JSON-массив ключей Индекса `"Id|Mutation"` (см. `Config.IndexKey`) |
| `Income` | number | итоговый доход в секунду (со всеми множителями) |
| `SlotsUsed` / `MaxSlots` | number | занято / всего слотов |
| `Plot` | number | номер своей базы (1..8) |
| `Carrying` | string | Id мема, которого игрок сейчас несёт ("" — ничего) |
| `CarryEndsAt` | number | когда мем вернётся хозяину, если не донести |
| `DailyStreak` | number | день ежедневной награды |
| `SessionStart` | number | начало сессии (для таймера подарков) |
| `GiftsClaimed` | number | сколько подарков за время уже выдано (индекс в `Config.PlaytimeGifts`) |
| `Pass_VIP`, `Pass_ExtraSlots`, `Pass_FastSteal`, `Pass_GoldSlipper`, `Pass_OfflinePlus` | bool | куплен ли геймпасс |

## Мир
- `workspace.Plots.Plot1..Plot8` (Model). Атрибуты: `Index`, `OwnerUserId` (0 — свободна),
  `OwnerName`, `LockedUntil`, `LockCooldownUntil`. Дети:
  - `Floor` (Part) — пол базы, её границы;
  - `Sign` (Part) — табличка над входом, клиент вешает на неё SurfaceGui (Face = Front) с именем хозяина и таймером замка;
  - `LockButton` (Part) с `ProximityPrompt` `LockPrompt`;
  - `Slots` (Folder) — `Slot1..Slot25` (Part), атрибут `Unlocked` (bool);
  - `Memes` (Folder) — мемы на базе;
  - `Guard` (Model, есть если `GuardLevel > 0`).
- Мемы — модели с тегом CollectionService `"Meme"`. PrimaryPart `Body`. Атрибуты:
  `CreatureId`, `Mutation` ("None" | "Gold" | ...), `Viral` (bool), `State`
  ("Carpet" | "Walking" | "Placed" | "Carried"), `OwnerUserId` (0 на дорожке), `Price` (цена на дорожке),
  `Height` (высота модели в studs — куда вешать табличку).
  ProximityPrompts в `Body`: `BuyPrompt` (на дорожке), `StealPrompt`, `SellPrompt`, `MergePrompt` (на базе).
  Сервер создаёт их с английским текстом и включает все; **клиент** локально переводит
  `ActionText`/`ObjectText` и выключает лишние: на своих мемах — `StealPrompt`, на чужих — `SellPrompt`
  и `MergePrompt`; `MergePrompt` включать только если у игрока есть `Config.Viral.Count` одинаковых
  невирусных мемов (вид+мутация). С геймпассом `FastSteal` клиент ставит `StealPrompt.HoldDuration =
  Config.Steal.FastHoldDuration` (сервер сам проверяет время удержания).
- Монстр — `workspace.Smiley` (Model, тег `"Monster"`), атрибуты `Hp`, `MaxHp`, `Carrying` (Id мема или "").
- Таблицы лидеров — `workspace.Map.Leaderboards` (сервер рисует сам).

## Remotes (`ReplicatedStorage.Remotes`)
| Имя | Направление | Аргументы |
|---|---|---|
| `Notify` | S→C | `(key, args?, kind?)` — текст через `Locale.T(key, args)`; kind: "success" / "error" / "info" |
| `Knockback` | S→C | `(velocity: Vector3)` — клиент ставит `HumanoidRootPart.AssemblyLinearVelocity = velocity` и на 0.6 с `Humanoid.PlatformStand`/`Physics` |
| `Fx` | S→All | `(kind, data)`: `"Slap"` {Position}, `"Bought"` {Position, Rarity}, `"Stolen"` {Position}, `"Delivered"` {Position, UserId}, `"Merged"` {Position}, `"Rebirth"` {UserId}, `"MonsterHit"` {Position} |
| `Popup` | S→C | `(kind, data)`: `"Offline"` {Coins, Seconds}, `"Daily"` {Coins, Day} |
| `LockBase` | C→S | `()` |
| `Rebirth` | C→S (RF) | `() -> (ok, key)` |
| `UpgradeGuard` | C→S (RF) | `() -> (ok, key)` |

Покупки за Robux клиент начинает сам: `MarketplaceService:PromptGamePassPurchase(player, Config.GamePasses[k].Id)`
/ `PromptProductPurchase(player, Config.Products[k].Id)`. Если `Id == 0` — показать `Locale.T("NotConfigured")`.

## Дополнения v2 (сезоны, туториал, предметы)
| Где | Что | Тип | Смысл |
|---|---|---|---|
| `ReplicatedStorage` | `Season` | string | "Halloween" / "Winter" / "None" — текущий сезон (`Config.SeasonFor`) |
| игрок | `ItemsJson` | string | JSON-массив Id купленных предметов (`Config.Items`); `Slipper` есть всегда |
| игрок | `TutorialDone` | number | 0 — показать туториал, 1 — пройден |
| игрок | `SessionStart` | number | теперь = `GetServerTimeNow() - сыграно_сегодня`: подарки за время копятся за день, а не за сессию (формула на клиенте та же) |
| персонаж | `Invisible` | bool | надета шапка-невидимка |
| персонаж | `BoostUntil` | number | до какого времени действует энергетик |
| Tool | `ItemId` | string | Id предмета (`Config.Items`); имя Tool = Id |
| Tool | `CooldownEndsAt` | number | серверное время конца перезарядки (клиент показывает таймер у экипированного предмета) |

Remotes:
| Имя | Направление | Аргументы |
|---|---|---|
| `Knockback` | S→C | `(velocity: Vector3, stun: number?)` — лежать в Physics `stun` секунд (по умолчанию 0.6) |
| `BuyItem` | C→S (RF) | `(itemId: string) -> (ok, key)`; ключи: "ItemBought", "ItemOwned", "NotEnoughCash" |
| `TutorialDone` | C→S | `()` — туториал пройден/пропущен |

Новые `Fx`: `"Invisible"` {Position} (облачко), `"Banana"` {Position} (поскользнулся), `"Energy"` {Position}.
Банановые кожуры — `workspace.Bananas` (детали, тег `"Banana"`, атрибут `OwnerUserId`).

## Дополнения v3 (квесты, календарь наград, админ-ивенты, обмен, защита базы, эмоции, новые предметы)
Строки фич: каждый модуль кладёт свои тексты в `src/shared/Strings/<Фича>.luau` (возвращает `{ Key = { "en", "ru" } }`),
`Locale` подгружает их сам. Имена мемов не переводятся.

| Где | Атрибут | Тип | Смысл |
|---|---|---|---|
| игрок | `DailyReady` | bool | можно забрать ежедневную награду |
| игрок | `DailyDay` | number | какой день календаря (1..7) будет выдан при следующем заборе |
| игрок | `DailyStreak` | number | (было) последний забранный день |
| игрок | `QuestsJson` | string | JSON `{ List = { { Id, Goal, Progress, Claimed } }, AllClaimed = bool, ResetAt = serverTime }` |
| игрок | `TurretLevel` / `LaserLevel` | number | уровни защиты базы (0 — нет) |
| ReplicatedStorage | `AdminEvent` | string | Id идущего ивента (`Config.AdminEvents.Types`) или "" |
| ReplicatedStorage | `AdminEventEndsAt` | number | конец ивента |
| ReplicatedStorage | `NextAdminEventAt` | number | начало следующего ивента по расписанию (0 — не скоро/неизвестно) |
| ReplicatedStorage | `EventIncomeMult` / `EventLuckMult` / `EventSpawnMult` | number | множители текущего ивента (по умолчанию 1) |
| ReplicatedStorage | `EventMutationChance` | number | 0..1, шанс принудительной мутации у мема на дорожке |

Мир: у базы появляются `Turret` (Model) и `LaserGate` (Part, при срабатывании мигает).

Remotes (созданы в `Remotes.luau`):
| Имя | Направление | Аргументы |
|---|---|---|
| `ClaimDaily` | C→S RF | `() -> (ok, key)` |
| `ClaimQuest` | C→S RF | `(index: number \| "All") -> (ok, key)` |
| `UpgradeDefense` | C→S RF | `(kind: "Turret" \| "LaserGate") -> (ok, key)` |
| `Emote` | C→S | `(emoteId)` → сервер рассылает `Fx("Emote", { UserId, Emote })`, клиент каждого игрока анимирует персонажа процедурно (`Config.Emotes[*].Proc`) и показывает эмодзи над головой |
| `TradeRequest` | C→S | `(targetUserId)` |
| `TradeIncoming` | S→C | `(fromUserId, fromName)` — показать «X хочет обменяться» с кнопками |
| `TradeRespond` | C→S | `(fromUserId, accept)` |
| `TradeSetOffer` | C→S | `(slots: { number })` — номера своих слотов, до `Config.Trade.MaxMemes` |
| `TradeReady` | C→S | `(ready: boolean)` |
| `TradeCancel` | C→S | `()` |
| `TradeState` | S→C | `(state \| nil)`; nil — обмен закрыт. state = `{ PartnerUserId, PartnerName, MyOffer = { { Slot, Id, Mut, Viral } }, TheirOffer = { { Id, Mut, Viral } }, MyReady, TheirReady, CountdownEndsAt (0 или serverTime) }` |

Предметы с `Pass` (Confetti Cannon) есть только у владельцев геймпасса; `ItemsJson` их тоже включает.
Новые Fx: `"Emote"` {UserId, Emote}, `"Turret"` {From, To} (выстрел), `"Laser"` {Position}, `"Freeze"` {Position, Radius},
`"Rocket"` {Position}, `"Shot"` {From, To} (дальнее оружие), `"AdminEvent"` {Id} (старт ивента — большой баннер), `"MysteryBox"` {UserId, Meme}.
`Knockback` теперь используется и для ракетных ботинок (stun = 0: просто толчок).

## Дополнения v4 (коды, друзья/группа, аналитика, анти-чит, Мем-пропуск, колесо, мем недели, скины)
| Где | Атрибут | Тип | Смысл |
|---|---|---|---|
| игрок | `FriendBoost` | number | бонус дохода за друзей на сервере (0..`Config.Social.FriendBoostMax`) |
| игрок | `InGroup` | bool | состоит в группе `Config.Social.GroupId` (бонус `GroupBoost`) |
| игрок | `BPJson` | string | JSON `{ Season, Xp, Level, XpInLevel, Free = { уровни }, Premium = { уровни }, EndsAt }` (Free/Premium — массивы забранных уровней) |
| игрок | `Pass_BattlePass` | bool | премиум-пропуск куплен |
| игрок | `Spins` | number | вращений колеса в запасе (без бесплатного) |
| игрок | `FreeSpinReady` | bool | бесплатное вращение сегодня доступно |
| игрок | `SkinsJson` | string | JSON `{ Owned = { id… }, Base = id, Slipper = id }` |
| ReplicatedStorage | `WeeklyMeme` | string | Id мема недели (`Config.Weekly`) |
| ReplicatedStorage | `WeeklyEndsAt` | number | конец недели (os.time) |

Remotes:
| Имя | Направление | Аргументы |
|---|---|---|
| `RedeemCode` | C→S RF | `(code) -> (ok, key)`; ключи: CodeRedeemed, CodeInvalid, CodeUsed, CodeExpired |
| `Spin` | C→S RF | `() -> (ok, key, segmentIndex)` — индекс в `Config.Spin.Segments` (клиент крутит колесо до него), награда приходит Popup `"Spin"` { Coins?, Meme?, Item?, Spins? } |
| `ClaimPass` | C→S RF | `(level, "Free" \| "Premium") -> (ok, key)`; награда — Popup `"Pass"` { Level, Track, Coins?, Meme?, Spins?, Skin?, Item? } |
| `BuySkin` / `EquipSkin` | C→S RF | `(skinId) -> (ok, key)` |
| `CheckGroup` | C→S | `()` — после вступления в группу (клиент: `GroupService:PromptJoinAsync`) |

Скины: база — сервер перекрашивает Floor/Wall своей базы; тапок — цвет/материал Handle (`ItemService`).
Приглашение друзей и «Добавить в избранное» — только клиент (`SocialService:PromptGameInvite`, `AvatarEditorService:PromptSetFavorite`).

## Дополнения v5 (большая карта и зоны)
Карта выросла: `MapBuilder.HALF_X = 420`, `HALF_Z = 160` (дорожка и базы на прежних местах). Зоны строит
`ZoneBuilder` (вызывается из `MapBuilder.Build`), логику ведёт `ZoneService`; баланс — `Config.Zones`.
Новых RemoteEvent/RemoteFunction нет.

| Где | Атрибут | Тип | Смысл |
|---|---|---|---|
| персонаж | `InSafeZone` | bool | корень персонажа на Торговой площади: его нельзя бить/стрелять/морозить/ронять бананом, и сам он не атакует; вор с мемом, вошедший на площадь, роняет мема (`StealService.Fail`) |
| персонаж | `ServerMovedAt` | number | серверный перенос (телепорт-площадки, лава башни, выталкивание с закрытой базы) — анти-чит переноски сбрасывает опорную точку |
| персонаж | `MoveGraceUntil` | number | теперь ставят и батуты парка (повышенный допуск скорости на 3 с) |

Мир (`workspace.Map`, модели зон — `ModelStreamingMode = Atomic`, клиент их не ждёт):
- `TeleportHub` у спавна и площадки в зонах: `TeleportPad` (Part), атрибут `Target` = `"Tower"` / `"Plaza"` / `"Park"` /
  `"Base"` / `"Carpet"` / `"TowerDown"`. Касание → сервер проверяет дистанцию, кулдаун 3 с, что игрок не несёт мема, и переносит.
- `MemeTower` (x≈320): `StartPad`, `Landing`, `Summit` с атрибутом `Checkpoint` (1..4); `PrizePad` / `SummitChest` с атрибутом
  `PrizeTier` (1..3); детали `Lava` (касание → на последний чекпоинт, мем при этом возвращается хозяину);
  `VanishPlatform` (сервер мигает CanCollide/Transparency); вращающиеся лава-перекладины.
- `EastCliffs` + `Cave` — скалы по восточному краю и секретная пещера с `SecretChest` (`ProximityPrompt` `ChestPrompt`). В UI не отмечается.
- `TradePlaza` (x≈-300, z≈-60) — столы `TradeTable` с `ProximityPrompt` `TradePrompt`: клиент по `PromptTriggered` открывает окно выбора игрока (`TradePick`).
- `CandyPark` (x≈-300, z≈+75) — `Trampoline` (касание → `Knockback` вверх, stun 0); пикапы — `workspace.Map.Pickups`.
- `ZoneSigns` (Persistent) — большие таблички с названиями зон.

Промпты зон сервер создаёт с английским `ActionText`, клиент переводит при `PromptShown` (`ZoneTradePrompt`, `ZoneChestPrompt`).

| Remote | Новое |
|---|---|
| `Fx` | `"Pickup"` {Position, Coins, UserId} — **только собравшему** (`FireClient`): всплывающее «+$X» |
| `Popup` | `"Zone"` {Zone = "Tower" \| "Cave", Tier?, Coins?, Meme?, Spins?} — приз яруса башни / сундука пещеры |
| `Notify` | ключи из `src/shared/Strings/Zones.luau`: ZoneTpCarrying, TowerLava, TowerCheckpoint {Tier}, TowerPrizeTaken, SafeZoneDrop {Meme}, SafeZoneNoAttack, ParkLimit, SecretFound {Meme}, SecretFoundCoins {Coins}, SecretEmpty |

Данные: таблица `Zones` = `{ Tower1, Tower2, Tower3, Cave }` — UTC-день (`os.time() // 86400`) последнего забранного приза.

## Дополнения v5 (фундамент: этажи, перерождения с требованиями, скорость, Lucky Blocks, тревога, «Домой», настройки, звуки)
Конфиг: `Config.Plot.Floors`/`FloorSlots`/`PassSlots`, `Config.FloorsUnlocked`, `Config.FloorOfSlot`, `Config.SlotAvailable`,
`Config.Rebirth.Tiers`, `Config.RebirthTier`, `Config.RebirthCost`, `Config.MatchesRequirement`, `Config.Speed`,
`Config.LuckyBlocks`, мемы с `Lucky = true` (`LuckyEpic`/`LuckyLegendary`/`LuckyMythic`), `Config.HomeCooldown`, редкости с `Rank`.

| Где | Атрибут | Тип | Смысл |
|---|---|---|---|
| игрок | `SpeedLevel` | number | уровень прокачки скорости (0..#Config.Speed), данные |
| игрок | `StolenBy` | number | UserId вора, который сейчас несёт ТВОЕГО мема (0 — никто); `StolenMeme` — Id этого мема |
| игрок | `SettingsJson` | string | JSON `{ Sound = bool, LowGraphics = bool, HideBillboards = bool, UiScale = number }` (сохраняется) |
| игрок | `HomeReadyAt` | number | серверное время, когда «Домой» снова доступно |
| мем (Model) | `OpensAt` | number | у Lucky Block на базе: серверное время открытия |
| мем (Model) | `Floor` | number | этаж слота (1..3) |
| база | `FloorsUnlocked` | number | сколько этажей открыто у хозяина |

Мир: у базы этажи — `Floor2`/`Floor3` (Part, платформа), лестница, ограждения; закрытый этаж перекрыт полупрозрачным
барьером `FloorLock2`/`FloorLock3` с табличкой «🔒 Rebirth N». Слоты `Slot1..Slot42` (атрибуты `Unlocked`, `Floor`).

Remotes:
| Имя | Направление | Аргументы |
|---|---|---|
| `Rebirth` | C→S RF | (было) теперь проверяет `Config.Rebirth.Tiers[n].Requires`; ключи: Rebirthed, RebirthNeed, RebirthNeedMemes |
| `BuySpeed` | C→S RF | `() -> (ok, key)`; ключи: SpeedUpgraded, SpeedMax, NotEnoughCash |
| `GoHome` | C→S | `()` — телепорт на свою базу (перезарядка, не с мемом) |
| `SetSetting` | C→S | `(key, value)` — Sound/LowGraphics/HideBillboards (bool), UiScale (0.7..1.3) |

Новые Fx: `"LuckyOpen"` {Position, Meme, UserId}.

### Уточнения сервера (v5, фундамент)
- Геометрия базы (система координат базы: `Floor.CFrame`, -Z — вход): верх пола этажа n = `0.5 + Config.Plot.Floors[n].Height`
  (0.5 / 14.5 / 28.5). `Floor2` — платформа во всю ширину, z от -12 до задней стены; `Floor3` — то же без полосы x < -33
  (проём над пандусом), за проёмом — `Floor3Landing`. Пандусы — `Stairs` (наклонная плита ≈30°): на 2-й этаж во дворе
  у +X стены (z -36 → -12), на 3-й — на 2-м этаже у -X стены (z -6 → 18). Перила — `Railing`. Детали этажей с атрибутом
  `SkinFloor = true` перекрашивает скин базы. Стены — до высоты ≈36.
- `FloorLock2`/`FloorLock3` — блок ForceField над **всем** пандусом (CanCollide, атрибуты `Floor`, `UnlockRebirth`),
  внутри `BillboardGui` `LockGui` с `TextLabel` `Text` = «🔒 Rebirth N». Открытый этаж: `CanCollide = false`,
  `Transparency = 1`, `LockGui.Enabled = false`. У свободной базы `FloorsUnlocked = 1`.
- Слоты: 1..36 — сетка 4×3 на этажах 1..3 (ряды z = 30 / 19.5 / 9), 37..42 (геймпасс) — ряд из 6 на 1-м этаже (z = -2).
  Атрибуты слота: `Index`, `Floor`, `Unlocked` (= `Config.SlotAvailable`). Новые мемы встают на нижний доступный этаж.
  Мемы из недоступных слотов (пропал геймпасс) остаются на месте и приносят доход. `MaxSlots` = `Config.MaxSlots`, `SlotsUsed` = все мемы.
- Кража: вор должен стоять на этаже мема (по высоте), сквозь пол/потолок украсть нельзя.
- Смайлик (ночь) крадёт только мемов 1-го этажа; турель стреляет только по прямой видимости (не сквозь этажи);
  страж стоит во дворе у пандуса на 2-й этаж (x = 14). Высота тела мема ограничена 11 studs (между этажами 13).
- Старые сохранения: мем в слоте ещё закрытого этажа при загрузке переезжает на свободный доступный слот.
- Требования перерождения считаются как у клиента: каждое отдельно по всем мемам базы, кроме унесённых (мем в обмене считается).
- `OpensAt` снимается, пока Lucky Block несут (вор/Смайлик); ставится заново при любой расстановке на базу.
  Блок в обмене или в руках не открывается — откроется, когда освободится.
- `StolenBy`/`StolenMeme` ставятся после загрузки данных (0/""). При нескольких ворах — самая свежая из идущих краж.
- `SettingsJson` по умолчанию `{ Sound = true, LowGraphics = false, HideBillboards = false, UiScale = 1 }`;
  `SetSetting` — не больше 30 изменений за 10 сек, неверные ключи/типы молча игнорируются.
- `HomeReadyAt` = 0 после загрузки; «Домой» использует тот же серверный перенос, что телепорт-площадки (`ServerMovedAt`).
- `BuySpeed` — не чаще раза в 0.3 сек (ключ `TooFast`).
- Продукт `PassLevels` при пропуске на максимуме даёт 3 вращения колеса (Notify `PassMaxedSpins` {Count}).
- `Notify` (строки в `src/shared/Strings/Foundation.luau`): `Rebirthed` {Count} (текст переопределён), `RebirthNeedMemes`
  {Count, Rarity}, `RebirthNeedMemeId` {Count, Meme} (требование по Id; RF всё равно вернёт ключ `RebirthNeedMemes`),
  `RebirthSpins` {Count}, `RebirthItem` {Item}, `FloorUnlocked` {Floor}, `SpeedUpgraded` {Level, Bonus}, `SpeedMax`,
  `TooFast`, `HomeCarrying`, `HomeCooldown` {Seconds}, `LuckyOpened` {Meme} (хозяину, вместе с Fx `LuckyOpen`), `PassMaxedSpins` {Count}.
