-- Друзья, группа и избранное — только клиентские окна Roblox (бонусы считает сервер):
--  * Invite — SocialService:PromptGameInvite (друзья на сервере дают FriendBoost);
--  * JoinGroup — GroupService:PromptJoinAsync(Config.Social.GroupId), затем Remotes.CheckGroup;
--  * через Config.Social.FavoritePromptAfter секунд игры (раз за сессию) — «Добавить в избранное».
-- Все вызовы в pcall: в Studio и на части устройств эти окна недоступны.
local AvatarEditorService = game:GetService("AvatarEditorService")
local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Locale = require(Shared:WaitForChild("Locale"))
local Util = require(script.Parent:WaitForChild("Util"))

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Social = {}

-- Суммарный бонус дохода от друзей и группы, в процентах (для строки HUD)
function Social.BoostPercent(): number
	local boost = Util.num(player, "FriendBoost")
	if Util.bool(player, "InGroup") and Config.Social.GroupId ~= 0 then
		boost += Config.Social.GroupBoost
	end
	return math.floor(boost * 100 + 0.5)
end

-- Показывать ли кнопку «Вступить в группу»
function Social.CanJoinGroup(): boolean
	return Config.Social.GroupId ~= 0 and not Util.bool(player, "InGroup")
end

function Social.Invite(toast: (string, string?) -> ())
	task.spawn(function()
		local okCheck, canSend = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
		if not okCheck or not canSend then
			toast(Locale.T("SocialInviteUnavailable"), "error")
			return
		end
		local ok = pcall(SocialService.PromptGameInvite, SocialService, player)
		if not ok then
			toast(Locale.T("SocialInviteUnavailable"), "error")
		end
	end)
end

function Social.JoinGroup()
	if not Social.CanJoinGroup() then
		return
	end
	task.spawn(function()
		pcall(GroupService.PromptJoinAsync, GroupService, Config.Social.GroupId)
		-- Вступил или нет — проверяет сервер (IsInGroup), клиент только просит перепроверить
		local remote = Remotes:FindFirstChild("CheckGroup")
		if remote and remote:IsA("RemoteEvent") then
			remote:FireServer()
		end
	end)
end

function Social.Start()
	-- Раз за сессию, после N секунд игры: окно «Добавить игру в избранное»
	task.delay(Config.Social.FavoritePromptAfter, function()
		pcall(function()
			AvatarEditorService:PromptSetFavorite(game.PlaceId, Enum.AvatarItemType.Asset, true)
		end)
	end)
end

return Social
