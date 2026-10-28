-- Окно Индекса: сетка всех мемов из Config.Creatures. Открытые — цветные, закрытые — «???».
-- Источник — атрибут игрока IndexJson (JSON-массив ключей "Id|Mutation", см. Config.IndexKey).
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Locale = require(Shared:WaitForChild("Locale"))
local UiKit = require(script.Parent:WaitForChild("UiKit"))
local Util = require(script.Parent:WaitForChild("Util"))

local COLORS = UiKit.Colors
local create = UiKit.create
local player = Players.LocalPlayer

local UNKNOWN_BG = Color3.fromRGB(14, 15, 22)
local CELL_HEIGHT = 132
local GAP = 8
local SEASON_TAGS = { Halloween = "IndexSeasonHalloween", Winter = "IndexSeasonWinter" }

local IndexWindow = {}

-- Множество открытых ключей; битый или пустой JSON -> пустое множество
local function discoveredSet(): { [string]: boolean }
	local set = {}
	local raw = Util.str(player, "IndexJson")
	if raw == "" then
		return set
	end
	local ok, list = pcall(HttpService.JSONDecode, HttpService, raw)
	if ok and type(list) == "table" then
		for _, key in list do
			if type(key) == "string" then
				set[key] = true
			end
		end
	end
	return set
end

-- Текст цвета редкости; у «Секретного» цвет почти чёрный — рисуем белым с тёмной обводкой
local function paintRarity(label: TextLabel, rarityId: string)
	local rarity = Config.GetRarity(rarityId)
	if rarityId == "Secret" then
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextStrokeColor3 = Color3.new(0, 0, 0)
		label.TextStrokeTransparency = 0
	else
		label.TextColor3 = rarity.Color
		label.TextStrokeTransparency = 0.6
	end
	label.Text = Locale.Name(rarity)
end

function IndexWindow.Start(ctx)
	local window, body = UiKit.window(ctx.Gui, Locale.T("IndexTitle"), Vector2.new(720, 480))
	window.Name = "IndexWindow"
	ctx.Register("Index", window)

	local header = UiKit.text({
		Text = "",
		TextSize = 18,
		TextColor3 = COLORS.Gold,
		Size = UDim2.new(1, 0, 0, 24),
		Parent = body,
	})
	local sub = UiKit.text({
		Text = "",
		TextSize = 14,
		TextColor3 = COLORS.Muted,
		Position = UDim2.fromOffset(0, 24),
		Size = UDim2.new(1, 0, 0, 18),
		Parent = body,
	})

	local grid = create("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 48),
		Size = UDim2.new(1, 0, 1, -48),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = body,
	}, {
		create("UIPadding", { PaddingRight = UDim.new(0, 10), PaddingBottom = UDim.new(0, 6) }),
	})
	local layout = create("UIGridLayout", {
		CellPadding = UDim2.fromOffset(GAP, GAP),
		CellSize = UDim2.fromOffset(110, CELL_HEIGHT),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})

	-- Число колонок по ширине: 2 на узком телефоне, до 6 на ПК
	local function relayout()
		local width = grid.AbsoluteSize.X - 10
		if width <= 0 then
			return
		end
		local columns = math.clamp(math.floor((width + GAP) / (110 + GAP)), 2, 6)
		layout.CellSize = UDim2.fromOffset(math.floor((width - GAP * (columns - 1)) / columns), CELL_HEIGHT)
	end
	grid:GetPropertyChangedSignal("AbsoluteSize"):Connect(relayout)
	relayout()

	-- Ячейки создаются один раз, render() только перекрашивает
	local cells = {}
	for order, creature in Config.Creatures do
		local cell = create("Frame", {
			BackgroundColor3 = UNKNOWN_BG,
			LayoutOrder = order,
			Parent = grid,
		}, { UiKit.corner(10) })
		local stroke = create("UIStroke", { Thickness = 2, Color = COLORS.PanelLight, Parent = cell })
		local face = UiKit.text({
			Text = "❓",
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.new(0, 6, 0, 6),
			Size = UDim2.new(1, -12, 0, 46),
			Parent = cell,
		})
		local name = UiKit.text({
			Text = "",
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.new(0, 4, 0, 56),
			Size = UDim2.new(1, -8, 0, 32),
			Parent = cell,
		})
		create("UITextSizeConstraint", { MaxTextSize = 15, MinTextSize = 9, Parent = name })
		local rarity = UiKit.text({
			Text = "",
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.new(0, 4, 0, 88),
			Size = UDim2.new(1, -8, 0, 16),
			Parent = cell,
		})
		-- Точки открытых мутаций (цвет мутации) + пометка «только ночью» для сезонных
		local extra = UiKit.text({
			Text = "",
			RichText = true,
			TextSize = 13,
			TextColor3 = COLORS.Muted,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.new(0, 4, 0, 106),
			Size = UDim2.new(1, -8, 0, 18),
			Parent = cell,
		})
		cells[creature.Id] = {
			Creature = creature,
			Frame = cell,
			Stroke = stroke,
			Face = face,
			Name = name,
			Rarity = rarity,
			Extra = extra,
		}
	end

	local function render()
		local set = discoveredSet()
		local found, mutated = 0, 0
		for _, cell in cells do
			local creature = cell.Creature
			local known = set[Config.IndexKey(creature.Id, "None")] == true

			-- Открытые мутации этого вида
			local dots = {}
			for _, mutation in Config.Mutations do
				if mutation.Id ~= "None" and set[Config.IndexKey(creature.Id, mutation.Id)] then
					mutated += 1
					known = true -- вид встречен хотя бы в мутации — тоже считаем открытым
					local c = mutation.Color or COLORS.Text
					table.insert(dots, '<font color="#' .. c:ToHex() .. '">●</font>')
				end
			end
			if known then
				found += 1
			end

			local rarityColor = Config.GetRarity(creature.Rarity).Color
			cell.Frame.BackgroundColor3 = if known then COLORS.PanelLight else UNKNOWN_BG
			cell.Stroke.Color = if known then rarityColor else COLORS.PanelLight
			cell.Face.Text = if known then creature.Face else "❓"
			cell.Face.TextTransparency = if known then 0 else 0.5
			cell.Name.Text = if known then Locale.Name(creature) else Locale.T("IndexUnknown")
			cell.Name.TextColor3 = if known then COLORS.Text else COLORS.Muted
			paintRarity(cell.Rarity, creature.Rarity)
			if #dots > 0 then
				cell.Extra.Text = table.concat(dots, " ")
			elseif creature.Event then
				-- Сезонные: «Ночь Хэллоуина» / «Зимняя ночь», без сезона — просто «Только ночью»
				cell.Extra.Text = Locale.T(SEASON_TAGS[creature.Season or ""] or "IndexEvent")
			else
				cell.Extra.Text = ""
			end
		end

		local count = Util.num(player, "IndexCount")
		header.Text = Locale.T("IndexHeader", {
			Count = count,
			Percent = math.floor(count * Config.IndexBonusPerEntry * 100 + 0.5),
		})
		sub.Text = Locale.T("IndexSub", { Found = found, Total = #Config.Creatures, Mutated = mutated })
	end

	player:GetAttributeChangedSignal("IndexJson"):Connect(render)
	player:GetAttributeChangedSignal("IndexCount"):Connect(render)
	render()
end

return IndexWindow
