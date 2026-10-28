-- Предметы из Config.Items: оружие (тапок, бита, сковородка, бан-молот) и гаджеты
-- (энергетик, банановая кожура, шапка-невидимка). Покупка за монеты навсегда, выдача в рюкзак,
-- вся логика ударов и перезарядок — на сервере.
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Remotes = require(script.Parent.Remotes)
local StealService = require(script.Parent.StealService)

local ItemService = {}

-- Колбэк удара по монстру (выставляет init.server): (player, origin, range) -> boolean
ItemService.OnMonsterHit = nil :: ((player: Player, origin: Vector3, range: number) -> boolean)?

local cooldowns: { [Player]: { [string]: number } } = {} -- игрок -> предмет -> os.clock() конца перезарядки
local bananas: { [Player]: { BasePart } } = {}
local invisibleToken: { [Player]: number } = {}
local bananaFolder: Folder

local function now(): number
	return workspace:GetServerTimeNow()
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function aliveHumanoid(player: Player): Humanoid?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		return humanoid
	end
	return nil
end

-- ===== Владение =====

function ItemService.Owns(player: Player, id: string): boolean
	if id == "Slipper" then
		return true
	end
	return DataService.IsLoaded(player) and DataService.GetTable(player, "Items")[id] == true
end

local function syncItems(player: Player)
	local owned = { "Slipper" }
	for id in DataService.GetTable(player, "Items") do
		table.insert(owned, id)
	end
	player:SetAttribute("ItemsJson", HttpService:JSONEncode(owned))
end

-- ===== Внешний вид (детали из примитивов) =====

local function addPart(tool: Tool, handle: BasePart, props: { [string]: any }, offset: CFrame)
	local p = Instance.new("Part")
	p.CanCollide = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	p.CFrame = handle.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = p
	weld.Parent = p
	p.Parent = tool
end

local function buildTool(item: any, gold: boolean): Tool
	local tool = Instance.new("Tool")
	tool.Name = item.Id
	tool.ToolTip = item.Face .. " " .. item.Name
	tool.CanBeDropped = false
	tool:SetAttribute("ItemId", item.Id)
	tool:SetAttribute("CooldownEndsAt", 0)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.CanCollide = false
	handle.Massless = true
	handle.TopSurface = Enum.SurfaceType.Smooth
	handle.BottomSurface = Enum.SurfaceType.Smooth
	handle.Parent = tool

	local id = item.Id
	if id == "Slipper" then
		handle.Size = Vector3.new(1.2, 2.6, 0.35)
		handle.Color = if gold then Color3.fromRGB(255, 205, 50) else Color3.fromRGB(70, 90, 200)
		handle.Material = if gold then Enum.Material.Foil else Enum.Material.Fabric
		tool.Grip = CFrame.new(0, -0.9, 0) * CFrame.Angles(0, math.rad(90), 0)
		addPart(tool, handle, { Size = Vector3.new(1.25, 0.35, 0.5), Color = Color3.fromRGB(240, 240, 240) }, CFrame.new(0, 0.6, -0.3))
	elseif id == "Bat" then
		handle.Size = Vector3.new(0.5, 4.5, 0.5)
		handle.Color = Color3.fromRGB(170, 120, 70)
		handle.Material = Enum.Material.Wood
		tool.Grip = CFrame.new(0, -1.6, 0)
		addPart(tool, handle, { Size = Vector3.new(0.9, 1.8, 0.9), Color = Color3.fromRGB(150, 100, 60), Material = Enum.Material.Wood }, CFrame.new(0, 1.6, 0))
	elseif id == "Pan" then
		handle.Size = Vector3.new(0.35, 2.2, 0.35)
		handle.Color = Color3.fromRGB(40, 40, 45)
		tool.Grip = CFrame.new(0, -0.8, 0)
		addPart(tool, handle, {
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.3, 2.6, 2.6),
			Color = Color3.fromRGB(30, 30, 35),
			Material = Enum.Material.Metal,
		}, CFrame.new(0, 2.2, 0) * CFrame.Angles(0, math.rad(90), 0))
	elseif id == "BanHammer" then
		handle.Size = Vector3.new(0.5, 4.5, 0.5)
		handle.Color = Color3.fromRGB(60, 40, 30)
		handle.Material = Enum.Material.Wood
		tool.Grip = CFrame.new(0, -1.6, 0)
		addPart(tool, handle, { Size = Vector3.new(3.2, 1.8, 1.8), Color = Color3.fromRGB(230, 40, 50), Material = Enum.Material.Neon }, CFrame.new(0, 2.4, 0))
	elseif id == "Energy" then
		handle.Shape = Enum.PartType.Cylinder
		handle.Size = Vector3.new(1.4, 0.8, 0.8)
		handle.Color = Color3.fromRGB(70, 220, 90)
		handle.Material = Enum.Material.Metal
		tool.Grip = CFrame.Angles(0, 0, math.rad(90))
	elseif id == "Banana" then
		handle.Size = Vector3.new(0.6, 1.8, 0.4)
		handle.Color = Color3.fromRGB(255, 225, 60)
		tool.Grip = CFrame.new(0, -0.4, 0)
	elseif id == "InvisHat" then
		handle.Shape = Enum.PartType.Cylinder
		handle.Size = Vector3.new(1.4, 1.3, 1.3)
		handle.Color = Color3.fromRGB(25, 25, 30)
		tool.Grip = CFrame.Angles(0, 0, math.rad(90))
		addPart(tool, handle, {
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.15, 2.2, 2.2),
			Color = Color3.fromRGB(25, 25, 30),
		}, CFrame.new(-0.65, 0, 0))
		addPart(tool, handle, {
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.3, 1.35, 1.35),
			Color = Color3.fromRGB(150, 60, 255),
			Material = Enum.Material.Neon,
		}, CFrame.new(-0.3, 0, 0))
	end
	return tool
end

-- ===== Перезарядка =====

local function ready(player: Player, item: any, tool: Tool): boolean
	local list = cooldowns[player]
	if not list then
		list = {}
		cooldowns[player] = list
	end
	local t = os.clock()
	if (list[item.Id] or 0) > t then
		return false
	end
	list[item.Id] = t + item.Cooldown
	tool:SetAttribute("CooldownEndsAt", now() + item.Cooldown)
	return true
end

-- ===== Невидимость =====

local function setInvisible(player: Player, invisible: boolean)
	local character = player.Character
	if not character then
		return
	end
	if (character:GetAttribute("Invisible") == true) == invisible then
		return
	end
	character:SetAttribute("Invisible", invisible)
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") or descendant:IsA("Decal") then
			if invisible then
				descendant:SetAttribute("OrigTransparency", descendant.Transparency)
				descendant.Transparency = 1
			else
				local original = descendant:GetAttribute("OrigTransparency")
				if original ~= nil then
					descendant.Transparency = original
					descendant:SetAttribute("OrigTransparency", nil)
				end
			end
		end
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = if invisible then Enum.HumanoidDisplayDistanceType.None else Enum.HumanoidDisplayDistanceType.Viewer
	end
	local root = rootOf(player)
	if root then
		Remotes.Fx:FireAllClients("Invisible", { Position = root.Position })
	end
end

-- Снять невидимость (начал кражу или ударил)
function ItemService.BreakInvisibility(player: Player)
	invisibleToken[player] = nil
	setInvisible(player, false)
end

-- ===== Оружие =====

local function swing(tool: Tool)
	local baseGrip = tool:GetAttribute("BaseGrip") or tool.Grip
	tool:SetAttribute("BaseGrip", baseGrip)
	tool.Grip = baseGrip * CFrame.Angles(math.rad(-80), 0, 0)
	task.delay(0.15, function()
		if tool.Parent then
			tool.Grip = baseGrip
		end
	end)
end

local function attack(player: Player, item: any, tool: Tool)
	local root = rootOf(player)
	if not root or not aliveHumanoid(player) or not ready(player, item, tool) then
		return
	end
	ItemService.BreakInvisibility(player)
	swing(tool)

	local gold = item.Id == "Slipper" and player:GetAttribute("Pass_GoldSlipper") == true
	local range = if gold then Config.Slap.GoldRange else item.Range
	local power = if gold then Config.Slap.GoldKnockback else item.Knockback
	local look = root.CFrame.LookVector

	local targets: { Player } = {}
	local best: Player? = nil
	local bestDistance = range
	for _, other in Players:GetPlayers() do
		if other == player or not aliveHumanoid(other) then
			continue
		end
		local otherRoot = rootOf(other)
		if not otherRoot then
			continue
		end
		local offset = otherRoot.Position - root.Position
		local distance = offset.Magnitude
		if item.Area then
			if distance <= range then
				table.insert(targets, other)
			end
		elseif distance <= bestDistance and (distance < 3 or offset.Unit:Dot(look) > 0.2) then
			best, bestDistance = other, distance
		end
	end
	if best then
		table.insert(targets, best)
	end

	for _, target in targets do
		local targetRoot = rootOf(target) :: BasePart
		StealService.Knock(target, root.Position, power, item.Stun)
		Remotes.Fx:FireAllClients("Slap", { Position = targetRoot.Position })
	end
	if (#targets == 0 or item.Area) and ItemService.OnMonsterHit then
		ItemService.OnMonsterHit(player, root.Position, range + 4)
	end
end

-- ===== Гаджеты =====

local function useEnergy(player: Player, item: any, tool: Tool)
	local character = player.Character
	local root = rootOf(player)
	if not character or not root or not aliveHumanoid(player) or not ready(player, item, tool) then
		return
	end
	character:SetAttribute("BoostUntil", now() + item.Duration)
	character:SetAttribute("BoostSpeed", item.Speed)
	StealService.UpdateSpeed(player)
	Remotes.Fx:FireAllClients("Energy", { Position = root.Position })
	task.delay(item.Duration + 0.05, function()
		if player.Parent and player.Character == character then
			StealService.UpdateSpeed(player)
		end
	end)
end

local function placeBanana(player: Player, item: any, tool: Tool)
	local root = rootOf(player)
	if not root or not aliveHumanoid(player) or not ready(player, item, tool) then
		return
	end
	-- Кладём под ноги чуть позади: ловушка для того, кто бежит следом
	local origin = root.Position - root.CFrame.LookVector * 3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: Model, bananaFolder }
	local hit = workspace:Raycast(origin, Vector3.new(0, -12, 0), params)
	local groundY = if hit then hit.Position.Y else root.Position.Y - 3

	local banana = Instance.new("Part")
	banana.Name = "Banana"
	banana.Size = Vector3.new(2, 0.3, 1.2)
	banana.Color = Color3.fromRGB(255, 225, 60)
	banana.Material = Enum.Material.SmoothPlastic
	banana.Anchored = true
	banana.CanCollide = false
	banana.CFrame = CFrame.new(origin.X, groundY + 0.15, origin.Z) * CFrame.Angles(0, math.rad(math.random(0, 360)), 0)
	banana:SetAttribute("OwnerUserId", player.UserId)
	CollectionService:AddTag(banana, "Banana")

	local list = bananas[player] or {}
	bananas[player] = list
	table.insert(list, banana)
	while #list > item.MaxActive do
		local old = table.remove(list, 1)
		if old then
			old:Destroy()
		end
	end

	local used = false
	banana.Touched:Connect(function(other)
		if used then
			return
		end
		local victim = Players:GetPlayerFromCharacter(other.Parent)
		if not victim or victim == player or not aliveHumanoid(victim) then
			return
		end
		used = true
		local position = banana.Position
		banana:Destroy()
		StealService.Knock(victim, position - Vector3.new(0, 1, 0), 25, item.Stun)
		Remotes.Fx:FireAllClients("Banana", { Position = position })
	end)
	banana.Parent = bananaFolder

	task.delay(item.Duration, function()
		if banana.Parent then
			banana:Destroy()
		end
		local current = bananas[player]
		if current then
			local index = table.find(current, banana)
			if index then
				table.remove(current, index)
			end
		end
	end)
end

local function useInvisHat(player: Player, item: any, tool: Tool)
	if not aliveHumanoid(player) or StealService.IsCarrying(player) or not ready(player, item, tool) then
		return
	end
	local token = (invisibleToken[player] or 0) + 1
	invisibleToken[player] = token
	setInvisible(player, true)
	task.delay(item.Duration, function()
		if invisibleToken[player] == token then
			invisibleToken[player] = nil
			setInvisible(player, false)
		end
	end)
end

local USE = {
	Energy = useEnergy,
	Banana = placeBanana,
	InvisHat = useInvisHat,
}

-- ===== Выдача =====

function ItemService.GiveTools(player: Player)
	local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 5)
	if not backpack then
		return
	end
	for _, container in { backpack, player.Character } do
		if container then
			for _, child in container:GetChildren() do
				if child:IsA("Tool") and child:GetAttribute("ItemId") then
					child:Destroy()
				end
			end
		end
	end
	local gold = player:GetAttribute("Pass_GoldSlipper") == true
	for _, item in Config.Items do
		if not ItemService.Owns(player, item.Id) then
			continue
		end
		local tool = buildTool(item, gold)
		-- Перезарядка переживает респавн
		local endsAt = cooldowns[player] and cooldowns[player][item.Id]
		if endsAt and endsAt > os.clock() then
			tool:SetAttribute("CooldownEndsAt", now() + (endsAt - os.clock()))
		end
		tool.Activated:Connect(function()
			if item.Kind == "Weapon" then
				attack(player, item, tool)
			else
				local use = USE[item.Id]
				if use then
					use(player, item, tool)
				end
			end
		end)
		tool.Parent = backpack
	end
end

function ItemService.Buy(player: Player, id: unknown): (boolean, string)
	if type(id) ~= "string" or not DataService.IsLoaded(player) then
		return false, "NotLoaded"
	end
	local item = Config.GetItem(id)
	if not item then
		return false, "NotLoaded"
	end
	if ItemService.Owns(player, id) then
		return false, "ItemOwned"
	end
	if DataService.Get(player, "Coins") < item.Price then
		Remotes.Notify:FireClient(player, "NotEnoughCash", { Price = item.Price }, "error")
		return false, "NotEnoughCash"
	end
	DataService.Increment(player, "Coins", -item.Price)
	DataService.GetTable(player, "Items")[id] = true
	syncItems(player)
	ItemService.GiveTools(player)
	Remotes.Notify:FireClient(player, "ItemBought", { Item = id }, "success")
	return true, "ItemBought"
end

function ItemService.OnLoaded(player: Player)
	syncItems(player)
end

function ItemService.OnCharacter(player: Player, character: Model)
	invisibleToken[player] = nil
	character:SetAttribute("Invisible", false)
	ItemService.GiveTools(player)
end

function ItemService.OnPlayerRemoving(player: Player)
	for _, banana in bananas[player] or {} do
		banana:Destroy()
	end
	bananas[player] = nil
	cooldowns[player] = nil
	invisibleToken[player] = nil
end

function ItemService.Start()
	bananaFolder = Instance.new("Folder")
	bananaFolder.Name = "Bananas"
	bananaFolder.Parent = workspace

	StealService.OnStealStarted = ItemService.BreakInvisibility
	Remotes.BuyItem.OnServerInvoke = ItemService.Buy
end

return ItemService
