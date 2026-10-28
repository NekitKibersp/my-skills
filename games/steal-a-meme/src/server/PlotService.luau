-- Базы игроков: выдача базы, мемы в слотах, доход в секунду, замок, страж, Индекс, перерождения.
-- Мемы на базе хранятся в DataService (таблица Memes); модели в мире — их отображение.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local MemeFactory = require(script.Parent.MemeFactory)
local Remotes = require(script.Parent.Remotes)

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
	return math.abs(localPos.X) <= size.X / 2 and math.abs(localPos.Z) <= size.Z / 2 and localPos.Y > -5 and localPos.Y < 40
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
	for slot = 1, PlotService.MaxSlots(player) do
		if not used[slot] then
			return slot
		end
	end
	return nil
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

local function updateSlotsInfo(player: Player)
	local plot = plotOf[player]
	if not plot then
		return
	end
	local maxSlots = PlotService.MaxSlots(player)
	for slot = 1, Config.AbsoluteMaxSlots do
		local part = slotPart(plot, slot)
		local unlocked = slot <= maxSlots
		part:SetAttribute("Unlocked", unlocked)
		part.Transparency = if unlocked then 0 else 0.75
		part.Color = if unlocked then Color3.fromRGB(90, 90, 110) else Color3.fromRGB(40, 40, 45)
	end
	player:SetAttribute("SlotsUsed", #PlotService.GetEntries(player))
	player:SetAttribute("MaxSlots", maxSlots)
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
	DataService.Set(player, "GuardLevel", level + 1)
	PlotService.RefreshGuard(player)
	Remotes.Notify:FireClient(player, "GuardUpgraded", { Level = level + 1 }, "success")
	return true, "GuardUpgraded"
end

-- ===== Перерождение =====

function PlotService.Rebirth(player: Player): (boolean, string)
	local rebirths = DataService.Get(player, "Rebirths")
	local cost = Config.RebirthCost(rebirths)
	if DataService.Get(player, "Coins") < cost then
		Remotes.Notify:FireClient(player, "RebirthNeed", { Price = cost }, "error")
		return false, "RebirthNeed"
	end
	DataService.Set(player, "Coins", 0)
	DataService.Set(player, "Rebirths", rebirths + 1)
	updateSlotsInfo(player)
	PlotService.RefreshIncome(player)
	Remotes.Fx:FireAllClients("Rebirth", { UserId = player.UserId })
	Remotes.Notify:FireClient(player, "Rebirthed", { Count = rebirths + 1 }, "success")
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
	local maxSlots = PlotService.MaxSlots(player)
	-- Если геймпасс слотов пропал (возврат), лишние мемы переезжают на свободные места или остаются вне слотов
	for _, entry in entries do
		if entry.Slot > maxSlots then
			warn("[PlotService] Мем за пределами слотов", player.Name, entry.Id)
		end
	end
	if #entries == 0 and DataService.IsNew(player) then
		table.insert(entries, { Id = Config.StarterMeme, Mut = "None", Viral = false, Slot = 1 })
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
	plotOf[player] = nil
	models[player] = nil
	away[player] = nil
end

function PlotService.Start(builtPlots: { Model })
	plots = builtPlots

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
					end
				end
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
						(character :: Model):PivotTo(PlotService.OutsidePoint(plot))
					end
				end
			end
		end
	end)
end

return PlotService
