# Устаревшие API и частые ошибки Roblox

## Устаревшее → современное

| Не использовать | Использовать |
|---|---|
| `wait`, `spawn`, `delay` | `task.wait`, `task.spawn`, `task.delay` |
| `tick()` для интервалов | `os.clock()` (замеры), `os.time()`/`DateTime` (дата) |
| `Instance.new("Part", parent)` | создать, настроить, затем `Parent` последним |
| `model:SetPrimaryPartCFrame` | `model:PivotTo` |
| `Humanoid:LoadAnimation` | `humanoid:WaitForChild("Animator"):LoadAnimation` |
| `BodyVelocity/BodyPosition/BodyGyro` | `LinearVelocity/AlignPosition/AlignOrientation` |
| `workspace:FindPartOnRay`, `Region3` | `workspace:Raycast`, `GetPartBoundsInBox` |
| `game.Players` | `game:GetService("Players")` |
| `pairs(t)`/`ipairs(t)` | можно просто `for k, v in t do` (Luau) |

## Частые ошибки (проверь перед сдачей)

1. Персонаж/данные: обработка `player.Character`, появившегося до подключения/загрузки.
2. Клиент обращается к объекту без `WaitForChild` → `nil` при медленной загрузке.
3. `StreamingEnabled` (по умолчанию в новых местах): далёкие детали на клиенте отсутствуют —
   слушай `ChildAdded` или делай `Model.ModelStreamingMode = Persistent` для важного.
4. Нет дебаунса на `Touched` → награда начисляется 20 раз.
5. `IntValue` хранит только целые: дробные значения обрезаются → округляй сам или бери `NumberValue`.
6. Бесконечный `while true do` без `task.wait` → зависание.
7. Ошибка внутри обработчика remote ломает только этот вызов, но `RemoteFunction` вернёт ошибку клиенту —
   оборачивай рискованное в `pcall`.
8. Кэш `state[player]` не очищен при выходе.
9. Звуки/модели/текстуры по `rbxassetid://` — не выдумывай ID: используй те, что дал пользователь,
   или создавай примитивами и пометь, куда вставить свои.
10. Типы: `--!strict` в начале модуля помогает ловить ошибки в Studio Script Analysis.

