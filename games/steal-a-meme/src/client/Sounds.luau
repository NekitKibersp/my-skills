-- Звуки событий: разовые 2D-звуки через SoundService (слышит только этот игрок).
-- Пока используются только файлы, которые идут вместе с клиентом Roblox (rbxasset://sounds/...).
-- Чтобы поставить свои звуки — замените Id в таблице SOUNDS на "rbxassetid://<ваш id>"
-- (id не выдумываем: только загруженные вами / из Creator Store).
-- Звук выключается настройкой Sound = false (Settings).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Settings = require(script.Parent:WaitForChild("Settings"))
local UiKit = require(script.Parent:WaitForChild("UiKit"))

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

-- Событие -> звук. Speed — PlaybackSpeed (выше — тоньше и короче).
local SOUNDS: { [string]: { Id: string, Volume: number, Speed: number } } = {
	Click = { Id = "rbxasset://sounds/button.wav", Volume = 0.35, Speed = 1 },
	Success = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.4, Speed = 1.1 },
	Error = { Id = "rbxasset://sounds/button.wav", Volume = 0.5, Speed = 0.6 },
	Bought = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.5, Speed = 1.4 },
	Slap = { Id = "rbxasset://sounds/collide.wav", Volume = 0.6, Speed = 1 },
	Stolen = { Id = "rbxasset://sounds/swoosh.wav", Volume = 0.6, Speed = 0.9 },
	Delivered = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.6, Speed = 1.7 },
	MemeLost = { Id = "rbxasset://sounds/uuhhh.mp3", Volume = 0.5, Speed = 1 },
	LuckyOpen = { Id = "rbxasset://sounds/swoosh.wav", Volume = 0.6, Speed = 1.4 },
	Rebirth = { Id = "rbxasset://sounds/swoosh.wav", Volume = 0.7, Speed = 0.6 },
	Alarm = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.6, Speed = 0.55 },
	Pickup = { Id = "rbxasset://sounds/action_jump.mp3", Volume = 0.35, Speed = 1.6 },
}

-- Ключи Notify -> событие звука вместо обычного «успех/ошибка». "None" — без звука
-- (о краже своего мема уже кричит тревога).
local NOTIFY_SOUNDS: { [string]: string } = {
	Bought = "Bought",
	ItemBought = "Bought",
	SpeedUpgraded = "Bought",
	GuardUpgraded = "Bought",
	PassBought = "Bought",
	StealStarted = "Stolen",
	Delivered = "Delivered",
	MemeLost = "MemeLost",
	Rebirthed = "Rebirth",
	BeingStolen = "None",
}

local HEAR_DISTANCE = 70 -- Fx дальше этого (от камеры) не озвучиваем
local REPEAT_GAP = 0.25 -- одно и то же событие не чаще

local Sounds = {}

local templates: { [string]: Sound } = {}
local lastPlayed: { [string]: number } = {}
local folder: Folder? = nil

local function template(name: string): Sound?
	local existing = templates[name]
	if existing then
		return existing
	end
	local info = SOUNDS[name]
	if not info then
		return nil
	end
	if not folder then
		local newFolder = Instance.new("Folder")
		newFolder.Name = "LocalSounds"
		newFolder.Parent = SoundService
		folder = newFolder
	end
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = info.Id
	sound.Volume = info.Volume
	sound.PlaybackSpeed = info.Speed
	sound.Parent = folder
	templates[name] = sound
	return sound
end

-- Проиграть звук события (если звук включён и это событие не звучало только что)
function Sounds.Play(name: string)
	if Settings.Get("Sound") == false then
		return
	end
	local now = os.clock()
	if lastPlayed[name] and now - lastPlayed[name] < REPEAT_GAP then
		return
	end
	local sound = template(name)
	if not sound then
		return
	end
	lastPlayed[name] = now
	-- Копия, чтобы одинаковые звуки могли накладываться
	local copy = sound:Clone()
	copy.Parent = sound.Parent
	copy:Play()
	copy.Ended:Once(function()
		copy:Destroy()
	end)
	task.delay(6, function()
		if copy.Parent then
			copy:Destroy()
		end
	end)
end

-- Звук для уведомления: особый по ключу или по виду (success / error); info — без звука
function Sounds.Toast(kind: string?, special: string?)
	if special == "None" then
		return
	end
	if special then
		Sounds.Play(special)
	elseif kind == "success" then
		Sounds.Play("Success")
	elseif kind == "error" then
		Sounds.Play("Error")
	end
end

function Sounds.ForNotify(key: string): string?
	return NOTIFY_SOUNDS[key]
end

local function near(position: any): boolean
	if typeof(position) ~= "Vector3" then
		return false
	end
	local camera = workspace.CurrentCamera
	return camera ~= nil and (camera.CFrame.Position - position).Magnitude <= HEAR_DISTANCE
end

local function onFx(kind: any, data: any)
	if type(kind) ~= "string" or type(data) ~= "table" then
		return
	end
	local mine = data.UserId == player.UserId
	if kind == "Slap" and near(data.Position) then
		Sounds.Play("Slap")
	elseif kind == "Bought" and near(data.Position) then
		Sounds.Play("Bought")
	elseif kind == "Stolen" and near(data.Position) then
		Sounds.Play("Stolen")
	elseif kind == "Delivered" and mine then
		Sounds.Play("Delivered")
	elseif kind == "LuckyOpen" and (mine or near(data.Position)) then
		Sounds.Play("LuckyOpen")
	elseif kind == "Rebirth" and mine then
		Sounds.Play("Rebirth")
	elseif kind == "Pickup" and (mine or data.UserId == nil) then
		Sounds.Play("Pickup")
	end
end

function Sounds.Start()
	-- Клик любой кнопки UiKit.button
	UiKit.OnClick = function()
		Sounds.Play("Click")
	end
	Remotes:WaitForChild("Fx").OnClientEvent:Connect(onFx)
end

return Sounds
