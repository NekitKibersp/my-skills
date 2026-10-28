-- Кражи: удержание «Украсть», переноска мема над головой, доставка на свою базу,
-- возврат хозяину (удар оружием, смерть, таймер, выход), отброс и скорость персонажа, страж-котёнок.
-- Само оружие и гаджеты — в ItemService.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local MemeFactory = require(script.Parent.MemeFactory)
local PlotService = require(script.Parent.PlotService)
local Remotes = require(script.Parent.Remotes)
local Hooks = require(script.Parent.Hooks)

local StealService = {}

type Carry = {
	Owner: Player,
	Slot: number,
	Model: Model,
	Id: string,
	EndsAt: number,
	-- Анти-чит: последняя проверенная позиция вора и число нарушений скорости
	LastPos: Vector3?,
	LastTime: number?,
	Strikes: number?,
}

local carries: { [Player]: Carry } = {} -- вор -> что несёт
local holdStart: { [Player]: number } = {}
local guardLastHit: { [Model]: number } = {}

local BASE_WALK_SPEED = 16

local checkMovement: (thief: Player, carry: Carry, root: BasePart, t: number) -> boolean

-- Колбэк начала кражи (выставляет init.server): снять шапку-невидимку и т.п.
StealService.OnStealStarted = nil :: ((thief: Player) -> ())?

local function now(): number
	return workspace:GetServerTimeNow()
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function setCarryAttributes(player: Player, id: string, endsAt: number)
	player:SetAttribute("Carrying", id)
	player:SetAttribute("CarryEndsAt", endsAt)
end

-- Все текущие переноски: вор -> { Owner, Slot, Model, Id, EndsAt } (только для чтения)
function StealService.GetCarries(): { [Player]: Carry }
	return carries
end

function StealService.IsCarrying(player: Player): boolean
	return carries[player] ~= nil
end

-- Скорость персонажа: с мемом медленнее, энергетик (атрибут BoostUntil на персонаже) быстрее
function StealService.UpdateSpeed(player: Player)
	local humanoid = humanoidOf(player)
	if not humanoid then
		return
	end
	local speed = if carries[player] then Config.Steal.CarryWalkSpeed else BASE_WALK_SPEED
	local character = player.Character :: Model
	if (character:GetAttribute("BoostUntil") or 0) > now() then
		speed += character:GetAttribute("BoostSpeed") or 0
	end
	humanoid.WalkSpeed = speed
end

-- Перенос закончился неудачей: мем возвращается хозяину
function StealService.Fail(thief: Player)
	local carry = carries[thief]
	if not carry then
		return
	end
	carries[thief] = nil
	setCarryAttributes(thief, "", 0)
	StealService.UpdateSpeed(thief)

	local owner = carry.Owner
	if owner.Parent and PlotService.GetPlot(owner) and DataService.IsLoaded(owner) and PlotService.GetEntry(owner, carry.Slot) then
		PlotService.ReturnModel(owner, carry.Slot, carry.Model)
		PlotService.SetAway(owner, carry.Slot, false)
		Remotes.Notify:FireClient(owner, "MemeReturned", { Meme = carry.Id }, "success")
	else
		carry.Model:Destroy()
	end
	if thief.Parent then
		Remotes.Notify:FireClient(thief, "StealFailed", { Meme = carry.Id }, "error")
	end
end

local function deliver(thief: Player)
	local carry = carries[thief]
	if not carry then
		return
	end
	local owner = carry.Owner
	-- Хозяин уже вышел (база освобождена) — мем остаётся в его сохранении, вору не достаётся
	if not PlotService.GetPlot(owner) or not DataService.IsLoaded(owner) then
		StealService.Fail(thief)
		return
	end
	local entry = PlotService.GetEntry(owner, carry.Slot)
	if not entry or not PlotService.FreeSlot(thief) then
		StealService.Fail(thief)
		return
	end
	carries[thief] = nil
	setCarryAttributes(thief, "", 0)
	StealService.UpdateSpeed(thief)

	local position = carry.Model:GetPivot().Position
	carry.Model:Destroy()
	PlotService.RemoveEntry(owner, carry.Slot)
	PlotService.AddMeme(thief, entry.Id, entry.Mut, entry.Viral)
	DataService.Increment(thief, "Stolen", 1)
	Hooks.Fire(thief, "Steal", 1)
	-- Дублей не бывает: при выходе хозяина все кражи его мемов отменяются до сохранения.
	Remotes.Fx:FireAllClients("Delivered", { Position = position, UserId = thief.UserId })
	Remotes.Notify:FireClient(thief, "Delivered", { Meme = entry.Id }, "success")
	Remotes.Notify:FireClient(owner, "MemeLost", { Meme = entry.Id, Player = thief.DisplayName }, "error")
end

local function requiredHold(player: Player): number
	return if player:GetAttribute("Pass_FastSteal") then Config.Steal.FastHoldDuration else Config.Steal.HoldDuration
end

-- Вызывается PlotService, когда кто-то дозажал «Украсть» на чужом меме
function StealService.TryStart(thief: Player, owner: Player, slot: number, prompt: ProximityPrompt)
	if thief == owner or not DataService.IsLoaded(thief) or not PlotService.GetPlot(thief) or not DataService.IsLoaded(owner) then
		return
	end
	-- Удержание проверяем сами: клиент может «нажать» промпт мгновенно
	local began = holdStart[thief]
	holdStart[thief] = nil
	local held = if began then os.clock() - began else 0
	if not began or held < requiredHold(thief) - 0.25 or held > requiredHold(thief) + 3 then
		return
	end
	if carries[thief] then
		Remotes.Notify:FireClient(thief, "AlreadyCarrying", nil, "error")
		return
	end
	local plot = PlotService.GetPlot(owner)
	if not plot then
		return
	end
	if PlotService.IsLocked(plot) then
		Remotes.Notify:FireClient(thief, "BaseLocked", nil, "error")
		return
	end
	if PlotService.IsBusy(owner, slot) or not PlotService.GetEntry(owner, slot) then
		return
	end
	if not PlotService.FreeSlot(thief) then
		Remotes.Notify:FireClient(thief, "BaseFull", nil, "error")
		return
	end
	local root = rootOf(thief)
	local humanoid = humanoidOf(thief)
	local model = PlotService.GetModel(owner, slot)
	if not root or not humanoid or humanoid.Health <= 0 or not model then
		return
	end
	if (root.Position - model:GetPivot().Position).Magnitude > 18 then
		return
	end

	PlotService.DetachModel(owner, slot)
	PlotService.SetAway(owner, slot, true)
	prompt:Destroy()
	for _, child in (model.PrimaryPart :: BasePart):GetChildren() do
		if child:IsA("ProximityPrompt") then
			child:Destroy()
		end
	end
	model:SetAttribute("State", "Carried")
	local height = (model.PrimaryPart :: BasePart).Size.Y
	MemeFactory.AttachTo(model, root, CFrame.new(0, 3 + height / 2, 0))
	model.Parent = workspace

	local id = model:GetAttribute("CreatureId")
	local endsAt = now() + Config.Steal.CarryTimeout
	carries[thief] = { Owner = owner, Slot = slot, Model = model, Id = id, EndsAt = endsAt }
	setCarryAttributes(thief, id, endsAt)
	StealService.UpdateSpeed(thief)
	if StealService.OnStealStarted then
		StealService.OnStealStarted(thief)
	end

	Remotes.Fx:FireAllClients("Stolen", { Position = root.Position })
	Remotes.Notify:FireClient(thief, "StealStarted", { Meme = id }, "success")
	Remotes.Notify:FireClient(owner, "BeingStolen", { Meme = id, Player = thief.DisplayName }, "error")
end

-- Анти-чит переноски: вор не может двигаться быстрее своей скорости (телепорт домой с мемом).
-- Возвращает false, если перенос сорван. Отброс и ракетные ботинки ставят персонажу
-- атрибут MoveGraceUntil — в это время скорость не проверяем.
function checkMovement(thief: Player, carry: Carry, root: BasePart, t: number): boolean
	local position = root.Position
	local lastPos, lastTime = carry.LastPos, carry.LastTime
	carry.LastPos, carry.LastTime = position, t
	if not lastPos or not lastTime then
		return true
	end
	local character = thief.Character
	if character and (character:GetAttribute("MoveGraceUntil") or 0) > t then
		return true
	end
	local humanoid = humanoidOf(thief)
	local speed = math.max(if humanoid then humanoid.WalkSpeed else BASE_WALK_SPEED, BASE_WALK_SPEED)
	local flat = Vector3.new(position.X - lastPos.X, 0, position.Z - lastPos.Z).Magnitude
	local allowed = speed * (t - lastTime) * Config.AntiCheat.CarrySpeedSlack + Config.AntiCheat.CarryExtraStuds
	if flat <= allowed then
		return true
	end
	carry.Strikes = (carry.Strikes or 0) + 1
	warn(string.format("[AntiCheat] %s двигается слишком быстро с мемом: %.1f studs (можно %.1f)", thief.Name, flat, allowed))
	if carry.Strikes >= Config.AntiCheat.MaxStrikes then
		StealService.Fail(thief)
		return false
	end
	return true
end

-- Отменить все кражи мемов этого хозяина (хозяин выходит из игры)
function StealService.CancelFromOwner(owner: Player)
	for thief, carry in carries do
		if carry.Owner == owner then
			StealService.Fail(thief)
		end
	end
end

-- Отбросить игрока (stun — сколько секунд он лежит) и выбить у него мема
function StealService.Knock(target: Player, from: Vector3, power: number, stun: number?)
	local root = rootOf(target)
	if not root then
		return
	end
	local direction = root.Position - from
	direction = Vector3.new(direction.X, 0, direction.Z)
	direction = if direction.Magnitude > 0.01 then direction.Unit else Vector3.new(1, 0, 0)
	local character = target.Character
	if character then
		character:SetAttribute("MoveGraceUntil", now() + 1.5 + (stun or 0.6))
	end
	Remotes.Knockback:FireClient(target, direction * power + Vector3.new(0, power * 0.45, 0), stun or 0.6)
	local carry = carries[target]
	if carry then
		StealService.Fail(target)
		-- Хозяин отбил своего мема (сам, стражем, турелью или ловушкой) — засчитываем защиту
		if carry.Owner.Parent then
			Hooks.Fire(carry.Owner, "Defend", 1)
		end
	end
end

-- ===== Персонажи =====

function StealService.OnCharacter(player: Player, character: Model)
	StealService.Fail(player)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if humanoid then
		humanoid.Died:Connect(function()
			StealService.Fail(player)
		end)
	end
end

function StealService.OnPlayerRemoving(player: Player)
	StealService.Fail(player)
	StealService.CancelFromOwner(player)
	holdStart[player] = nil
end

-- ===== Цикл: доставка, таймеры, страж =====

local function guardStep()
	local t = os.clock()
	for _, plot in PlotService.AllPlots() do
		local guard = plot:FindFirstChild("Guard") :: Model?
		local owner = PlotService.GetOwner(plot)
		if not guard or not owner then
			continue
		end
		local level = Config.Guard[guard:GetAttribute("GuardLevel") or 1]
		if not level or t - (guardLastHit[guard] or 0) < level.Cooldown then
			continue
		end
		local guardPosition = guard:GetPivot().Position
		for thief, carry in carries do
			if carry.Owner ~= owner then
				continue
			end
			local root = rootOf(thief)
			if root and (root.Position - guardPosition).Magnitude <= level.Range then
				guardLastHit[guard] = t
				StealService.Knock(thief, guardPosition, Config.Slap.Knockback)
				Remotes.Fx:FireAllClients("Slap", { Position = root.Position })
				Remotes.Notify:FireClient(thief, "GuardHit", nil, "error")
				-- Страж разворачивается к вору
				local base = guard:GetPivot()
				guard:PivotTo(CFrame.lookAt(base.Position, Vector3.new(root.Position.X, base.Position.Y, root.Position.Z)))
				break
			end
		end
	end
	for guard in guardLastHit do
		if not guard.Parent then
			guardLastHit[guard] = nil
		end
	end
end

function StealService.Start()
	PlotService.OnStealPrompt = StealService.TryStart

	-- Удержание промпта «Украсть» начинается — запоминаем время (проверка в TryStart)
	game:GetService("ProximityPromptService").PromptButtonHoldBegan:Connect(function(prompt, player)
		if prompt.Name == "StealPrompt" then
			holdStart[player] = os.clock()
		end
	end)
	local function step()
		local t = now()
		for thief, carry in carries do
			if not thief.Parent then
				continue
			end
			if t >= carry.EndsAt then
				StealService.Fail(thief)
				continue
			end
			local plot = PlotService.GetPlot(thief)
			local root = rootOf(thief)
			if root and not checkMovement(thief, carry, root, t) then
				continue
			end
			if plot and root and PlotService.InPlot(plot, root.Position) then
				deliver(thief)
			end
		end
		guardStep()
	end
	task.spawn(function()
		while true do
			task.wait(0.2)
			-- Ошибка в одном тике не должна навсегда остановить доставку, таймеры и стражей
			local ok, err = pcall(step)
			if not ok then
				warn("[StealService]", err)
			end
		end
	end)
end

return StealService
