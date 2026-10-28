-- Базы игроков: выдача базы, мемы в слотах, доход в секунду, замок, страж, Индекс, перерождения,
-- этажи (барьеры закрытых этажей) и открытие Lucky Blocks.
-- Мемы на базе хранятся в DataService (таблица Memes); модели в мире — их отображение.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local MemeFactory = require(script.Parent.MemeFactory)
local Remotes = require(script.Parent.Remotes)
local Hooks = require(script.Parent.Hooks)
local AnalyticsService = require(script.Parent.AnalyticsService)

local PlotService = {}

type Entry = { Id: string, Mut: string, Viral: boolean, Slot: number }

local plots: { Model } = {}
local plotOf: { [Player]: Model } = {}
local models: { [Player]: { [number]: Model } } = {} -- слот -> модель на базе
local away: { [Player]: { [number]: boolean } } = {} -- слоты, чьих мемов сейчас несут (вор или Смайлик)

-- Колбэки, которые выставляет init.server (чтобы не было циклических require)
PlotService.OnStealPrompt = nil :: ((thief: Player, owner: Player, slot: number, prompt: ProximityPrompt) -> ())?
-- Мем выставлен в обмен — его нельзя продать, слить, украсть (выставляет TradeService)
PlotService.IsTradeLocked = nil :: ((player: Player, slot: number) -> boolean)?
-- Награды перерождения (спины, предмет): (player, rewards из Config.Rebirth.Tiers[n].Rewards).
-- Выставляет FoundationService — через Grant, который сам требует PlotService.
PlotService.OnRebirthRewards = nil :: ((player: Player, rewards: any) -> ())?

-- Порядок заполнения слотов: сначала нижние этажи (слоты геймпасса — на 1-м этаже), внутри этажа по номеру
local SLOT_ORDER: { number } = {}
for slot = 1, Config.AbsoluteMaxSlots do
	table.insert(SLOT_ORDER, slot)
end
table.sort(SLOT_ORDER, function(a, b)
	local floorA, floorB = Config.FloorOfSlot(a), Config.FloorOfSlot(b)
	if floorA ~= floorB then
		return floorA < floorB
	end
	return a < b
end)

local LUCKY_CHECK_INTERVAL = 1 -- сек: как часто проверять, не пора ли открыть Lucky Block

-- Мем сейчас недоступен для действий: его несут или он в обмене
function PlotService.IsBusy(player: Player, slot: number): boolean
	if PlotService.IsAway(player, slot) then
		return true
	end
	return PlotService.IsTradeLocked ~= nil and PlotService.IsTradeLocked(player, slot)
end

local function now(): number
	return workspace:GetServerTimeNow()
end

function PlotService.GetPlot(player: Player): Model?
	return plotOf[player]
end

function PlotService.GetOwner(plot: Model): Player?
	local userId = plot:GetAttribute("OwnerUserId")
	if not userId or userId == 0 then
		return nil
	end
	return Players:GetPlayerByUserId(userId)
end

function PlotService.AllPlots(): { Model }
	return plots
end

function PlotService.IsLocked(plot: Model): boolean
	return (plot:GetAttribute("LockedUntil") or 0) > now()
end

-- Находится ли точка внутри базы (по полу, с запасом по высоте)
function PlotService.InPlot(plot: Model, position: Vector3): boolean
	local floor = plot:FindFirstChild("Floor") :: BasePart
	local localPos = floor.CFrame:PointToObjectSpace(position)
	local size = floor.Size
	-- По высоте — все этажи и прыжок над верхним
	local top = Config.Plot.Floors[#Config.Plot.Floors].Height + 22
	return math.abs(localPos.X) <= size.X / 2 and math.abs(localPos.Z) <= size.Z / 2 and localPos.Y > -5 and localPos.Y < top
end

-- Точка перед входом в базу (сюда выталкивает с закрытой базы)
function PlotService.OutsidePoint(plot: Model): CFrame
	local floor = plot:FindFirstChild("Floor") :: BasePart
	return floor.CFrame * CFrame.new(0, 4, -floor.Size.Z / 2 - 8)
end

function PlotService.SpawnPoint(plot: Model): CFrame
	local spawnPart = plot:FindFirstChild("Spawn") :: BasePart
	local floor = plot:FindFirstChild("Floor") :: BasePart
	-- лицом к дорожке
	return CFrame.lookAt(spawnPart.Position + Vector3.new(0, 3, 0), spawnPart.Position + Vector3.new(0, 3, 0) + floor.CFrame.LookVector)
end

local function slotPart(plot: Model, slot: number): BasePart
	return (plot:FindFirstChild("Slots") :: Folder):FindFirstChild("Slot" .. slot) :: BasePart
end

-- Точка, где стоит мем в слоте (низ модели), лицом к дорожке
function PlotService.SlotCFrame(plot: Model, slot: number): CFrame
	local part = slotPart(plot, slot)
	local floor = plot:FindFirstChild("Floor") :: BasePart
	local position = part.Position + Vector3.new(0, part.Size.X / 2, 0)
	return CFrame.lookAt(position, position + floor.CFrame.LookVector)
end

function PlotService.MaxSlots(player: Player): number
	return Config.MaxSlots(DataService.Get(player, "Rebirths"), player:GetAttribute("Pass_ExtraSlots") == true)
end

-- Можно ли ставить мема в слот (этаж открыт; слоты геймпасса — с геймпассом)
function PlotService.SlotAvailable(player: Player, slot: number): boolean
	return Config.SlotAvailable(slot, DataService.Get(player, "Rebirths"), player:GetAttribute("Pass_ExtraSlots") == true)
end

function PlotService.FloorsUnlocked(player: Player): number
	return Config.FloorsUnlocked(DataService.Get(player, "Rebirths"))
end

-- Случайный обычный мем редкости: без сезонных, лимитированных, эксклюзивов и Lucky Blocks
function PlotService.RandomMeme(rarity: string): string?
	local pool = {}
	for _, creature in Config.Creatures do
		if creature.Rarity == rarity and not creature.Event and not creature.Limited and not creature.Exclusive and not creature.Lucky then
			table.insert(pool, creature.Id)
		end
	end
	if #pool == 0 then
		return nil
	end
	return pool[math.random(1, #pool)]
end

function PlotService.GetEntries(player: Player): { Entry }
	return DataService.GetTable(player, "Memes")
end

function PlotService.GetEntry(player: Player, slot: number): Entry?
	for _, entry in PlotService.GetEntries(player) do
		if entry.Slot == slot then
			return entry
		end
	end
	return nil
end

function PlotService.FreeSlot(player: Player): number?
	if not plotOf[player] then
		return nil -- нет базы (сервер переполнен) — ставить некуда
	end
	local used = {}
	for _, entry in PlotService.GetEntries(player) do
		used[entry.Slot] = true
	end
	for _, slot in SLOT_ORDER do
		if not used[slot] and PlotService.SlotAvailable(player, slot) then
			return slot
		end
	end
	return nil
end

-- Сколько доступных слотов свободно
function PlotService.FreeSlotCount(player: Player): number
	local used = {}
	for _, entry in PlotService.GetEntries(player) do
		used[entry.Slot] = true
	end
	local free = 0
	for slot = 1, Config.AbsoluteMaxSlots do
		if not used[slot] and PlotService.SlotAvailable(player, slot) then
			free += 1
		end
	end
	return free
end

function PlotService.IsAway(player: Player, slot: number): boolean
	return away[player] ~= nil and away[player][slot] == true
end

function PlotService.SetAway(player: Player, slot: number, value: boolean)
	if away[player] then
		away[player][slot] = if value then true else nil
	end
	PlotService.RefreshIncome(player)
end

function PlotService.GetModel(player: Player, slot: number): Model?
	return models[player] and models[player][slot]
end

-- Забрать модель со слота (для переноски). Модель больше не числится на базе.
function PlotService.DetachModel(player: Player, slot: number): Model?
	local model = PlotService.GetModel(player, slot)
	if model then
		models[player][slot] = nil
	end
	return model
end

-- ===== Доход =====

function PlotService.IncomeOf(player: Player): number
	if not DataService.IsLoaded(player) then
		return 0
	end
	local trending = ReplicatedStorage:GetAttribute("TrendingId")
	local total = 0
	for _, entry in PlotService.GetEntries(player) do
		if not PlotService.IsAway(player, entry.Slot) then
			local income = Config.BaseIncome(entry.Id, entry.Mut, entry.Viral)
			if entry.Id == trending then
				income *= Config.Trend.Mult
			end
			total += income
		end
	end
	total *= Config.IncomeMult(DataService.Get(player, "Rebirths"))
	if player:GetAttribute("Pass_VIP") then
		total *= Config.VipIncomeMult
	end
	total *= 1 + (player:GetAttribute("IndexCount") or 0) * Config.IndexBonusPerEntry
	total *= ReplicatedStorage:GetAttribute("EventIncomeMult") or 1 -- «Двойные деньги» админ-ивента
	total *= 1 + (player:GetAttribute("FriendBoost") or 0) + (if player:GetAttribute("InGroup") then Config.Social.GroupBoost else 0) -- друзья и группа (SocialService)
	return total
end

function PlotService.RefreshIncome(player: Player)
	if DataService.IsLoaded(player) then
		player:SetAttribute("Income", PlotService.IncomeOf(player))
	end
end

function PlotService.RefreshAllIncome()
	for player in plotOf do
		PlotService.RefreshIncome(player)
	end
end

function PlotService.AddCoins(player: Player, amount: number)
	DataService.Increment(player, "Coins", amount)
	if amount > 0 then
		DataService.Increment(player, "TotalEarned", amount)
	end
end

-- ===== Индекс =====

local function syncIndex(player: Player)
	local keys = {}
	for key in DataService.GetTable(player, "Index") do
		table.insert(keys, key)
	end
	player:SetAttribute("IndexJson", HttpService:JSONEncode(keys))
	player:SetAttribute("IndexCount", #keys)
end

local function discover(player: Player, id: string, mutationId: string)
	local creature = Config.GetCreature(id)
	if not creature or creature.Lucky then
		return -- Lucky Blocks в Индекс не попадают
	end
	local index = DataService.GetTable(player, "Index")
	local key = Config.IndexKey(id, mutationId)
	if not index[key] then
		index[key] = true
		syncIndex(player)
		Remotes.Notify:FireClient(player, "NewIndex", { Meme = id }, "success")
	end
end

-- ===== Модели на базе =====

local function setupPlacedModel(player: Player, model: Model, slot: number)
	model:SetAttribute("State", "Placed")
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("Slot", slot)
	model:SetAttribute("Floor", Config.FloorOfSlot(slot))
	-- Lucky Block: таймер открытия начинается заново при каждой расстановке
	-- (покупка, возврат после кражи, доставка вору, обмен, перезаход)
	local creature = Config.GetCreature(model:GetAttribute("CreatureId"))
	model:SetAttribute("OpensAt", if creature and creature.Lucky then now() + Config.LuckyBlocks.OpenTime else nil)

	local steal = MemeFactory.AddPrompt(model, "StealPrompt", "Steal", Config.Steal.HoldDuration)
	steal.Triggered:Connect(function(thief)
		if PlotService.OnStealPrompt then
			PlotService.OnStealPrompt(thief, player, slot, steal)
		end
	end)

	local sell = MemeFactory.AddPrompt(model, "SellPrompt", "Sell", 0.6)
	sell.Triggered:Connect(function(who)
		if who == player then
			PlotService.Sell(player, slot)
		end
	end)

	local merge = MemeFactory.AddPrompt(model, "MergePrompt", "Make VIRAL", 0.8)
	merge.Triggered:Connect(function(who)
		if who == player then
			PlotService.Merge(player, slot)
		end
	end)
end

-- Поставить модель мема на слот (новую или вернувшуюся после кражи)
function PlotService.PlaceModel(player: Player, slot: number, model: Model)
	local plot = plotOf[player]
	if not plot then
		model:Destroy()
		return
	end
	MemeFactory.Detach(model)
	for _, prompt in (model.PrimaryPart :: BasePart):GetChildren() do
		if prompt:IsA("ProximityPrompt") then
			prompt:Destroy()
		end
	end
	model:PivotTo(PlotService.SlotCFrame(plot, slot) * CFrame.new(0, MemeFactory.BodyOffset(model), 0))
	setupPlacedModel(player, model, slot)
	model.Parent = plot:FindFirstChild("Memes")
	models[player][slot] = model
end

local function spawnModel(player: Player, entry: Entry): Model
	local plot = plotOf[player]
	local model = MemeFactory.Create(entry.Id, entry.Mut, entry.Viral, PlotService.SlotCFrame(plot, entry.Slot))
	PlotService.PlaceModel(player, entry.Slot, model)
	return model
end

-- Вернуть унесённого мема на его слот. Если модель успела уничтожиться
-- (например, упала за карту вместе с вором), собираем её заново по записи.
function PlotService.ReturnModel(player: Player, slot: number, model: Model)
	local entry = PlotService.GetEntry(player, slot)
	if not entry then
		model:Destroy()
		return
	end
	if model.PrimaryPart and model.PrimaryPart:IsDescendantOf(game) then
		PlotService.PlaceModel(player, slot, model)
	else
		model:Destroy()
		spawnModel(player, entry)
	end
end

-- Барьеры закрытых этажей: открытый этаж — барьер невидим и проходим (floorsUnlocked = 1 — свободная база)
local function updateFloors(plot: Model, floorsUnlocked: number)
	plot:SetAttribute("FloorsUnlocked", floorsUnlocked)
	for floor = 2, #Config.Plot.Floors do
		local barrier = plot:FindFirstChild("FloorLock" .. floor) :: BasePart?
		if barrier then
			local open = floor <= floorsUnlocked
			barrier.CanCollide = not open
			barrier.CanQuery = not open
			barrier.Transparency = if open then 1 else 0.3
			local gui = barrier:FindFirstChild("LockGui") :: BillboardGui?
			if gui then
				gui.Enabled = not open
			end
		end
	end
end

local function updateSlotsInfo(player: Player)
	local plot = plotOf[player]
	if not plot then
		return
	end
	for slot = 1, Config.AbsoluteMaxSlots do
		local part = slotPart(plot, slot)
		local unlocked = PlotService.SlotAvailable(player, slot)
		part:SetAttribute("Unlocked", unlocked)
		part.Transparency = if unlocked then 0 else 0.75
		part.Color = if unlocked then Color3.fromRGB(90, 90, 110) else Color3.fromRGB(40, 40, 45)
	end
	updateFloors(plot, PlotService.FloorsUnlocked(player))
	player:SetAttribute("SlotsUsed", #PlotService.GetEntries(player))
	player:SetAttribute("MaxSlots", PlotService.MaxSlots(player))
end
PlotService.UpdateSlotsInfo = updateSlotsInfo

-- Добавить мема игроку. walkFrom — откуда мем «идёт» на базу (покупка с дорожки).
-- Возвращает запись или nil, если нет места.
function PlotService.AddMeme(player: Player, id: string, mutationId: string, viral: boolean, walkFrom: CFrame?): Entry?
	if not plotOf[player] or not DataService.IsLoaded(player) then
		return nil
	end
	local slot = PlotService.FreeSlot(player)
	if not slot then
		return nil
	end
	local entry: Entry = { Id = id, Mut = mutationId, Viral = viral, Slot = slot }
	table.insert(PlotService.GetEntries(player), entry)
	discover(player, id, mutationId)

	local model = spawnModel(player, entry)
	if walkFrom then
		-- Короткая анимация: мем летит с дорожки на свой слот
		local target = model:GetPivot()
		local holder = Instance.new("CFrameValue")
		holder.Value = walkFrom
		model:PivotTo(walkFrom)
		holder.Changed:Connect(function(value)
			-- Мема могли украсть прямо в полёте: тогда двигать его нельзя (утащит вора вместе с ним)
			if model.Parent and PlotService.GetModel(player, entry.Slot) == model then
				model:PivotTo(value)
			end
		end)
		local tween = TweenService:Create(holder, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = target })
		tween.Completed:Connect(function()
			holder:Destroy()
		end)
		tween:Play()
	end

	updateSlotsInfo(player)
	PlotService.RefreshIncome(player)
	return entry
end

-- Убрать мема из данных (продажа, кража, слияние). Модель уничтожается, если она ещё на базе.
function PlotService.RemoveEntry(player: Player, slot: number): Entry?
	local entries = PlotService.GetEntries(player)
	for i, entry in entries do
		if entry.Slot == slot then
			table.remove(entries, i)
			local model = PlotService.DetachModel(player, slot)
			if model then
				model:Destroy()
			end
			if away[player] then
				away[player][slot] = nil
			end
			updateSlotsInfo(player)
			PlotService.RefreshIncome(player)
			return entry
		end
	end
	return nil
end

function PlotService.Sell(player: Player, slot: number)
	if PlotService.IsBusy(player, slot) then
		return
	end
	local entry = PlotService.GetEntry(player, slot)
	if not entry then
		return
	end
	local refund = math.floor(Config.PriceOf(entry.Id, entry.Mut) * (if entry.Viral then Config.Viral.Count else 1) * Config.Steal.SellRefund)
	PlotService.RemoveEntry(player, slot)
	PlotService.AddCoins(player, refund)
	Remotes.Notify:FireClient(player, "Sold", { Meme = entry.Id, Coins = refund }, "success")
end

function PlotService.Merge(player: Player, slot: number)
	local entry = PlotService.GetEntry(player, slot)
	if not entry or entry.Viral or PlotService.IsBusy(player, slot) then
		return
	end
	local creature = Config.GetCreature(entry.Id)
	if creature and creature.Lucky then
		return -- Lucky Blocks не сливаются
	end
	local same = {}
	for _, other in PlotService.GetEntries(player) do
		if other.Id == entry.Id and other.Mut == entry.Mut and not other.Viral and not PlotService.IsBusy(player, other.Slot) then
			table.insert(same, other.Slot)
		end
	end
	if #same < Config.Viral.Count then
		Remotes.Notify:FireClient(player, "NeedMoreToMerge", { Count = Config.Viral.Count }, "error")
		return
	end
	-- Оставляем выбранный слот, остальные сливаются в него
	local removed = 0
	for _, otherSlot in same do
		if otherSlot ~= slot and removed < Config.Viral.Count - 1 then
			PlotService.RemoveEntry(player, otherSlot)
			removed += 1
		end
	end
	local position = (PlotService.GetModel(player, slot) :: Model):GetPivot().Position
	PlotService.RemoveEntry(player, slot)
	-- Возвращаем в тот же слот: он освободился и он минимальный не обязательно, поэтому ставим напрямую
	local viralEntry: Entry = { Id = entry.Id, Mut = entry.Mut, Viral = true, Slot = slot }
	table.insert(PlotService.GetEntries(player), viralEntry)
	spawnModel(player, viralEntry)
	updateSlotsInfo(player)
	PlotService.RefreshIncome(player)
	Remotes.Fx:FireAllClients("Merged", { Position = position })
	Remotes.Notify:FireClient(player, "Merged", { Meme = entry.Id, Mult = Config.Viral.Mult }, "success")
	Hooks.Fire(player, "Merge", 1)
end

-- ===== Lucky Blocks =====

-- Открыть Lucky Block в слоте: на его месте появляется случайный мем редкости LuckyRarity
-- (мутация блока сохраняется)
local function openLucky(player: Player, slot: number, model: Model)
	local entry = PlotService.GetEntry(player, slot)
	local creature = entry and Config.GetCreature(entry.Id)
	if not entry or not creature or not creature.Lucky then
		model:SetAttribute("OpensAt", nil)
		return
	end
	local id = PlotService.RandomMeme(creature.LuckyRarity or creature.Rarity)
	if not id then
		model:SetAttribute("OpensAt", nil)
		warn("[PlotService] Нет мемов редкости для Lucky Block", creature.Id)
		return
	end
	local position = model:GetPivot().Position
	PlotService.RemoveEntry(player, slot)
	local opened: Entry = { Id = id, Mut = entry.Mut, Viral = false, Slot = slot }
	table.insert(PlotService.GetEntries(player), opened)
	spawnModel(player, opened)
	discover(player, id, opened.Mut)
	updateSlotsInfo(player)
	PlotService.RefreshIncome(player)
	Remotes.Fx:FireAllClients("LuckyOpen", { Position = position, Meme = id, UserId = player.UserId })
	Remotes.Notify:FireClient(player, "LuckyOpened", { Meme = id }, "success")
end

-- Открыть все Lucky Blocks, чьё время пришло (несомые и выставленные в обмен ждут)
local function luckyStep()
	local t = now()
	local due = {}
	for player, slotModels in models do
		if not DataService.IsLoaded(player) then
			continue
		end
		for slot, model in slotModels do
			local opensAt = model:GetAttribute("OpensAt")
			if type(opensAt) == "number" and opensAt <= t and not PlotService.IsBusy(player, slot) then
				table.insert(due, { player, slot, model })
			end
		end
	end
	-- Открываем после обхода: открытие меняет таблицу моделей
	for _, item in due do
		local player, slot, model = item[1], item[2], item[3]
		if PlotService.GetModel(player, slot) == model then
			openLucky(player, slot, model)
		end
	end
end

-- ===== Замок =====

function PlotService.Lock(player: Player, duration: number?, ignoreCooldown: boolean?): boolean
	local plot = plotOf[player]
	if not plot then
		return false
	end
	local t = now()
	if PlotService.IsLocked(plot) then
		if ignoreCooldown then
			plot:SetAttribute("LockedUntil", plot:GetAttribute("LockedUntil") + (duration or Config.Plot.LockDuration))
			plot:SetAttribute("LockCooldownUntil", plot:GetAttribute("LockedUntil") + Config.Plot.LockCooldown)
			return true
		end
		return false
	end
	local cooldownUntil = plot:GetAttribute("LockCooldownUntil") or 0
	if not ignoreCooldown and cooldownUntil > t then
		Remotes.Notify:FireClient(player, "LockCooldown", { Seconds = math.ceil(cooldownUntil - t) }, "error")
		return false
	end
	local lockedUntil = t + (duration or Config.Plot.LockDuration)
	plot:SetAttribute("LockedUntil", lockedUntil)
	plot:SetAttribute("LockCooldownUntil", lockedUntil + Config.Plot.LockCooldown)
	Remotes.Notify:FireClient(player, "Locked", { Seconds = math.floor(lockedUntil - t) }, "success")
	Hooks.Fire(player, "Lock", 1)
	return true
end

-- ===== Страж =====

function PlotService.RefreshGuard(player: Player)
	local plot = plotOf[player]
	if not plot then
		return
	end
	local existing = plot:FindFirstChild("Guard")
	if existing then
		existing:Destroy()
	end
	local level = DataService.Get(player, "GuardLevel")
	if level <= 0 then
		return
	end
	local floor = plot:FindFirstChild("Floor") :: BasePart
	local spot = floor:FindFirstChild("GuardSpot") :: Attachment
	local base = CFrame.lookAt(spot.WorldPosition, spot.WorldPosition + floor.CFrame.LookVector)
	local guard = MemeFactory.Create("SwordKitten", "None", false, base)
	guard.Name = "Guard"
	-- Страж — не мем на продажу: снимаем тег, чтобы клиент не рисовал ему ценник
	game:GetService("CollectionService"):RemoveTag(guard, "Meme")
	guard:SetAttribute("GuardLevel", level)
	local sword = Instance.new("Part")
	sword.Name = "Sword"
	sword.Size = Vector3.new(0.4, 5, 0.9)
	sword.Color = Color3.fromRGB(220, 230, 255)
	sword.Material = Enum.Material.Metal
	local body = guard.PrimaryPart :: BasePart
	sword.CFrame = body.CFrame * CFrame.new(body.Size.X / 2 + 0.6, 0.5, 0) * CFrame.Angles(math.rad(-20), 0, 0)
	sword.Anchored = false
	sword.CanCollide = false
	sword.Massless = true
	local weldConstraint = Instance.new("WeldConstraint")
	weldConstraint.Part0 = body
	weldConstraint.Part1 = sword
	weldConstraint.Parent = sword
	sword.Parent = guard
	guard.Parent = plot
end

function PlotService.UpgradeGuard(player: Player): (boolean, string)
	local level = DataService.Get(player, "GuardLevel")
	local nextLevel = Config.Guard[level + 1]
	if not nextLevel then
		return false, "GuardMax"
	end
	if DataService.Get(player, "Coins") < nextLevel.Price then
		Remotes.Notify:FireClient(player, "NotEnoughCash", { Price = nextLevel.Price }, "error")
		return false, "NotEnoughCash"
	end
	DataService.Increment(player, "Coins", -nextLevel.Price)
	AnalyticsService.Economy(player, "Sink", nextLevel.Price, "Gameplay", "Guard" .. (level + 1))
	DataService.Set(player, "GuardLevel", level + 1)
	PlotService.RefreshGuard(player)
	Remotes.Notify:FireClient(player, "GuardUpgraded", { Level = level + 1 }, "success")
	return true, "GuardUpgraded"
end

-- ===== Перерождение =====

-- Сколько мемов на базе подходят под требование. Как у клиента (RebirthWindow.Status): каждое
-- требование считается отдельно по всем мемам базы, кроме унесённых (вор/Смайлик) — мем в обмене
-- стоит на базе и считается.
local function countMatching(player: Player, requirement: any): number
	local count = 0
	for _, entry in PlotService.GetEntries(player) do
		if not PlotService.IsAway(player, entry.Slot) and Config.MatchesRequirement(entry.Id, requirement) then
			count += 1
		end
	end
	return count
end

function PlotService.Rebirth(player: Player): (boolean, string)
	local rebirths = DataService.Get(player, "Rebirths")
	local cost = Config.RebirthCost(rebirths)
	if DataService.Get(player, "Coins") < cost then
		Remotes.Notify:FireClient(player, "RebirthNeed", { Price = cost }, "error")
		return false, "RebirthNeed"
	end
	-- Требования тира: нужные мемы должны стоять на базе (их не забирают)
	local tier = Config.RebirthTier(rebirths)
	if tier and tier.Requires then
		for _, requirement in tier.Requires do
			local need = requirement.Count or 1
			if countMatching(player, requirement) < need then
				if requirement.Id then
					Remotes.Notify:FireClient(player, "RebirthNeedMemeId", { Count = need, Meme = requirement.Id }, "error")
				else
					Remotes.Notify:FireClient(player, "RebirthNeedMemes", { Count = need, Rarity = requirement.Rarity }, "error")
				end
				return false, "RebirthNeedMemes"
			end
		end
	end
	local floorsBefore = PlotService.FloorsUnlocked(player)
	DataService.Set(player, "Coins", 0)
	AnalyticsService.Economy(player, "Sink", cost, "Gameplay", "Rebirth")
	DataService.Set(player, "Rebirths", rebirths + 1)
	local rewards = if tier then tier.Rewards else nil
	local onRewards = PlotService.OnRebirthRewards
	if rewards and onRewards then
		-- Ошибка выдачи наград не должна сорвать уже засчитанное перерождение
		local ok, err = pcall(onRewards, player, rewards)
		if not ok then
			warn("[PlotService] Награды перерождения:", err)
		end
	end
	-- Новый этаж (Rewards.Floor) открывается сам: этажи считаются по числу перерождений
	updateSlotsInfo(player)
	PlotService.RefreshIncome(player)
	Remotes.Fx:FireAllClients("Rebirth", { UserId = player.UserId })
	Remotes.Notify:FireClient(player, "Rebirthed", { Count = rebirths + 1 }, "success")
	local floorsAfter = PlotService.FloorsUnlocked(player)
	if floorsAfter > floorsBefore then
		Remotes.Notify:FireClient(player, "FloorUnlocked", { Floor = floorsAfter }, "success")
	end
	return true, "Rebirthed"
end

-- ===== Игроки =====

function PlotService.Assign(player: Player): Model?
	for _, plot in plots do
		if plot:GetAttribute("OwnerUserId") == 0 then
			plot:SetAttribute("OwnerUserId", player.UserId)
			plot:SetAttribute("OwnerName", player.DisplayName)
			plot:SetAttribute("LockedUntil", 0)
			plot:SetAttribute("LockCooldownUntil", 0)
			plotOf[player] = plot
			models[player] = {}
			away[player] = {}
			player:SetAttribute("Plot", plot:GetAttribute("Index"))
			return plot
		end
	end
	warn("[PlotService] Нет свободной базы для", player.Name, "— выставьте Max Players = 8")
	return nil
end

-- Вызывается после загрузки данных: расставить мемов, Индекс, стража
function PlotService.LoadPlayer(player: Player)
	if not plotOf[player] then
		return
	end
	local entries = PlotService.GetEntries(player)
	-- Мемы в недоступных слотах (геймпасс слотов пропал после возврата) остаются на своих местах:
	-- они видны, приносят доход и их можно украсть или продать — просто новых туда не поставить.
	if #entries == 0 and DataService.IsNew(player) then
		table.insert(entries, { Id = Config.StarterMeme, Mut = "None", Viral = false, Slot = 1 })
	end
	-- Старые сохранения (до этажей слоты шли подряд 1..25): мем на ещё закрытом этаже оказался бы
	-- за барьером — хозяин не смог бы его продать. Переносим такие мемы на свободные доступные слоты.
	local floorsUnlocked = PlotService.FloorsUnlocked(player)
	for _, entry in entries do
		if Config.FloorOfSlot(entry.Slot) > floorsUnlocked then
			local free = PlotService.FreeSlot(player)
			if free then
				entry.Slot = free
			end
		end
	end
	for _, entry in entries do
		spawnModel(player, entry)
		discover(player, entry.Id, entry.Mut)
	end
	syncIndex(player)
	updateSlotsInfo(player)
	PlotService.RefreshGuard(player)
	PlotService.RefreshIncome(player)
end

function PlotService.Release(player: Player)
	local plot = plotOf[player]
	if not plot then
		return
	end
	for _, model in models[player] or {} do
		model:Destroy()
	end
	local guard = plot:FindFirstChild("Guard")
	if guard then
		guard:Destroy()
	end
	for _, child in (plot:FindFirstChild("Memes") :: Folder):GetChildren() do
		child:Destroy()
	end
	plot:SetAttribute("OwnerUserId", 0)
	plot:SetAttribute("OwnerName", "")
	plot:SetAttribute("LockedUntil", 0)
	plot:SetAttribute("LockCooldownUntil", 0)
	for slot = 1, Config.AbsoluteMaxSlots do
		local part = slotPart(plot, slot)
		part:SetAttribute("Unlocked", false)
		part.Transparency = 0.6
	end
	updateFloors(plot, 1)
	plotOf[player] = nil
	models[player] = nil
	away[player] = nil
end

function PlotService.Start(builtPlots: { Model })
	plots = builtPlots

	for _, plot in plots do
		updateFloors(plot, 1)
	end

	for _, plot in plots do
		local prompt = plot:FindFirstChild("LockButton"):FindFirstChild("LockPrompt") :: ProximityPrompt
		prompt.Triggered:Connect(function(player)
			if plotOf[player] == plot then
				PlotService.Lock(player)
			end
		end)
	end

	Remotes.LockBase.OnServerEvent:Connect(function(player)
		if DataService.IsLoaded(player) then
			PlotService.Lock(player)
		end
	end)
	Remotes.Rebirth.OnServerInvoke = function(player)
		if not DataService.IsLoaded(player) then
			return false, "NotLoaded"
		end
		return PlotService.Rebirth(player)
	end
	Remotes.UpgradeGuard.OnServerInvoke = function(player)
		if not DataService.IsLoaded(player) then
			return false, "NotLoaded"
		end
		return PlotService.UpgradeGuard(player)
	end

	-- Доход раз в секунду
	task.spawn(function()
		while true do
			task.wait(1)
			for player in plotOf do
				if DataService.IsLoaded(player) then
					local income = PlotService.IncomeOf(player)
					player:SetAttribute("Income", income)
					if income > 0 then
						PlotService.AddCoins(player, income)
						Hooks.Fire(player, "Earn", income)
					end
				end
			end
		end
	end)

	-- Lucky Blocks на базах
	task.spawn(function()
		while true do
			task.wait(LUCKY_CHECK_INTERVAL)
			local ok, err = pcall(luckyStep)
			if not ok then
				warn("[PlotService] Lucky Blocks:", err)
			end
		end
	end)

	-- Щиты закрытых баз и выталкивание чужих игроков
	task.spawn(function()
		while true do
			task.wait(0.2)
			for _, plot in plots do
				local locked = PlotService.IsLocked(plot)
				local shield = plot:FindFirstChild("Shield") :: BasePart
				shield.Transparency = if locked then 0.2 else 1
				if not locked then
					continue
				end
				local ownerId = plot:GetAttribute("OwnerUserId")
				for _, other in Players:GetPlayers() do
					if other.UserId == ownerId then
						continue
					end
					local character = other.Character
					local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
					if root and PlotService.InPlot(plot, root.Position) then
						-- Анти-чит переноски (StealService): это серверный перенос, не телепорт читера
						local pushed = character :: Model
						pushed:SetAttribute("ServerMovedAt", workspace:GetServerTimeNow())
						pushed:PivotTo(PlotService.OutsidePoint(plot))
					end
				end
			end
		end
	end)
end

return PlotService
