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
