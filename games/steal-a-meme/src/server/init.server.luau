-- Точка входа сервера. Порядок: сервисы -> карта -> игроки.
local Players = game:GetService("Players")

local DataService = require(script.DataService)
local MapBuilder = require(script.MapBuilder)
local PlotService = require(script.PlotService)
local StealService = require(script.StealService)
local ConveyorService = require(script.ConveyorService)
local EventService = require(script.EventService)
local ShopService = require(script.ShopService)
local RewardService = require(script.RewardService)
local LeaderboardService = require(script.LeaderboardService)

DataService.Start()
local world = MapBuilder.Build()
PlotService.Start(world.Plots)
StealService.Start()
ConveyorService.Start(MapBuilder.CarpetStart, MapBuilder.CarpetEnd)
EventService.Start(MapBuilder.HALF_X, MapBuilder.HALF_Z)
RewardService.Start()
LeaderboardService.Start(world.Leaderboards)

-- Связи между сервисами (без циклических require)
StealService.OnMonsterSlap = EventService.HitMonster
ShopService.OnSummonGod = function()
	ConveyorService.SummonGod()
end
ShopService.OnSlipperChanged = function(player)
	for _, container in { player:FindFirstChildOfClass("Backpack"), player.Character } do
		local old = container and container:FindFirstChild("Slipper")
		if old then
			old:Destroy()
		end
	end
	StealService.GiveSlipper(player)
end
ShopService.Start()

-- Каждый новый персонаж (данные уже загружены): тапок и перенос на свою базу
local function setupCharacter(player: Player, character: Model)
	task.spawn(StealService.OnCharacter, player, character)
	local plot = PlotService.GetPlot(player)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if plot and root and character.Parent then
		task.wait() -- даём движку закончить появление, иначе позиция перезапишется точкой спавна
		character:PivotTo(PlotService.SpawnPoint(plot))
	end
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		if player:GetAttribute("DataLoaded") then
			setupCharacter(player, character)
		end
	end)

	PlotService.Assign(player)
	ShopService.CheckPasses(player) -- до загрузки базы: от геймпассов зависят слоты и доход
	DataService.Load(player)
	if not player.Parent or not DataService.IsLoaded(player) then
		return
	end
	PlotService.LoadPlayer(player)
	RewardService.OnLoaded(player)
	player:SetAttribute("DataLoaded", true)

	-- Персонаж мог появиться раньше, чем загрузились данные.
	if player.Character then
		setupCharacter(player, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	-- Сначала возвращаем всё «в пути» по местам, потом освобождаем базу и сохраняем.
	-- База освобождается ДО сохранения: Save ждёт DataStore, и за это время вор успел бы
	-- начать новую кражу с базы уходящего игрока (а его данные потом пропадут из памяти).
	StealService.OnPlayerRemoving(player)
	EventService.OnPlayerRemoving(player)
	PlotService.Release(player)
	DataService.Release(player)
end)
