-- Таблички над мемами (тег "Meme"): мутация, ВИРУСНЫЙ, имя, редкость, доход/сек, цена на дорожке.
-- BillboardGui создаются локально в PlayerGui и привязываются к Body (Adornee), поэтому
-- переживают стриминг: Body ушёл — табличка пустая, вернулся — снова привязываем.
-- Редкость «Лимит» пульсирует (мем недели), цвета Limited/Exclusive — из Config.Rarities.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))
local Locale = require(Shared:WaitForChild("Locale"))
local UiKit = require(script.Parent:WaitForChild("UiKit"))
local Util = require(script.Parent:WaitForChild("Util"))

local COLORS = UiKit.Colors
local create = UiKit.create
local player = Players.LocalPlayer

local VIRAL_COLOR = Color3.fromRGB(255, 80, 220)
local MAX_DISTANCE = 60
local PULSE = TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
local PULSE_RARITIES = { Limited = true }

local MemeBillboards = {}

type Entry = {
	Model: Instance,
	Gui: BillboardGui,
	Tags: TextLabel,
	Name: TextLabel,
	Rarity: TextLabel,
	Income: TextLabel,
	Price: TextLabel,
	Pulse: Tween?,
}
local entries: { [Instance]: Entry } = {}

local function row(parent: Instance, order: number, height: number, textSize: number): TextLabel
	return UiKit.text({
		Text = "",
		RichText = true,
		TextSize = textSize,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.2,
		Size = UDim2.new(1, 0, 0, height),
		LayoutOrder = order,
		Parent = parent,
	})
end

local function render(entry: Entry)
	local model = entry.Model
	local id = Util.str(model, "CreatureId")
	local creature = Config.GetCreature(id)
	local mutation = Config.GetMutation(Util.str(model, "Mutation"))
	local viral = Util.bool(model, "Viral")
	local state = Util.str(model, "State")

	-- Мутация (цветом) и значок ВИРУСНЫЙ
	local tags = {}
	if mutation.Id ~= "None" then
		local color = mutation.Color or COLORS.Text
		table.insert(tags, '<font color="#' .. color:ToHex() .. '">' .. Locale.Name(mutation) .. "</font>")
	end
	if viral then
		table.insert(tags, '<font color="#' .. VIRAL_COLOR:ToHex() .. '">🔥 ' .. Locale.T("BbViral") .. "</font>")
	end
	entry.Tags.Text = table.concat(tags, "  ")
	entry.Tags.Visible = #tags > 0

	entry.Name.Text = if creature then Locale.Name(creature) else id

	-- Редкость; «Секретный» почти чёрный — белый текст с тёмной обводкой
	local rarityId = if creature then creature.Rarity else "Common"
	local rarity = Config.GetRarity(rarityId)
	entry.Rarity.Text = Locale.Name(rarity)
	if rarityId == "Secret" then
		entry.Rarity.TextColor3 = Color3.new(1, 1, 1)
		entry.Rarity.TextStrokeColor3 = Color3.new(0, 0, 0)
		entry.Rarity.TextStrokeTransparency = 0
	else
		entry.Rarity.TextColor3 = rarity.Color
		entry.Rarity.TextStrokeColor3 = Color3.new(0, 0, 0)
		entry.Rarity.TextStrokeTransparency = 0.2
	end
	-- Пульсация подписи редкости (один бесконечный твин на табличку)
	if PULSE_RARITIES[rarityId] and not entry.Pulse then
		local scale = create("UIScale", { Parent = entry.Rarity })
		entry.Pulse = TweenService:Create(scale, PULSE, { Scale = 1.25 })
		entry.Pulse:Play()
	end

	-- Доход/сек: базовый × тренд (без личных множителей игрока)
	local income = Config.BaseIncome(id, mutation.Id, viral)
	local trending = id ~= "" and Util.str(ReplicatedStorage, "TrendingId") == id
	if trending then
		income *= Config.Trend.Mult
	end
	local incomeText = Locale.T("BbIncome", { Coins = income })
	entry.Income.Text = if trending then "📈 " .. incomeText else incomeText
	entry.Income.TextColor3 = if trending then COLORS.Gold else COLORS.Green

	-- Цена — только на дорожке: зелёная, если хватает денег, иначе красная
	local price = Util.num(model, "Price")
	local onCarpet = state == "Carpet" and Util.num(model, "OwnerUserId") == 0 and price > 0
	entry.Price.Visible = onCarpet
	if onCarpet then
		entry.Price.Text = "$" .. Format.Number(price)
		entry.Price.TextColor3 = if Util.num(player, "Coins") >= price then COLORS.Green else COLORS.Red
	end

	-- Высота таблички — над макушкой модели
	local body = entry.Gui.Adornee
	local height = Util.num(model, "Height")
	if height <= 0 and body and body:IsA("BasePart") then
		height = body.Size.Y
	end
	entry.Gui.StudsOffsetWorldSpace = Vector3.new(0, height / 2 + 0.8, 0)
end

local function track(model: Instance): () -> ()
	local folder = player:WaitForChild("PlayerGui"):FindFirstChild("MemeBillboards")
	local gui = create("BillboardGui", {
		Name = "Meme",
		Size = UDim2.fromOffset(200, 112),
		SizeOffset = Vector2.new(0, 0.5), -- нижний край таблички на точке привязки
		MaxDistance = MAX_DISTANCE,
		LightInfluence = 0,
		ResetOnSpawn = false,
		ClipsDescendants = false,
	})
	local list = create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		create("UIListLayout", {
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	local entry: Entry = {
		Model = model,
		Gui = gui,
		Tags = row(list, 1, 18, 15),
		Name = row(list, 2, 24, 20),
		Rarity = row(list, 3, 18, 15),
		Income = row(list, 4, 20, 17),
		Price = row(list, 5, 24, 21),
	}
	entry.Name.TextColor3 = COLORS.Text
	entry.Name.TextStrokeTransparency = 0
	entry.Price.TextStrokeTransparency = 0
	entries[model] = entry

	local connections: { RBXScriptConnection } = {}
	local function adorn()
		gui.Adornee = Util.mainPart(model)
		render(entry)
	end
	adorn()
	gui.Parent = folder

	-- StreamingEnabled: Body может прийти позже (или заново после выгрузки)
	table.insert(connections, model.ChildAdded:Connect(function(child)
		if child.Name == "Body" or (not gui.Adornee and child:IsA("BasePart")) then
			adorn()
		end
	end))
	table.insert(connections, model.AttributeChanged:Connect(function()
		render(entry)
	end))

	return function()
		entries[model] = nil
		if entry.Pulse then
			entry.Pulse:Cancel()
		end
		for _, connection in connections do
			connection:Disconnect()
		end
		gui:Destroy()
	end
end

local function renderAll()
	for _, entry in entries do
		render(entry)
	end
end

function MemeBillboards.Start()
	create("Folder", { Name = "MemeBillboards", Parent = player:WaitForChild("PlayerGui") })

	ReplicatedStorage:GetAttributeChangedSignal("TrendingId"):Connect(renderAll)
	-- Цвет цены зависит от денег игрока
	player:GetAttributeChangedSignal("Coins"):Connect(function()
		for _, entry in entries do
			if entry.Price.Visible then
				local price = Util.num(entry.Model, "Price")
				entry.Price.TextColor3 = if Util.num(player, "Coins") >= price then COLORS.Green else COLORS.Red
			end
		end
	end)

	Util.watchTagged("Meme", track)
end

return MemeBillboards
