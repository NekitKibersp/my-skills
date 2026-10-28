-- Создаёт ReplicatedStorage.Remotes. Клиент получает их через
-- ReplicatedStorage:WaitForChild("Remotes"):WaitForChild(name).
-- Покупка, кража, продажа и слияние мемов идут через ProximityPrompt на сервере, remotes для них не нужны.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = Instance.new("Folder")
folder.Name = "Remotes"

local function make(className: string, name: string)
	local remote = Instance.new(className)
	remote.Name = name
	remote.Parent = folder
	return remote
end

local Remotes = {
	-- сервер -> клиент: (key: string, args: { [string]: any }?, kind: "success" | "error" | "info"?)
	-- key — ключ из Shared.Locale, клиент сам переводит текст на язык игрока.
	Notify = make("RemoteEvent", "Notify") :: RemoteEvent,
	-- сервер -> клиент: (velocity: Vector3, stun: number?) — отбросить своего персонажа и уронить на stun секунд
	Knockback = make("RemoteEvent", "Knockback") :: RemoteEvent,
	-- сервер -> все: (kind: string, data: { [string]: any }) — разовые эффекты, см. README
	Fx = make("RemoteEvent", "Fx") :: RemoteEvent,
	-- сервер -> клиент: (kind: "Offline" | "Daily", data: { Coins: number, Seconds: number?, Day: number? })
	Popup = make("RemoteEvent", "Popup") :: RemoteEvent,
	-- клиент -> сервер: () — закрыть свою базу
	LockBase = make("RemoteEvent", "LockBase") :: RemoteEvent,
	-- клиент -> сервер: () -> (ok: boolean, key: string)
	Rebirth = make("RemoteFunction", "Rebirth") :: RemoteFunction,
	-- клиент -> сервер: () -> (ok: boolean, key: string)
	UpgradeGuard = make("RemoteFunction", "UpgradeGuard") :: RemoteFunction,
	-- клиент -> сервер: (itemId: string) -> (ok: boolean, key: string) — купить предмет за монеты
	BuyItem = make("RemoteFunction", "BuyItem") :: RemoteFunction,
	-- клиент -> сервер: () — туториал пройден или пропущен
	TutorialDone = make("RemoteEvent", "TutorialDone") :: RemoteEvent,
	-- клиент -> сервер: () -> (ok, key) — забрать ежедневную награду
	ClaimDaily = make("RemoteFunction", "ClaimDaily") :: RemoteFunction,
	-- клиент -> сервер: (index: number | "All") -> (ok, key) — забрать награду квеста / бонус за все
	ClaimQuest = make("RemoteFunction", "ClaimQuest") :: RemoteFunction,
	-- клиент -> сервер: (kind: "Turret" | "LaserGate") -> (ok, key) — купить/улучшить защиту базы
	UpgradeDefense = make("RemoteFunction", "UpgradeDefense") :: RemoteFunction,
	-- клиент -> сервер: (emoteId: string) — сыграть эмоцию (все увидят через Fx "Emote")
	Emote = make("RemoteEvent", "Emote") :: RemoteEvent,
	-- Обмен (см. CONTRACT.md):
	TradeRequest = make("RemoteEvent", "TradeRequest") :: RemoteEvent, -- C→S (targetUserId)
	TradeIncoming = make("RemoteEvent", "TradeIncoming") :: RemoteEvent, -- S→C (fromUserId, fromName)
	TradeRespond = make("RemoteEvent", "TradeRespond") :: RemoteEvent, -- C→S (fromUserId, accept: boolean)
	TradeSetOffer = make("RemoteEvent", "TradeSetOffer") :: RemoteEvent, -- C→S (slots: { number })
	TradeReady = make("RemoteEvent", "TradeReady") :: RemoteEvent, -- C→S (ready: boolean)
	TradeCancel = make("RemoteEvent", "TradeCancel") :: RemoteEvent, -- C→S ()
	TradeState = make("RemoteEvent", "TradeState") :: RemoteEvent, -- S→C (state | nil)
	-- v4: коды, колесо, пропуск, скины, группа
	RedeemCode = make("RemoteFunction", "RedeemCode") :: RemoteFunction, -- C→S (code: string) -> (ok, key)
	Spin = make("RemoteFunction", "Spin") :: RemoteFunction, -- C→S () -> (ok, key, segmentIndex?)
	ClaimPass = make("RemoteFunction", "ClaimPass") :: RemoteFunction, -- C→S (level: number, track: "Free" | "Premium") -> (ok, key)
	BuySkin = make("RemoteFunction", "BuySkin") :: RemoteFunction, -- C→S (skinId) -> (ok, key)
	EquipSkin = make("RemoteFunction", "EquipSkin") :: RemoteFunction, -- C→S (skinId) -> (ok, key)
	CheckGroup = make("RemoteEvent", "CheckGroup") :: RemoteEvent, -- C→S () — перепроверить членство в группе
	-- v5 (фундамент): скорость, «Домой», настройки
	BuySpeed = make("RemoteFunction", "BuySpeed") :: RemoteFunction, -- C→S () -> (ok, key)
	GoHome = make("RemoteEvent", "GoHome") :: RemoteEvent, -- C→S () — телепорт на свою базу
	SetSetting = make("RemoteEvent", "SetSetting") :: RemoteEvent, -- C→S (key: string, value: boolean | number)
}

folder.Parent = ReplicatedStorage

return Remotes
