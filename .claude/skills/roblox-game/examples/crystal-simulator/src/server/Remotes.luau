-- Создаёт папку ReplicatedStorage.Remotes, через которую клиент общается с сервером.
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
	Shop = make("RemoteFunction", "Shop") :: RemoteFunction, -- (kind, tier) -> ok, message
	Rebirth = make("RemoteFunction", "Rebirth") :: RemoteFunction, -- () -> ok, message
	Notify = make("RemoteEvent", "Notify") :: RemoteEvent, -- сервер -> клиент: (text, kind)
	Mined = make("RemoteEvent", "Mined") :: RemoteEvent, -- сервер -> клиент: (amount, position)
}

folder.Parent = ReplicatedStorage

return Remotes
