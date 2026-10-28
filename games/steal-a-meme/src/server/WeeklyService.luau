-- Лимитированный мем недели (Config.Weekly): публикует ReplicatedStorage.WeeklyMeme / WeeklyEndsAt
-- и сообщает всем, когда неделя сменилась. Появление мема на дорожке — в ConveyorService.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(script.Parent.Remotes)

local WeeklyService = {}

local CHECK_INTERVAL = 60

local function update(announce: boolean)
	local meme, endsAt = Config.WeeklyMeme(os.time())
	local changed = ReplicatedStorage:GetAttribute("WeeklyMeme") ~= meme
	ReplicatedStorage:SetAttribute("WeeklyMeme", meme)
	ReplicatedStorage:SetAttribute("WeeklyEndsAt", endsAt)
	if changed and announce then
		for _, player in Players:GetPlayers() do
			Remotes.Notify:FireClient(player, "WeeklyNew", { Meme = meme }, "info")
		end
	end
end

function WeeklyService.Start()
	update(false)
	task.spawn(function()
		while true do
			task.wait(CHECK_INTERVAL)
			update(true)
		end
	end)
end

return WeeklyService
