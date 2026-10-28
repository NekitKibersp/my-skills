-- Точка входа сервера. Порядок: сервисы -> карта -> игроки.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local DataService = require(script.DataService)
local MapBuilder = require(script.MapBuilder)
local PlotService = require(script.PlotService)
local StealService = require(script.StealService)
local ConveyorService = require(script.ConveyorService)
local EventService = require(script.EventService)
local ShopService = require(script.ShopService)
local RewardService = require(script.RewardService)
local LeaderboardService = require(script.LeaderboardService)
local ItemService = require(script.ItemService)
local QuestService = require(script.QuestService)
local AdminEventService = require(script.AdminEventService)
local TradeService = require(script.TradeService)
local DefenseService = require(script.DefenseService)
local EmoteService = require(script.EmoteService)
local Remotes = require(script.Remotes)

-- Сезон по дате (UTC): от него зависят ночные мемы, мутации, декор и цвет монстра
local today = os.date("!*t")
ReplicatedStorage:SetAttribute("Season", Config.SeasonFor(today.month, today.day))

DataService.Start()
local world = MapBuilder.Build(ReplicatedStorage:GetAttribute("Season"))
PlotService.Start(world.Plots)
StealService.Start()
ItemService.Start()
ConveyorService.Start(MapBuilder.CarpetStart, MapBuilder.CarpetEnd)
EventService.Start(MapBuilder.HALF_X, MapBuilder.HALF_Z)
RewardService.Start()
QuestService.Start()
-- Колбэк нужен до Start: если сервер стартует посреди слота расписания, ивент запускается сразу
AdminEventService.OnSpawnRarity = ConveyorService.SpawnRarity
AdminEventService.Start()
TradeService.Start()
DefenseService.Start()
EmoteService.Start()
LeaderboardService.Start(world.Leaderboards)

-- Связи между сервисами (без циклических require)
ItemService.OnMonsterHit = EventService.HitMonster
ShopService.OnSummonGod = function()
	ConveyorService.SummonGod()
end
-- Геймпассы предметов (золотой тапок, конфетти-пушка) и предмет из календаря — перевыдаём рюкзак
ShopService.OnToolsChanged = ItemService.RefreshPasses
RewardService.OnItemGranted = ItemService.RefreshPasses
ShopService.OnMemeRain = function(player)
	return AdminEventService.StartEvent("MemeRain", Config.AdminEvents.MemeRainDuration, player)
end
ShopService.Start()

-- Каждый новый персонаж (данные уже загружены): тапок и перенос на свою базу
local function setupCharacter(player: Player, character: Model)
	task.spawn(StealService.OnCharacter, player, character)
	ItemService.OnCharacter(player, character)
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
	ItemService.OnLoaded(player)
	QuestService.OnLoaded(player)
	DefenseService.OnLoaded(player)
	player:SetAttribute("DataLoaded", true)

	-- Персонаж мог появиться раньше, чем загрузились данные.
	if player.Character then
		setupCharacter(player, player.Character)
	end
end

Remotes.TutorialDone.OnServerEvent:Connect(function(player)
	if DataService.IsLoaded(player) and DataService.Get(player, "TutorialDone") == 0 then
		DataService.Set(player, "TutorialDone", 1)
	end
end)

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
	ItemService.OnPlayerRemoving(player)
	TradeService.OnPlayerRemoving(player)
	DefenseService.OnPlayerRemoving(player)
	EmoteService.OnPlayerRemoving(player)
	PlotService.Release(player)
	DataService.Release(player)
end)
