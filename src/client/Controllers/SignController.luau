--!strict
-- Floating signs (MAP_BRIEF_REPLAN stage 3, reworked after the stage 4 review). Signs have no panels: the map builder
-- tags invisible anchors Sign, and this floats words from them. Three kinds (the Kind attribute):
--   (none)        over a doorway or a stair end: EXIT, RESTROOMS, EXTRACTION, UP TO / DOWN TO, on the side facing the reader
--   "RoomName"    over a doorway: each side floats the name of the room beyond it
--   "Directions"  inside a doorway: rows naming the nearest stairs, restrooms and extraction, each with an arrow turned
--                 toward it from where the camera looks, and how far it is
-- The words are soft, with no box behind them, and outlined in the tier colour of the area they lead to. They only show
-- within GameConfig.Map.Signs range, fading smoothly with distance. Billboards are made only while a sign is in range.
-- Walls still hide the words (they are not drawn on top), so they never show through into another room. Purely visual
-- and local.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local SignController = {}

local config = GameConfig.Map.Signs
local FONT = Enum.Font.GothamMedium
local ARROW = "▲" -- turned by its Rotation: straight up on screen is straight ahead

type Side = { text: string, color: Color3, normal: Vector3, tier: number }
type Row = { label: string, color: Color3, target: Vector3, tier: number }
type RowView = { arrow: TextLabel, distance: TextLabel, texts: { TextLabel }, strokes: { UIStroke }, meters: number }
type View = {
	billboard: BillboardGui,
	label: TextLabel?, -- a sided sign's floating text
	stroke: UIStroke?,
	rows: { RowView }, -- a signpost's rows
}
type Sign = {
	part: BasePart,
	sides: { Side }, -- empty for a signpost
	rows: { Row }, -- empty unless a signpost
	shown: number, -- the current fade: 0 hidden, 1 fully floating
	side: Side?,
	view: View?,
}
local signs: { [BasePart]: Sign } = {}

local function tierColor(tier: number): Color3
	return GameConfig.Zones.TierColors[tier] or GameConfig.Zones.TierColors[0]
end

local function sidesOf(part: BasePart): { Side }
	local sides: { Side } = {}
	for index = 1, 2 do
		local text, color, normal, tier =
			part:GetAttribute(`Text{index}`),
			part:GetAttribute(`Color{index}`),
			part:GetAttribute(`Normal{index}`),
			part:GetAttribute(`Tier{index}`)
		if type(text) == "string" and typeof(color) == "Color3" and typeof(normal) == "Vector3" then
			table.insert(
				sides,
				{ text = text, color = color, normal = normal, tier = if type(tier) == "number" then tier else 0 }
			)
		end
	end
	return sides
end

local function rowsOf(part: BasePart): { Row }
	local rows: { Row } = {}
	local index = 1
	while true do
		local label, color, target, tier =
			part:GetAttribute(`Label{index}`),
			part:GetAttribute(`Color{index}`),
			part:GetAttribute(`Target{index}`),
			part:GetAttribute(`Tier{index}`)
		if type(label) ~= "string" or typeof(color) ~= "Color3" or typeof(target) ~= "Vector3" then
			return rows
		end
		table.insert(
			rows,
			{ label = label, color = color, target = target, tier = if type(tier) == "number" then tier else 0 }
		)
		index += 1
	end
end

-- Soft floating text with a tier-colour outline.
local function softText(parent: Instance, color: Color3, outline: Color3): (TextLabel, UIStroke)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = FONT
	label.TextScaled = true
	label.TextColor3 = color
	label.TextTransparency = 1
	label.Parent = parent
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Color = outline
	stroke.Thickness = config.OutlineThickness
	stroke.Transparency = 1
	stroke.Parent = label
	return label, stroke
end

local function makeView(sign: Sign): View
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "FloatingSign"
	billboard.LightInfluence = 0
	billboard.AlwaysOnTop = false -- walls hide it, so it never shows into another room
	billboard.Adornee = sign.part
	local view: View = { billboard = billboard, rows = {} }
	if #sign.rows > 0 then
		local rowSize = config.RowSize
		billboard.Size = UDim2.new(rowSize.X, UDim.new(0, rowSize.Y.Offset * #sign.rows))
		local list = Instance.new("UIListLayout")
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Parent = billboard
		for index, row in sign.rows do
			local frame = Instance.new("Frame")
			frame.BackgroundTransparency = 1
			frame.Size = UDim2.new(1, 0, 0, rowSize.Y.Offset)
			frame.LayoutOrder = index
			frame.Parent = billboard
			local outline = tierColor(row.tier)
			local arrow, arrowStroke = softText(frame, row.color, outline)
			arrow.Text = ARROW
			arrow.Size = UDim2.fromScale(0.15, 0.8)
			arrow.Position = UDim2.fromScale(0, 0.1)
			local place, placeStroke = softText(frame, row.color, outline)
			place.Text = row.label
			place.TextXAlignment = Enum.TextXAlignment.Left
			place.Size = UDim2.fromScale(0.6, 0.8)
			place.Position = UDim2.fromScale(0.18, 0.1)
			local distance, distanceStroke = softText(frame, row.color, outline)
			distance.TextXAlignment = Enum.TextXAlignment.Right
			distance.Size = UDim2.fromScale(0.22, 0.7)
			distance.Position = UDim2.fromScale(0.78, 0.15)
			table.insert(view.rows, {
				arrow = arrow,
				distance = distance,
				texts = { arrow, place, distance },
				strokes = { arrowStroke, placeStroke, distanceStroke },
				meters = -1,
			})
		end
	else
		billboard.Size = config.FloatSize
		local label, stroke = softText(billboard, Color3.new(1, 1, 1), Color3.new(1, 1, 1))
		label.Size = UDim2.fromScale(1, 1)
		view.label, view.stroke = label, stroke
	end
	billboard.Parent = sign.part
	return view
end

local function add(instance: Instance)
	if not instance:IsA("BasePart") or signs[instance] then
		return
	end
	local kind = instance:GetAttribute("Kind")
	local sides = if kind == "Directions" then {} else sidesOf(instance)
	local rows = if kind == "Directions" then rowsOf(instance) else {}
	if #sides == 0 and #rows == 0 then
		return
	end
	signs[instance] = {
		part = instance,
		sides = sides,
		rows = rows,
		shown = 0,
	}
end

local function remove(instance: Instance)
	if instance:IsA("BasePart") then
		local sign = signs[instance]
		if sign then
			if sign.view then
				sign.view.billboard:Destroy()
			end
			signs[instance] = nil
		end
	end
end

-- Applies the fade to the floating words.
local function applyFade(sign: Sign)
	local fade = 1 - sign.shown
	local view = sign.view
	if not view then
		return
	end
	if view.label and view.stroke then
		view.label.TextTransparency = fade
		view.stroke.Transparency = fade
	end
	for _, row in view.rows do
		for _, text in row.texts do
			text.TextTransparency = fade
		end
		for _, stroke in row.strokes do
			stroke.Transparency = fade
		end
	end
end

local function update(sign: Sign, camera: CFrame, dt: number)
	local eye = camera.Position
	local toEye = eye - sign.part.Position
	local distance = toEye.Magnitude
	if distance > config.FadeOutStuds and sign.shown == 0 and not sign.view then
		return -- out of range and already hidden: nothing to do
	end
	local target = math.clamp((config.FadeOutStuds - distance) / (config.FadeOutStuds - config.FadeInStuds), 0, 1)
	-- A sided sign shows the side that faces the reader; turning to the other side fades the new text in afresh.
	if #sign.sides > 0 then
		local best: Side? = nil
		for _, side in sign.sides do
			if toEye:Dot(side.normal) > 0 then
				best = side
			end
		end
		if not best then
			target = 0
		elseif best ~= sign.side then
			sign.side = best
			sign.shown = 0
			if sign.view then
				local view = sign.view
				local label, stroke = view.label :: TextLabel, view.stroke :: UIStroke
				label.Text = best.text
				label.TextColor3 = best.color
				stroke.Color = tierColor(best.tier)
				view.billboard.StudsOffsetWorldSpace = best.normal * config.FloatOffset
			end
		end
	end
	local step = dt / config.FadeSeconds
	local shown = sign.shown + math.clamp(target - sign.shown, -step, step)
	if shown > 0 and not sign.view then
		local view = makeView(sign)
		sign.view = view
		local side = sign.side
		if side and view.label and view.stroke then
			view.label.Text = side.text
			view.label.TextColor3 = side.color
			view.stroke.Color = tierColor(side.tier)
			view.billboard.StudsOffsetWorldSpace = side.normal * config.FloatOffset
		end
	end
	if shown ~= sign.shown then
		sign.shown = shown
		applyFade(sign)
	end
	local view = sign.view
	if not view then
		return
	end
	if shown == 0 and target == 0 then
		view.billboard:Destroy()
		sign.view = nil
		return
	end
	-- Signpost arrows point at their targets as seen from the camera, flattened onto the floor.
	if #view.rows > 0 then
		local look = Vector3.new(camera.LookVector.X, 0, camera.LookVector.Z)
		local right = Vector3.new(camera.RightVector.X, 0, camera.RightVector.Z)
		for index, row in view.rows do
			local goal = sign.rows[index].target
			local toward = Vector3.new(goal.X - eye.X, 0, goal.Z - eye.Z)
			row.arrow.Rotation = math.deg(math.atan2(toward:Dot(right), toward:Dot(look)))
			local meters = math.floor(toward.Magnitude * config.MetersPerStud + 0.5)
			if meters ~= row.meters then
				row.meters = meters
				row.distance.Text = `{meters} m`
			end
		end
	end
end

function SignController.Init() end

function SignController.Start()
	for _, instance in CollectionService:GetTagged(Enums.Tag.Sign) do
		add(instance)
	end
	CollectionService:GetInstanceAddedSignal(Enums.Tag.Sign):Connect(add)
	CollectionService:GetInstanceRemovedSignal(Enums.Tag.Sign):Connect(remove)

	RunService.RenderStepped:Connect(function(dt: number)
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local frame = camera.CFrame
		for _, sign in signs do
			update(sign, frame, dt)
		end
	end)
end

return SignController
