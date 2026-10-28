-- Скины базы и тапка (Config.Skins). Покупка за монеты — только скины с Price > 0 и без Source
-- (скины с Source = "Pass"/"Spin" приходят через Grant.Give из пропуска/колеса).
-- Данные: DataService.GetTable(player, "Skins") = { Owned = { [id] = true }, Base = id, Slipper = id }.
-- Скин базы: сервер перекрашивает Floor, Wall и GatePillar своей базы; исходный вид хранится в атрибутах
-- деталей (OrigColor/OrigMaterial), чтобы вернуть его при смене скина и уходе игрока.
-- Скин тапка: атрибут игрока SlipperSkin, сам тапок перекрашивает ItemService (через OnSlipperChanged).
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local Remotes = require(script.Parent.Remotes)

local SkinService = {}

-- Колбэк из init.server: скин тапка сменился (перевыдать/перекрасить тапок)
SkinService.OnSlipperChanged = nil :: ((Player) -> ())?

local DEFAULTS = { Base = "BaseDefault", Slipper = "SlipperDefault" }
local WALL_PARTS = { Wall = true, GatePillar = true }
local EQUIP_COOLDOWN = 0.5

local lastEquip: { [Player]: number } = {}

local function isReady(player: Player): boolean
	return player.Parent ~= nil and player:GetAttribute("DataLoaded") == true and DataService.IsLoaded(player)
end

local function materialOf(name: any): Enum.Material?
	if type(name) ~= "string" then
		return nil
	end
	local ok, material = pcall(function()
		return (Enum.Material :: any)[name]
	end)
	return if ok then material else nil
end

-- Проверенные данные скинов: неизвестные id выкидываем, стандартные скины есть всегда
local function ensure(player: Player): { [string]: any }
	local data = DataService.GetTable(player, "Skins")
	local owned = {}
	if type(data.Owned) == "table" then
		for id, value in data.Owned do
			if type(id) == "string" and value == true and Config.GetSkin(id) then
				owned[id] = true
			end
		end
	end
	for _, id in DEFAULTS do
		owned[id] = true
	end
	data.Owned = owned
	for kind, default in DEFAULTS do
		local skin = type(data[kind]) == "string" and Config.GetSkin(data[kind])
		if not skin or skin.Kind ~= kind or not owned[skin.Id] then
			data[kind] = default
		end
	end
	return data
end

local function sync(player: Player, data: { [string]: any })
	local owned = {}
	for id in data.Owned do
		table.insert(owned, id)
	end
	table.sort(owned)
	player:SetAttribute("SkinsJson", HttpService:JSONEncode({
		Owned = owned,
		Base = data.Base,
		Slipper = data.Slipper,
	}))
end

-- Запомнить исходный вид детали перед первой перекраской
local function remember(part: BasePart)
	if part:GetAttribute("OrigColor") == nil then
		part:SetAttribute("OrigColor", part.Color)
		part:SetAttribute("OrigMaterial", part.Material.Name)
	end
end

local function restore(part: BasePart)
	local color = part:GetAttribute("OrigColor")
	if typeof(color) == "Color3" then
		part.Color = color
	end
	local material = materialOf(part:GetAttribute("OrigMaterial"))
	if material then
		part.Material = material
	end
end

-- Перекрасить базу; skin = nil или скин без цветов — вернуть исходный вид
local function paintPlot(plot: Model, skin: any)
	local custom = skin ~= nil and typeof(skin.Floor) == "Color3"
	for _, part in plot:GetDescendants() do
		if not part:IsA("BasePart") then
			continue
		end
		if part.Name == "Floor" and part.Parent == plot then
			if custom then
				remember(part)
				part.Color = skin.Floor
				part.Material = materialOf(skin.Material) or part.Material
			else
				restore(part)
			end
		elseif WALL_PARTS[part.Name] then
			if custom and typeof(skin.Wall) == "Color3" then
				remember(part)
				part.Color = skin.Wall
			else
				restore(part)
			end
		end
	end
end

local function applyBase(player: Player, data: { [string]: any })
	local plot = PlotService.GetPlot(player)
	if plot then
		paintPlot(plot, Config.GetSkin(data.Base))
	end
end

local function applySlipper(player: Player, data: { [string]: any }, notify: boolean)
	player:SetAttribute("SlipperSkin", data.Slipper)
	if notify and SkinService.OnSlipperChanged then
		task.spawn(SkinService.OnSlipperChanged, player)
	end
end

local function equip(player: Player, data: { [string]: any }, skin: any)
	data[skin.Kind] = skin.Id
	if skin.Kind == "Base" then
		applyBase(player, data)
	else
		applySlipper(player, data, true)
	end
	sync(player, data)
end

local function buy(player: Player, id: any): (boolean, string)
	if not isReady(player) then
		return false, "SkinNotReady"
	end
	local skin = type(id) == "string" and Config.GetSkin(id)
	if not skin then
		return false, "SkinInvalid"
	end
	local data = ensure(player)
	if data.Owned[skin.Id] then
		return false, "SkinOwned"
	end
	if skin.Source or type(skin.Price) ~= "number" or skin.Price <= 0 then
		return false, "SkinNotForSale"
	end
	if DataService.Get(player, "Coins") < skin.Price then
		Remotes.Notify:FireClient(player, "NotEnoughCash", { Price = skin.Price }, "error")
		return false, "NotEnoughCash"
	end
	DataService.Increment(player, "Coins", -skin.Price)
	data.Owned[skin.Id] = true
	-- Купленный скин сразу надеваем
	equip(player, data, skin)
	Remotes.Notify:FireClient(player, "SkinBought", nil, "success")
	return true, "SkinBought"
end

local function equipRequest(player: Player, id: any): (boolean, string)
	if not isReady(player) then
		return false, "SkinNotReady"
	end
	local skin = type(id) == "string" and Config.GetSkin(id)
	if not skin then
		return false, "SkinInvalid"
	end
	local now = os.clock()
	if lastEquip[player] and now - lastEquip[player] < EQUIP_COOLDOWN then
		return false, "SkinTooFast"
	end
	local data = ensure(player)
	if not data.Owned[skin.Id] then
		return false, "SkinNotOwned"
	end
	lastEquip[player] = now
	if data[skin.Kind] ~= skin.Id then
		equip(player, data, skin)
	end
	return true, "SkinEquipped"
end

-- Пересчитать SkinsJson (например, скин выдан через Grant.Give)
function SkinService.Refresh(player: Player)
	if DataService.IsLoaded(player) then
		sync(player, ensure(player))
	end
end

-- Вызывается из init.server после загрузки базы и ДО выдачи тапка (DataLoaded),
-- чтобы ItemService уже видел атрибут SlipperSkin
function SkinService.OnLoaded(player: Player)
	if not DataService.IsLoaded(player) then
		return
	end
	local data = ensure(player)
	sync(player, data)
	applyBase(player, data)
	applySlipper(player, data, false)
end

-- Вызывается из init.server ДО PlotService.Release: база возвращается к исходному виду
function SkinService.OnPlayerRemoving(player: Player)
	lastEquip[player] = nil
	local plot = PlotService.GetPlot(player)
	if plot then
		paintPlot(plot, nil)
	end
end

local function guarded(callback: (Player, any) -> (boolean, string), name: string)
	return function(player: Player, id: any)
		local ok, result, key = pcall(callback, player, id)
		if not ok then
			warn("[SkinService] Ошибка " .. name .. ":", result)
			return false, "SkinNotReady"
		end
		return result, key
	end
end

function SkinService.Start()
	Remotes.BuySkin.OnServerInvoke = guarded(buy, "покупки скина")
	Remotes.EquipSkin.OnServerInvoke = guarded(equipRequest, "смены скина")

	Players.PlayerRemoving:Connect(function(player)
		lastEquip[player] = nil
	end)
end

return SkinService
