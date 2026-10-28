--!strict
-- Настройки игрока: звук, слабая графика, скрытие чужих табличек мемов, масштаб интерфейса.
-- Источник — атрибут SettingsJson (сервер сохраняет), изменения просим через Remotes.SetSetting(key, value).
-- Клиент применяет новое значение сразу (оптимистично); эхо сервера в течение PENDING_SECONDS
-- не перетирает только что изменённый ключ.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Util = require(script.Parent:WaitForChild("Util"))

local player = Players.LocalPlayer

local PENDING_SECONDS = 2
local SCALE_MIN, SCALE_MAX = 0.7, 1.3

local Settings = {}

local DEFAULTS: { [string]: any } = {
	Sound = true,
	LowGraphics = false,
	HideBillboards = false,
	UiScale = 1,
}

local values: { [string]: any } = table.clone(DEFAULTS)
local pendingAt: { [string]: number } = {}
local changed = Instance.new("BindableEvent")

-- Settings.Changed:Connect(function(key, value) ... end)
Settings.Changed = changed.Event
Settings.ScaleMin = SCALE_MIN
Settings.ScaleMax = SCALE_MAX

local function sanitize(key: string, value: any): any
	local default = DEFAULTS[key]
	if default == nil then
		return nil
	end
	if type(default) == "boolean" then
		return if type(value) == "boolean" then value else nil
	end
	if type(value) ~= "number" or value ~= value then
		return nil
	end
	-- Шаг 0.05, в пределах 0.7..1.3
	return math.clamp(math.floor(value * 20 + 0.5) / 20, SCALE_MIN, SCALE_MAX)
end

function Settings.Get(key: string): any
	local value = values[key]
	if value == nil then
		return DEFAULTS[key]
	end
	return value
end

-- Применить локально и попросить сервер сохранить
function Settings.Set(key: string, value: any)
	local clean = sanitize(key, value)
	if clean == nil then
		return
	end
	pendingAt[key] = os.clock()
	if values[key] ~= clean then
		values[key] = clean
		changed:Fire(key, clean)
	end
	local remote = ReplicatedStorage:WaitForChild("Remotes"):FindFirstChild("SetSetting")
	if remote and remote:IsA("RemoteEvent") then
		remote:FireServer(key, clean)
	end
end

local function readServer()
	local data = Util.json(player, "SettingsJson")
	if type(data) ~= "table" then
		return
	end
	local now = os.clock()
	for key in DEFAULTS do
		local pending = pendingAt[key]
		local clean = sanitize(key, data[key])
		if clean ~= nil and not (pending and now - pending < PENDING_SECONDS) and values[key] ~= clean then
			values[key] = clean
			changed:Fire(key, clean)
		end
	end
end

player:GetAttributeChangedSignal("SettingsJson"):Connect(readServer)
readServer()

return Settings
