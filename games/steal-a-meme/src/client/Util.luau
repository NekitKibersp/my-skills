--!strict
-- Общие помощники клиента: серверное время, атрибуты с значениями по умолчанию,
-- слежение за объектами с тегом (с учётом StreamingEnabled) и поиск своей базы.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Util = {}

local player = Players.LocalPlayer

-- Время сервера: все отметки в атрибутах (TrendEndsAt, LockedUntil, ...) в этой шкале
function Util.now(): number
	return workspace:GetServerTimeNow()
end

-- 75 -> "1:15", 3725 -> "1:02:05"
function Util.clock(seconds: number): string
	local total = math.max(0, math.floor(seconds))
	local hours = total // 3600
	local minutes = (total % 3600) // 60
	local secs = total % 60
	if hours > 0 then
		return string.format("%d:%02d:%02d", hours, minutes, secs)
	end
	return string.format("%d:%02d", minutes, secs)
end

-- Атрибуты могут ещё не прийти от сервера — подставляем значение по умолчанию нужного типа
function Util.num(inst: Instance?, name: string): number
	local value = if inst then inst:GetAttribute(name) else nil
	return if type(value) == "number" then value else 0
end

function Util.str(inst: Instance?, name: string): string
	local value = if inst then inst:GetAttribute(name) else nil
	return if type(value) == "string" then value else ""
end

function Util.bool(inst: Instance?, name: string): boolean
	return (if inst then inst:GetAttribute(name) else nil) == true
end

-- Вызывает callback(child), когда у parent появится ребёнок name (сразу, если уже есть).
-- Нужно при StreamingEnabled: части моделей подгружаются позже. Возвращает соединение (или nil).
function Util.onChild(parent: Instance, name: string, callback: (Instance) -> ()): RBXScriptConnection?
	local existing = parent:FindFirstChild(name)
	if existing then
		task.spawn(callback, existing)
		return nil
	end
	local connection: RBXScriptConnection
	connection = parent.ChildAdded:Connect(function(child)
		if child.Name == name then
			connection:Disconnect()
			callback(child)
		end
	end)
	return connection
end

-- Следит за всеми объектами с тегом. onAdded(inst) может вернуть функцию очистки,
-- она вызывается, когда объект теряет тег или уходит из стриминга.
function Util.watchTagged(tag: string, onAdded: (Instance) -> (() -> ())?)
	local cleanups: { [Instance]: () -> () } = {}

	local function added(inst: Instance)
		if cleanups[inst] then
			return
		end
		local ok, cleanup = pcall(onAdded, inst)
		if not ok then
			warn("[" .. tag .. "]", cleanup)
			return
		end
		cleanups[inst] = cleanup or function() end
	end

	local function removed(inst: Instance)
		local cleanup = cleanups[inst]
		if cleanup then
			cleanups[inst] = nil
			cleanup()
		end
	end

	CollectionService:GetInstanceAddedSignal(tag):Connect(added)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(removed)
	for _, inst in CollectionService:GetTagged(tag) do
		task.spawn(added, inst)
	end
end

-- Папка баз (сервер создаёт её при старте)
local plotsFolder: Instance? = nil
function Util.plots(): Instance
	if not plotsFolder then
		plotsFolder = workspace:WaitForChild("Plots")
	end
	return plotsFolder :: Instance
end

-- Своя база: по атрибуту Plot игрока, запасной вариант — по OwnerUserId
function Util.myPlot(): Instance?
	local folder = workspace:FindFirstChild("Plots")
	if not folder then
		return nil
	end
	local index = Util.num(player, "Plot")
	if index > 0 then
		local plot = folder:FindFirstChild("Plot" .. index)
		if plot then
			return plot
		end
	end
	for _, plot in folder:GetChildren() do
		if plot:GetAttribute("OwnerUserId") == player.UserId then
			return plot
		end
	end
	return nil
end

-- Вызывает callback(plot) для каждой базы, в том числе подгруженной позже
function Util.forEachPlot(callback: (Instance) -> ())
	task.spawn(function()
		local folder = Util.plots()
		folder.ChildAdded:Connect(callback)
		for _, plot in folder:GetChildren() do
			task.spawn(callback, plot)
		end
	end)
end

-- Основная часть модели (Body по контракту, иначе PrimaryPart / первая деталь)
function Util.mainPart(model: Instance): BasePart?
	local body = model:FindFirstChild("Body")
	if body and body:IsA("BasePart") then
		return body
	end
	if model:IsA("Model") and model.PrimaryPart then
		return model.PrimaryPart
	end
	return model:FindFirstChildWhichIsA("BasePart", true)
end

function Util.character(): (Model?, BasePart?, Humanoid?)
	local character = player.Character
	if not character then
		return nil, nil, nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return character, (if root and root:IsA("BasePart") then root else nil), humanoid
end

return Util
