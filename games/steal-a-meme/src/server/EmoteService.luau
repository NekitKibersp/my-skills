-- Эмоции: клиент просит сыграть эмоцию, сервер проверяет и рассылает всем Fx "Emote".
-- Саму анимацию (процедурную, Config.Emotes[*].Proc) и эмодзи над головой рисует каждый клиент.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Remotes = require(script.Parent.Remotes)

local EmoteService = {}

local lastEmoteAt: { [Player]: number } = {}

local function onEmote(player: Player, emoteId: unknown)
	if typeof(emoteId) ~= "string" or #emoteId > 50 then
		return
	end
	local emote = Config.GetEmote(emoteId)
	if not emote or not DataService.IsLoaded(player) then
		return
	end
	if emote.Pass and player:GetAttribute("Pass_" .. emote.Pass) ~= true then
		return
	end
	local t = os.clock()
	-- Небольшой допуск: клиент считает ту же перезарядку по своим часам, и запрос
	-- «ровно через EmoteCooldown» из-за пинга не должен молча теряться
	if t - (lastEmoteAt[player] or -math.huge) < Config.EmoteCooldown - 0.3 then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 or not (character :: Model):FindFirstChild("HumanoidRootPart") then
		return
	end
	lastEmoteAt[player] = t
	Remotes.Fx:FireAllClients("Emote", { UserId = player.UserId, Emote = emoteId })
end

function EmoteService.OnPlayerRemoving(player: Player)
	lastEmoteAt[player] = nil
end

function EmoteService.Start()
	Remotes.Emote.OnServerEvent:Connect(onEmote)
end

return EmoteService
