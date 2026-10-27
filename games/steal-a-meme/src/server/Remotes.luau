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
	-- сервер -> клиент: (velocity: Vector3) — отбросить своего персонажа (удар тапком)
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
}

folder.Parent = ReplicatedStorage

return Remotes
