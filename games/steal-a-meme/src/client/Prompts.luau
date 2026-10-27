-- ProximityPrompt мемов и замков баз: перевод ActionText/ObjectText и локальное выключение лишних
-- (Украсть — на своих, Продать/Слить — на чужих, Слить — только если есть Config.Viral.Count одинаковых,
-- Замок — только на своей базе). Сервер всё равно проверяет каждое действие сам.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))
local Locale = require(Shared:WaitForChild("Locale"))
local Util = require(script.Parent:WaitForChild("Util"))

local player = Players.LocalPlayer

local Prompts = {}

-- ===== Управляемые подсказки =====
-- Enabled = (значение сервера) and (локальное правило). Значение сервера запоминаем,
-- чтобы при снятии локального запрета вернуть именно его, а не включить то, что сервер выключил.
type Managed = {
	Server: boolean,
	Expected: boolean?,
	Rule: () -> (boolean, string?, string?), -- (можно ли, ActionText, ObjectText)
	Connections: { RBXScriptConnection },
}
local managed: { [ProximityPrompt]: Managed } = {}

local function setIfDiff(prompt: ProximityPrompt, property: string, value: any)
	if (prompt :: any)[property] ~= value then
		(prompt :: any)[property] = value
	end
end

local function apply(prompt: ProximityPrompt)
	local entry = managed[prompt]
	if not entry then
		return
	end
	local ok, allowed, action, object = pcall(entry.Rule)
	if not ok then
		return
	end
	if action then
		setIfDiff(prompt, "ActionText", action)
	end
	if object then
		setIfDiff(prompt, "ObjectText", object)
	end
	local want = entry.Server and allowed
	entry.Expected = want
	setIfDiff(prompt, "Enabled", want)
end

local function manage(prompt: ProximityPrompt, rule: () -> (boolean, string?, string?))
	local existing = managed[prompt]
	if existing then
		existing.Rule = rule
		apply(prompt)
		return
	end
	local entry: Managed = { Server = prompt.Enabled, Expected = nil, Rule = rule, Connections = {} }
	managed[prompt] = entry
	table.insert(
		entry.Connections,
		prompt:GetPropertyChangedSignal("Enabled"):Connect(function()
			-- Сигналы отложенные: своё же изменение узнаём по Expected
			if prompt.Enabled ~= entry.Expected then
				entry.Server = prompt.Enabled
				apply(prompt)
			end
		end)
	)
	-- Сервер мог переписать текст — переводим заново
	for _, property in { "ActionText", "ObjectText" } do
		table.insert(entry.Connections, prompt:GetPropertyChangedSignal(property):Connect(function()
			task.defer(apply, prompt)
		end))
	end
	table.insert(entry.Connections, prompt.Destroying:Connect(function()
		for _, connection in entry.Connections do
			connection:Disconnect()
		end
		managed[prompt] = nil
	end))
	apply(prompt)
end

-- ===== Мемы =====
local memes: { [Instance]: boolean } = {}

-- Имя мема с мутацией и пометкой вирусности: «Gold Kolobok», «VIRAL Kolobok»
local function memeTitle(model: Instance): string
	local name = Locale.MemeName(Util.str(model, "CreatureId"))
	local mutation = Config.GetMutation(Util.str(model, "Mutation"))
	if mutation.Id ~= "None" then
		name = Locale.Name(mutation) .. " " .. name
	end
	if Util.bool(model, "Viral") then
		name = Locale.T("BbViral") .. " " .. name
	end
	return name
end

local function myMemesFolder(): Instance?
	local plot = Util.myPlot()
	return plot and plot:FindFirstChild("Memes")
end

local function isMine(model: Instance): boolean
	return Util.num(model, "OwnerUserId") == player.UserId
end

-- Сколько у игрока на базе таких же невирусных мемов (тот же вид и мутация), включая этот
local function sameCount(model: Instance): number
	local folder = myMemesFolder()
	local id, mutation = Util.str(model, "CreatureId"), Util.str(model, "Mutation")
	local count = 0
	for other in memes do
		local onBase = if folder then other.Parent == folder else isMine(other)
		if
			onBase
			and isMine(other)
			and not Util.bool(other, "Viral")
			and Util.str(other, "State") ~= "Carried"
			and Util.str(other, "CreatureId") == id
			and Util.str(other, "Mutation") == mutation
		then
			count += 1
		end
	end
	return count
end

local function ruleFor(model: Instance, prompt: ProximityPrompt): (() -> (boolean, string?, string?))?
	if prompt.Name == "BuyPrompt" then
		return function()
			local price = Util.num(model, "Price")
			return true, Locale.T("PromptBuy"), memeTitle(model) .. " — $" .. Format.Number(price)
		end
	elseif prompt.Name == "StealPrompt" then
		return function()
			-- Быстрая кража: только время удержания на клиенте, сервер проверяет сам
			prompt.HoldDuration = if Util.bool(player, "Pass_FastSteal")
				then Config.Steal.FastHoldDuration
				else Config.Steal.HoldDuration
			local allowed = not isMine(model)
				and Util.str(player, "Carrying") == ""
				and Util.str(model, "State") ~= "Carried"
			return allowed, Locale.T("PromptSteal"), memeTitle(model)
		end
	elseif prompt.Name == "SellPrompt" then
		return function()
			return isMine(model), Locale.T("PromptSell"), memeTitle(model)
		end
	elseif prompt.Name == "MergePrompt" then
		return function()
			local allowed = isMine(model) and not Util.bool(model, "Viral") and sameCount(model) >= Config.Viral.Count
			return allowed, Locale.T("PromptMerge", { Count = Config.Viral.Count }), memeTitle(model)
		end
	end
	return nil
end

-- Перепроверить все подсказки мемов (одним пакетом за кадр)
local refreshQueued = false
local function refreshAll()
	if refreshQueued then
		return
	end
	refreshQueued = true
	task.defer(function()
		refreshQueued = false
		for prompt in managed do
			apply(prompt)
		end
	end)
end

local function trackMeme(model: Instance): () -> ()
	memes[model] = true
	local connections: { RBXScriptConnection } = {}

	local function hookPrompt(child: Instance)
		if child:IsA("ProximityPrompt") then
			local rule = ruleFor(model, child)
			if rule then
				manage(child, rule)
			end
		end
	end

	local function hookBody(body: Instance)
		for _, child in body:GetChildren() do
			hookPrompt(child)
		end
		table.insert(connections, body.ChildAdded:Connect(hookPrompt))
	end

	local body = model:FindFirstChild("Body")
	if body then
		hookBody(body)
	end
	-- StreamingEnabled: Body может прийти позже или подгрузиться заново
	table.insert(connections, model.ChildAdded:Connect(function(child)
		if child.Name == "Body" then
			hookBody(child)
		end
	end))
	table.insert(connections, model.AttributeChanged:Connect(refreshAll))
	table.insert(connections, model.AncestryChanged:Connect(refreshAll))
	refreshAll()

	return function()
		memes[model] = nil
		for _, connection in connections do
			connection:Disconnect()
		end
		refreshAll()
	end
end

-- ===== Замки баз =====
local function trackPlot(plot: Instance)
	local function hookButton(button: Instance)
		local function hookPrompt(prompt: Instance)
			if not prompt:IsA("ProximityPrompt") then
				return
			end
			manage(prompt, function()
				local mine = Util.num(plot, "OwnerUserId") == player.UserId
				return mine, Locale.T("PromptLock"), Locale.T("PromptLockObject", { Seconds = Config.Plot.LockDuration })
			end)
		end
		local prompt = button:FindFirstChild("LockPrompt")
		if prompt then
			hookPrompt(prompt)
		end
		button.ChildAdded:Connect(function(child)
			if child.Name == "LockPrompt" then
				hookPrompt(child)
			end
		end)
	end

	local button = plot:FindFirstChild("LockButton")
	if button then
		hookButton(button)
	end
	plot.ChildAdded:Connect(function(child)
		if child.Name == "LockButton" then
			hookButton(child)
		end
	end)
	plot:GetAttributeChangedSignal("OwnerUserId"):Connect(refreshAll)
end

function Prompts.Start()
	for _, name in { "Carrying", "Pass_FastSteal", "Plot" } do
		player:GetAttributeChangedSignal(name):Connect(refreshAll)
	end
	Util.watchTagged("Meme", trackMeme)
	Util.forEachPlot(trackPlot)
end

return Prompts
