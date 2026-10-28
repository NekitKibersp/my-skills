-- Состояние своего персонажа над панелью предметов (снизу по центру):
-- перезарядка экипированного предмета (Tool.CooldownEndsAt), невидимость (Invisible), энергетик (BoostUntil)
-- и безопасная зона Торговой площади (InSafeZone).
-- Пока своя невидимость включена, игрок видит себя полупрозрачным (LocalTransparencyModifier) —
-- остальные не видят его вовсе (это делает сервер).
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

local SELF_GHOST = 0.6 -- насколько прозрачным игрок видит себя в невидимости
local HIDDEN = 0.99 -- деталь считается спрятанной сервером, если прозрачнее этого
local HOTBAR_GAP = 78 -- отступ от низа экрана: над стандартной панелью предметов Roblox
local INVIS_COLOR = Color3.fromRGB(190, 200, 230)
local BOOST_COLOR = Color3.fromRGB(110, 255, 140)
local SAFE_COLOR = Color3.fromRGB(90, 255, 200)

local Status = {}

-- Небольшая плашка с текстом и обводкой
local function chip(parent: Instance, order: number, stroke: Color3): TextLabel
	local label = UiKit.text({
		Text = "",
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.5,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 28),
		BackgroundColor3 = COLORS.Panel,
		BackgroundTransparency = 0.15,
		LayoutOrder = order,
		Visible = false,
		Parent = parent,
	})
	UiKit.corner(8).Parent = label
	create("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = label })
	create("UIStroke", { Color = stroke, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = label })
	return label
end

-- ===== Своя полупрозрачность в невидимости =====
-- Сервер прячет детали (Transparency = 1) для всех. Чтобы игрок видел себя, локально
-- возвращаем исходную прозрачность и добавляем LocalTransparencyModifier.
-- Исходную прозрачность запоминаем, пока невидимость выключена.
local original: { [Instance]: number } = {}
local touched: { [Instance]: boolean } = {}

local function isVisual(inst: Instance): boolean
	if inst:IsA("BasePart") then
		return inst.Name ~= "HumanoidRootPart"
	end
	return inst:IsA("Decal")
end

local function remember(inst: Instance)
	if isVisual(inst) and original[inst] == nil then
		original[inst] = (inst :: any).Transparency
	end
end

local function applyGhost(character: Model)
	for _, inst in character:GetDescendants() do
		if isVisual(inst) then
			local target = inst :: any
			local base = original[inst]
			if base and base < HIDDEN and target.Transparency >= HIDDEN then
				target.Transparency = base
			end
			target.LocalTransparencyModifier = math.max(target.LocalTransparencyModifier, SELF_GHOST)
			touched[inst] = true
		end
	end
end

local function clearGhost()
	-- Transparency не трогаем: сервер сам вернёт исходную (ту же, что мы поставили локально)
	for inst in touched do
		if inst.Parent then
			(inst :: any).LocalTransparencyModifier = 0
		end
	end
	table.clear(touched)
end

local function trackCharacter(character: Model)
	table.clear(original)
	table.clear(touched)
	for _, inst in character:GetDescendants() do
		remember(inst)
	end
	character.DescendantAdded:Connect(function(inst)
		if not Util.bool(character, "Invisible") then
			remember(inst)
		end
	end)
end

function Status.Start(ctx)
	local holder = create("Frame", {
		Name = "Status",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -HOTBAR_GAP),
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		Parent = ctx.Gui,
	}, {
		create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	ctx.Scale(holder)

	-- Перезарядка: имя предмета + полоса + секунды
	local cooldown = create("Frame", {
		Name = "Cooldown",
		Size = UDim2.fromOffset(170, 44),
		BackgroundColor3 = COLORS.Panel,
		BackgroundTransparency = 0.15,
		LayoutOrder = 1,
		Visible = false,
		Parent = holder,
	}, {
		UiKit.corner(8),
		create("UIStroke", { Color = COLORS.Gold, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	})
	local itemName = UiKit.text({
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(6, 2),
		Size = UDim2.new(1, -12, 0, 18),
		Parent = cooldown,
	})
	create("UITextSizeConstraint", { MaxTextSize = 14, Parent = itemName })
	local bar = create("Frame", {
		Position = UDim2.fromOffset(8, 22),
		Size = UDim2.new(1, -16, 0, 16),
		BackgroundColor3 = COLORS.PanelLight,
		Parent = cooldown,
	}, { UiKit.corner(5) })
	local fill = create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = COLORS.Gold,
		Parent = bar,
	}, { UiKit.corner(5) })
	local seconds = UiKit.text({
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.3,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
		Parent = bar,
	})

	local invisible = chip(holder, 2, INVIS_COLOR)
	invisible.TextColor3 = INVIS_COLOR
	local boost = chip(holder, 3, BOOST_COLOR)
	boost.TextColor3 = BOOST_COLOR
	local safe = chip(holder, 4, SAFE_COLOR)
	safe.TextColor3 = SAFE_COLOR
	safe.Text = Locale.T("ZoneSafeChip")

	if player.Character then
		trackCharacter(player.Character)
	end
	player.CharacterAdded:Connect(trackCharacter)

	local wasInvisible = false
	local invisibleSince = 0

	local function render()
		local now = Util.now()
		local character = player.Character

		-- Экипированный предмет на перезарядке
		local tool = character and character:FindFirstChildOfClass("Tool")
		local left = if tool then Util.num(tool, "CooldownEndsAt") - now else 0
		cooldown.Visible = left > 0
		if tool and left > 0 then
			local itemId = Util.str(tool, "ItemId")
			local item = Config.GetItem(if itemId ~= "" then itemId else tool.Name)
			local total = if item and item.Cooldown and item.Cooldown > 0 then item.Cooldown else left
			itemName.Text = if item then item.Face .. " " .. Locale.Name(item) else tool.Name
			fill.Size = UDim2.fromScale(math.clamp(left / total, 0, 1), 1)
			seconds.Text = Locale.T("StatusCooldown", { Seconds = string.format("%.1f", left) })
		end

		-- Невидимость: длительность — из Config.Items (сервер даёт только флаг)
		local isInvisible = character ~= nil and Util.bool(character, "Invisible")
		if isInvisible and not wasInvisible then
			invisibleSince = now
		end
		if isInvisible and character then
			applyGhost(character)
			local hat = Config.GetItem("InvisHat")
			local duration = if hat and hat.Duration then hat.Duration else 0
			invisible.Text = Locale.T("StatusInvisible", { Time = Util.clock(math.ceil(duration - (now - invisibleSince))) })
		elseif wasInvisible then
			clearGhost()
		end
		invisible.Visible = isInvisible
		wasInvisible = isInvisible

		local boostLeft = if character then Util.num(character, "BoostUntil") - now else 0
		boost.Visible = boostLeft > 0
		if boostLeft > 0 then
			boost.Text = Locale.T("StatusBoost", { Time = Util.clock(math.ceil(boostLeft)) })
		end

		safe.Visible = character ~= nil and Util.bool(character, "InSafeZone")
	end

	task.spawn(function()
		while true do
			render()
			task.wait(0.1)
		end
	end)
end

return Status
