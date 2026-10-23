--!strict
-- Floating signs (MAP_BRIEF_REPLAN stage 3). Every sign the map builder tags Sign is a lit panel with its text printed
-- on it. From far away that is all a player sees, so signs never crowd the screen. Within GameConfig.Map.Signs range,
-- the text of the side facing the camera floats out in front of the panel, turned to face the camera at a fixed
-- on-screen size so it always reads. It fades in as the player gets closer while the printed text fades out. Walls
-- still hide it (it is not drawn on top), so a sign never shows through into another room. Purely visual and local.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local SignController = {}

local config = GameConfig.Map.Signs
local PANEL_COLOR = Color3.fromRGB(20, 22, 26)
local PANEL_TRANSPARENCY = 0.15

type Side = { text: string, color: Color3, normal: Vector3 }
type Sign = {
	part: BasePart,
	sides: { Side },
	billboard: BillboardGui,
	group: CanvasGroup,
	label: TextLabel,
	printed: { TextLabel },
	shown: number, -- the last fade applied: 0 hidden, 1 fully floating
	side: Side?,
}
local signs: { [BasePart]: Sign } = {}

local function sidesOf(part: BasePart): { Side }
	local sides: { Side } = {}
	for index = 1, 2 do
		local text, color, normal =
			part:GetAttribute(`Text{index}`), part:GetAttribute(`Color{index}`), part:GetAttribute(`Normal{index}`)
		if type(text) == "string" and typeof(color) == "Color3" and typeof(normal) == "Vector3" then
			table.insert(sides, { text = text, color = color, normal = normal })
		end
	end
	return sides
end

local function add(instance: Instance)
	if not instance:IsA("BasePart") or signs[instance] then
		return
	end
	local sides = sidesOf(instance)
	if #sides == 0 then
		return
	end
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "FloatingSign"
	billboard.Size = config.FloatSize
	billboard.LightInfluence = 0
	billboard.AlwaysOnTop = false -- walls hide it, like the panel itself
	billboard.MaxDistance = config.FadeOutStuds
	billboard.Enabled = false
	local group = Instance.new("CanvasGroup")
	group.Size = UDim2.fromScale(1, 1)
	group.BackgroundColor3 = PANEL_COLOR
	group.BackgroundTransparency = PANEL_TRANSPARENCY
	group.GroupTransparency = 1
	group.Parent = billboard
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.2, 0)
	corner.Parent = group
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Parent = group
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.06, 0)
	padding.PaddingRight = UDim.new(0.06, 0)
	padding.PaddingTop = UDim.new(0.15, 0)
	padding.PaddingBottom = UDim.new(0.15, 0)
	padding.Parent = label
	billboard.Adornee = instance
	billboard.Parent = instance
	local printed: { TextLabel } = {}
	for _, gui in instance:GetChildren() do
		if gui:IsA("SurfaceGui") then
			local text = gui:FindFirstChildOfClass("TextLabel")
			if text then
				table.insert(printed, text)
			end
		end
	end
	signs[instance] = {
		part = instance,
		sides = sides,
		billboard = billboard,
		group = group,
		label = label,
		printed = printed,
		shown = 0,
	}
end

local function remove(instance: Instance)
	if instance:IsA("BasePart") then
		local sign = signs[instance]
		if sign then
			sign.billboard:Destroy()
			signs[instance] = nil
		end
	end
end

local function update(sign: Sign, eye: Vector3)
	local toEye = eye - sign.part.Position
	local distance = toEye.Magnitude
	local shown = math.clamp((config.FadeOutStuds - distance) / (config.FadeOutStuds - config.FadeInStuds), 0, 1)
	-- The side that faces the reader.
	local best: Side? = nil
	for _, side in sign.sides do
		if toEye:Dot(side.normal) > 0 then
			best = side
		end
	end
	if not best then
		shown = 0
	end
	if shown == sign.shown and best == sign.side then
		return
	end
	sign.shown = shown
	if best and best ~= sign.side then
		sign.side = best
		sign.label.Text = best.text
		sign.label.TextColor3 = best.color
		sign.billboard.StudsOffsetWorldSpace = best.normal * config.FloatOffset
	end
	sign.billboard.Enabled = shown > 0
	sign.group.GroupTransparency = 1 - shown
	for _, text in sign.printed do
		text.TextTransparency = shown
	end
end

function SignController.Init() end

function SignController.Start()
	for _, instance in CollectionService:GetTagged(Enums.Tag.Sign) do
		add(instance)
	end
	CollectionService:GetInstanceAddedSignal(Enums.Tag.Sign):Connect(add)
	CollectionService:GetInstanceRemovedSignal(Enums.Tag.Sign):Connect(remove)

	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local eye = camera.CFrame.Position
		for _, sign in signs do
			update(sign, eye)
		end
	end)
end

return SignController
