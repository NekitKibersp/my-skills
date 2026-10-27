-- Точка входа сервера. Порядок: сервисы -> карта -> игроки.
local Players = game:GetService("Players")

local DataService = require(script.DataService)
-- local MapBuilder = require(script.MapBuilder)
-- local GameService = require(script.GameService)

DataService.Start()
-- GameService.Start()
-- MapBuilder.Build({ ... колбэки сервисов ... })

-- Вызывается для каждого нового персонажа, когда данные игрока уже загружены:
-- выдать инструменты, поставить на чекпоинт и т.п.
local function setupCharacter(player: Player, character: Model)
	local _ = player
	local _ = character
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		if DataService.IsLoaded(player) then
			setupCharacter(player, character)
		end
	end)

	DataService.Load(player)

	-- Персонаж мог появиться раньше, чем загрузились данные.
	if player.Character and DataService.IsLoaded(player) then
		setupCharacter(player, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end
