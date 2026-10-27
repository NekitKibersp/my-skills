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
