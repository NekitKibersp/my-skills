-- Создаёт ReplicatedStorage.Remotes. Добавляйте свои remotes в таблицу ниже;
-- клиент получает их через ReplicatedStorage:WaitForChild("Remotes"):WaitForChild(name).
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
	Notify = make("RemoteEvent", "Notify") :: RemoteEvent, -- сервер -> клиент: (text, kind: "success" | "error" | nil)
	-- Пример: Buy = make("RemoteFunction", "Buy") :: RemoteFunction,
}

folder.Parent = ReplicatedStorage

return Remotes
