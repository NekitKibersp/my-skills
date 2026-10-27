-- Собирает модель мема: из примитивов (тело + ножки + эмодзи-лицо) или из модели Creator Store
-- по Config.Creatures[*].ModelId. Подписи (имя, редкость, доход) рисует клиент.
local CollectionService = game:GetService("CollectionService")
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local MemeFactory = {}

local BASE_SIZE = 4 -- высота тела мема с Size = 1
local VIRAL_SCALE = 1.35

local loadedModels: { [number]: Model | false } = {}

-- Скрипты в бесплатных моделях часто оказываются «бэкдорами» — вырезаем всё исполняемое.
local function stripScripts(root: Instance)
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		end
	end
end

local function loadTemplate(assetId: number): Model?
	local cached = loadedModels[assetId]
	if cached ~= nil then
		return if cached then cached else nil
	end
	local ok, container = pcall(function()
		return InsertService:LoadAsset(assetId)
	end)
	local model: Model? = nil
	if ok and container then
		stripScripts(container)
		local found = container:FindFirstChildWhichIsA("Model")
		if found then
			model = found
		elseif #container:GetChildren() > 0 then
			model = Instance.new("Model")
			for _, child in container:GetChildren() do
				child.Parent = model
			end
		end
	else
		warn("[MemeFactory] Не удалось загрузить модель", assetId, container)
	end
	loadedModels[assetId] = model or false
	return model
end

local function weld(part: BasePart, body: BasePart)
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = false
	part.Massless = true
	local constraint = Instance.new("WeldConstraint")
	constraint.Part0 = body
	constraint.Part1 = part
	constraint.Parent = part
end

local function applyMutation(part: BasePart, mutationId: string)
	if mutationId == "Gold" then
		part.Color = Color3.fromRGB(255, 205, 60)
		part.Material = Enum.Material.Foil
	elseif mutationId == "Diamond" then
		part.Color = Color3.fromRGB(130, 230, 255)
		part.Material = Enum.Material.Glass
		part.Transparency = math.max(part.Transparency, 0.15)
	elseif mutationId == "Pumpkin" then
		part.Color = Color3.fromRGB(255, 120, 20)
	elseif mutationId == "Ghost" then
		part.Material = Enum.Material.ForceField
		part.Color = Color3.fromRGB(190, 255, 240)
	end
end

local function buildPrimitive(model: Model, body: BasePart, creature: any, height: number): BasePart
	local shapeName = creature.Shape or "Ball"
	local visual = body
	if shapeName == "Ball" then
		body.Shape = Enum.PartType.Ball
		body.Size = Vector3.one * height
	elseif shapeName == "Cylinder" then
		-- Ось цилиндра у Part — X, поэтому видимую часть делаем отдельной деталью, повёрнутой
		-- вертикально, а Body оставляем невидимым блоком-«хитбоксом».
		body.Shape = Enum.PartType.Block
		body.Size = Vector3.new(height * 0.75, height, height * 0.75)
		body.Transparency = 1
		local shell = Instance.new("Part")
		shell.Name = "Shell"
		shell.Shape = Enum.PartType.Cylinder
		shell.Size = Vector3.new(height, height * 0.75, height * 0.75)
		shell.CFrame = body.CFrame * CFrame.Angles(0, 0, math.rad(90))
		shell.Color = creature.Color
		shell.Material = Enum.Material.SmoothPlastic
		weld(shell, body)
		shell.Parent = model
		visual = shell
	else
		body.Shape = Enum.PartType.Block
		body.Size = Vector3.new(height * 0.9, height, height * 0.9)
	end
	if visual == body then
		body.Color = creature.Color
		body.Material = Enum.Material.SmoothPlastic
		body.Transparency = 0
	end

	-- Ножки
	for _, side in { -1, 1 } do
		local foot = Instance.new("Part")
		foot.Name = "Foot"
		foot.Size = Vector3.new(height * 0.22, height * 0.18, height * 0.3)
		foot.Color = creature.Color:Lerp(Color3.new(0, 0, 0), 0.35)
		foot.Material = Enum.Material.SmoothPlastic
		foot.CFrame = body.CFrame * CFrame.new(side * height * 0.22, -height / 2 + foot.Size.Y / 2 - 0.05, -height * 0.05)
		weld(foot, body)
		foot.Parent = model
	end

	-- Эмодзи-лицо: всегда смотрит в камеру
	local face = Instance.new("BillboardGui")
	face.Name = "Face"
	face.Size = UDim2.fromScale(height * 1.1, height * 0.8)
	face.LightInfluence = 0
	face.MaxDistance = 120
	face.Parent = body
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Text = creature.Face
	label.Parent = face
	return visual
end

local function buildFromAsset(model: Model, body: BasePart, template: Model, height: number)
	local clone = template:Clone()
	local _, size = clone:GetBoundingBox()
	local scale = height / math.max(size.Y, 0.1)
	if scale > 0 and math.abs(scale - 1) > 0.01 then
		pcall(function()
			clone:ScaleTo(scale)
		end)
	end
	local cf, newSize = clone:GetBoundingBox()
	body.Size = newSize
	body.Transparency = 1
	body.CFrame = cf
	for _, part in clone:GetDescendants() do
		if part:IsA("BasePart") then
			weld(part, body)
		end
	end
	clone.Parent = model
end

-- Создаёт модель мема в точке cframe (низ модели на уровне cframe.Position).
-- Возвращает модель без Parent: вызывающий сам добавит промпты и поставит Parent.
function MemeFactory.Create(id: string, mutationId: string, viral: boolean, cframe: CFrame): Model
	local creature = Config.GetCreature(id)
	assert(creature, "Неизвестный мем: " .. tostring(id))

	local height = BASE_SIZE * (creature.Size or 1) * (if viral then VIRAL_SCALE else 1)

	local model = Instance.new("Model")
	model.Name = id

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Anchored = true
	body.CanCollide = false
	body.CanTouch = false
	body.CastShadow = true
	body.Size = Vector3.one * height
	body.CFrame = cframe * CFrame.new(0, height / 2 + height * 0.12, 0)
	body.Parent = model
	model.PrimaryPart = body

	local template = if creature.ModelId and creature.ModelId ~= 0 then loadTemplate(creature.ModelId) else nil
	if template then
		buildFromAsset(model, body, template, height)
	else
		local visual = buildPrimitive(model, body, creature, height)
		applyMutation(visual, mutationId)
	end

	if mutationId ~= "None" or viral then
		local mutation = Config.GetMutation(mutationId)
		local color = mutation.Color or Config.GetRarity(creature.Rarity).Color
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = height * 3
		light.Brightness = if viral then 3 else 1.5
		light.Parent = body
		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Name = "Sparkles"
		sparkles.Color = ColorSequence.new(color)
		sparkles.LightEmission = 1
		sparkles.Size = NumberSequence.new(0.35, 0)
		sparkles.Lifetime = NumberRange.new(0.8, 1.4)
		sparkles.Rate = if viral then 14 else 6
		sparkles.Speed = NumberRange.new(1, 3)
		sparkles.SpreadAngle = Vector2.new(180, 180)
		sparkles.Parent = body
	end

	local rarityId = creature.Rarity
	if rarityId == "God" or rarityId == "Secret" or rarityId == "Mythic" then
		local aura = Instance.new("ParticleEmitter")
		aura.Name = "Aura"
		aura.Color = ColorSequence.new(Config.GetRarity(rarityId).Color)
		aura.LightEmission = 0.6
		aura.Size = NumberSequence.new(height * 0.25, 0)
		aura.Lifetime = NumberRange.new(1, 1.6)
		aura.Rate = 10
		aura.Speed = NumberRange.new(2, 4)
		aura.Parent = body
	end

	model:SetAttribute("CreatureId", id)
	model:SetAttribute("Mutation", mutationId)
	model:SetAttribute("Viral", viral)
	model:SetAttribute("Height", body.Size.Y)
	model:SetAttribute("State", "Carpet")
	model:SetAttribute("OwnerUserId", 0)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	CollectionService:AddTag(model, "Meme")
	return model
end

-- Высота от низа модели до центра Body (чтобы ставить мема на пол)
function MemeFactory.BodyOffset(model: Model): number
	local body = model.PrimaryPart :: BasePart
	return body.Size.Y / 2 + body.Size.Y * 0.12
end

function MemeFactory.AddPrompt(model: Model, name: string, actionText: string, holdDuration: number?): ProximityPrompt
	local body = model.PrimaryPart :: BasePart
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = name
	prompt.ActionText = actionText
	prompt.ObjectText = Config.GetCreature(model:GetAttribute("CreatureId")).Name
	prompt.HoldDuration = holdDuration or 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = if name == "SellPrompt" then Enum.KeyCode.F elseif name == "MergePrompt" then Enum.KeyCode.R else Enum.KeyCode.E
	prompt.UIOffset = if name == "SellPrompt" then Vector2.new(0, 70) elseif name == "MergePrompt" then Vector2.new(0, 140) else Vector2.zero
	prompt.Parent = body
	return prompt
end

-- Сделать модель «переносимой»: привариваем Body к точке над головой персонажа.
function MemeFactory.AttachTo(model: Model, root: BasePart, offset: CFrame)
	local body = model.PrimaryPart :: BasePart
	body.Anchored = false
	body.Massless = true
	body.CFrame = root.CFrame * offset
	local constraint = Instance.new("WeldConstraint")
	constraint.Name = "CarryWeld"
	constraint.Part0 = root
	constraint.Part1 = body
	constraint.Parent = body
end

function MemeFactory.Detach(model: Model)
	local body = model.PrimaryPart :: BasePart
	local constraint = body:FindFirstChild("CarryWeld")
	if constraint then
		constraint:Destroy()
	end
	body.Anchored = true
end

return MemeFactory
