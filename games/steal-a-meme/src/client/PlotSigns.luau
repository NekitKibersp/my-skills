-- Таблички баз: SurfaceGui на Sign каждой базы (Face = Front) — имя хозяина или «Свободно»,
-- замок с таймером, своя база подсвечена зелёным. SurfaceGui живут в PlayerGui с Adornee = Sign,
-- поэтому не пропадают при стриминге: Sign вернулся — снова привязываем.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Locale = require(Shared:WaitForChild("Locale"))
local UiKit = require(script.Parent:WaitForChild("UiKit"))
local Util = require(script.Parent:WaitForChild("Util"))

local COLORS = UiKit.Colors
local create = UiKit.create
local player = Players.LocalPlayer

local OWN_COLOR = Color3.fromRGB(40, 150, 70)
local LOCK_COLOR = Color3.fromRGB(255, 120, 100)

local PlotSigns = {}

type Sign = {
	Plot: Instance,
	Gui: SurfaceGui,
	Background: Frame,
	Owner: TextLabel,
	Status: TextLabel,
}

function PlotSigns.Start()
	local folder = create("Folder", { Name = "PlotSigns", Parent = player:WaitForChild("PlayerGui") })
	local signs: { Sign } = {}

	Util.forEachPlot(function(plot: Instance)
		local gui = create("SurfaceGui", {
			Name = plot.Name,
			Face = Enum.NormalId.Front,
			SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
			PixelsPerStud = 40,
			LightInfluence = 0,
			ResetOnSpawn = false,
			Parent = folder,
		})
		local background = create("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = COLORS.Panel,
			Parent = gui,
		}, { UiKit.padding(6) })
		local owner = UiKit.text({
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextStrokeTransparency = 0.4,
			Size = UDim2.fromScale(1, 0.6),
			Parent = background,
		})
		local status = UiKit.text({
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromScale(0, 0.62),
			Size = UDim2.fromScale(1, 0.38),
			Parent = background,
		})
		table.insert(signs, { Plot = plot, Gui = gui, Background = background, Owner = owner, Status = status })
	end)

	local function render(sign: Sign)
		local plot = sign.Plot
		if not plot.Parent then
			return
		end
		local signPart = plot:FindFirstChild("Sign")
		sign.Gui.Adornee = if signPart and signPart:IsA("BasePart") then signPart else nil
		if not sign.Gui.Adornee then
			return
		end

		local ownerId = Util.num(plot, "OwnerUserId")
		local mine = ownerId == player.UserId
		if ownerId == 0 then
			sign.Owner.Text = Locale.T("SignFree")
			sign.Owner.TextColor3 = COLORS.Muted
		else
			local name = Util.str(plot, "OwnerName")
			sign.Owner.Text = if mine then Locale.T("SignYours") else name
			sign.Owner.TextColor3 = if mine then Color3.new(1, 1, 1) else COLORS.Gold
		end
		sign.Background.BackgroundColor3 = if mine then OWN_COLOR else COLORS.Panel

		local lockedLeft = Util.num(plot, "LockedUntil") - Util.now()
		if ownerId ~= 0 and lockedLeft > 0 then
			sign.Status.Text = "🔒 " .. Util.clock(lockedLeft)
			sign.Status.TextColor3 = LOCK_COLOR
		else
			sign.Status.Text = if mine then Util.str(plot, "OwnerName") else ""
			sign.Status.TextColor3 = Color3.new(1, 1, 1)
		end
	end

	task.spawn(function()
		while true do
			for _, sign in signs do
				render(sign)
			end
			task.wait(0.25)
		end
	end)
end

return PlotSigns
