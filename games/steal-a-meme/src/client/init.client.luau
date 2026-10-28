-- Точка входа клиента «Укради Мем»: создаёт экран, общий контекст UI и запускает модули.
-- Клиент только рисует состояние (атрибуты, теги) и просит действия через Remotes;
-- все решения (цены, кражи, награды) принимает сервер.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Строки UI добавляются в Locale до того, как кто-то их попросит
local Locale = require(script:WaitForChild("Strings"))
local UiKit = require(script:WaitForChild("UiKit"))
local Settings = require(script:WaitForChild("Settings"))
local Sounds = require(script:WaitForChild("Sounds"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local gui = UiKit.screen("GameUi")
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets -- кнопки не под чёлкой и не под кнопками Roblox

-- Уведомления — чуть ниже баннеров события сверху
local toastHolder = UiKit.create("Frame", {
	Name = "Toasts",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 112),
	Size = UDim2.new(1, 0, 0, 220),
	BackgroundTransparency = 1,
	ZIndex = 20,
	Parent = gui,
})
local rawToast = UiKit.toaster(toastHolder)

-- Один и тот же текст дважды подряд не показываем: сервер шлёт Notify, а окна ещё
-- показывают ключ, который вернула RemoteFunction (Rebirth/UpgradeGuard/ClaimDaily/...)
local recentToasts: { [string]: number } = {}
-- sound — особый звук события (Sounds.ForNotify), иначе звук по kind
local function toast(message: string, kind: string?, sound: string?)
	local now = os.clock()
	if recentToasts[message] and now - recentToasts[message] < 2 then
		return
	end
	recentToasts[message] = now
	for text, at in recentToasts do
		if now - at >= 2 then
			recentToasts[text] = nil
		end
	end
	rawToast(message, kind)
	Sounds.Toast(kind, sound)
end

-- Масштаб интерфейса по высоте экрана: телефон в альбомной ориентации ~ 0.6, ПК — 1;
-- умножается на настройку игрока UiScale (0.7..1.3)
local scales: { UIScale } = {}
local function currentScale(): number
	local camera = workspace.CurrentCamera
	local height = if camera then camera.ViewportSize.Y else 720
	local userScale = Settings.Get("UiScale")
	return math.clamp(height / 720, 0.6, 1) * (if type(userScale) == "number" then userScale else 1)
end
local function rescale()
	local value = currentScale()
	for _, scale in scales do
		scale.Scale = value
	end
end
local function watchCamera()
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	end
	rescale()
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
watchCamera()
Settings.Changed:Connect(function(key)
	if key == "UiScale" then
		rescale()
	end
end)

local windows: { [string]: GuiObject } = {}

-- Общий контекст, который получают все модули интерфейса
local ctx = {
	Gui = gui,
	Toast = toast,
	Windows = windows,
}

-- Добавить UIScale к кластеру интерфейса (панель, кнопки, окно)
function ctx.Scale(frame: GuiObject)
	local scale = Instance.new("UIScale")
	scale.Scale = currentScale()
	scale.Parent = frame
	table.insert(scales, scale)
end

-- Одно окно за раз: открыть/закрыть по имени
function ctx.Open(name: string, forceOpen: boolean?)
	local target = windows[name]
	if not target then
		return
	end
	local show = forceOpen or not target.Visible
	for _, window in windows do
		window.Visible = false
	end
	target.Visible = show
end

-- Окна не масштабируются: UiKit.window уже подгоняет размер под экран
function ctx.Register(name: string, window: GuiObject)
	windows[name] = window
end

Remotes:WaitForChild("Notify").OnClientEvent:Connect(function(key, args, kind)
	if type(key) ~= "string" then
		return
	end
	toast(
		Locale.T(key, if type(args) == "table" then args else nil),
		if type(kind) == "string" then kind else nil,
		Sounds.ForNotify(key)
	)
end)

-- Модули: окна регистрируются раньше HUD, который их открывает
local modules = {
	"Sounds",
	"Shop",
	"IndexWindow",
	"RebirthWindow",
	"DefenseWindow",
	"SettingsWindow",
	"Items",
	"DailyWindow",
	"QuestsWindow",
	"Emotes",
	"TradeWindow",
	"CodesWindow",
	"PassWindow",
	"SpinWindow",
	"SkinsWindow",
	"Popups",
	"Hud",
	"Social",
	"Banners",
	"Carry",
	"Alarm",
	"PlotSigns",
	"Prompts",
	"MemeBillboards",
	"Effects",
	"FxExtra",
	"Zones",
	"Status",
	"Tutorial",
}
for _, name in modules do
	local ok, err = pcall(function()
		require(script:WaitForChild(name)).Start(ctx)
	end)
	if not ok then
		warn("[Client] " .. name .. " failed: " .. tostring(err))
	end
end
