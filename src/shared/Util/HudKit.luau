--!strict
-- Small helpers for building the HUD from code (STYLE_QUESTIONS D2: minimal, bold pixel-style font). Client only.
--
--   HudKit.screen(name) -> ScreenGui                    a gui that survives respawns, under PlayerGui
--   HudKit.text(parent, name, position, anchor, size) -> TextLabel
--   HudKit.edgeGlow(parent, color) -> EdgeGlow          soft colored glow along the screen edges

local Players = game:GetService("Players")

local GameConfig = require(script.Parent.Parent.GameConfig)
local HudTheme = require(script.Parent.HudTheme)
local HudScale = require(script.Parent.HudScale)

local ui = GameConfig.UI
local graphics = HudTheme.get()

export type EdgeGlow = {
	setSide: (side: string, transparency: number) -> (), -- "Top", "Bottom", "Left" or "Right"
	setAll: (transparency: number) -> (),
}

local HudKit = {}

-- Ticket HUD refresh: normalized vector strokes, built once. These are drawing coordinates, not gameplay tunables.
local ICONS: { [string]: { { number } } } = {
	Alarm = {
		{ 0.5, 0.08, 0.92, 0.86 },
		{ 0.92, 0.86, 0.08, 0.86 },
		{ 0.08, 0.86, 0.5, 0.08 },
		{ 0.5, 0.35, 0.5, 0.57 },
		{ 0.5, 0.69, 0.5, 0.72 },
	},
	Shield = {
		{ 0.15, 0.18, 0.85, 0.18 },
		{ 0.85, 0.18, 0.8, 0.65 },
		{ 0.8, 0.65, 0.5, 0.92 },
		{ 0.5, 0.92, 0.2, 0.65 },
		{
			0.2,
			0.65,
			0.15,
			0.18,
		},
	},
	Intel = {
		{ 0.2, 0.2, 0.8, 0.2 },
		{ 0.8, 0.2, 0.8, 0.8 },
		{ 0.8, 0.8, 0.2, 0.8 },
		{ 0.2, 0.8, 0.2, 0.2 },
		{ 0.35, 0.4, 0.65, 0.4 },
		{ 0.35, 0.6, 0.65, 0.6 },
		{ 0.4, 0.05, 0.4, 0.2 },
		{ 0.6, 0.8, 0.6, 0.95 },
	},
	Health = { { 0.5, 0.12, 0.5, 0.88 }, { 0.12, 0.5, 0.88, 0.5 } },
	Badge = {
		{ 0.08, 0.18, 0.92, 0.18 },
		{ 0.92, 0.18, 0.92, 0.82 },
		{ 0.92, 0.82, 0.08, 0.82 },
		{ 0.08, 0.82, 0.08, 0.18 },
		{ 0.3, 0.37, 0.3, 0.45 },
		{ 0.22, 0.64, 0.38, 0.64 },
		{ 0.56, 0.4, 0.78, 0.4 },
		{ 0.56, 0.6, 0.78, 0.6 },
	},
	Bullet = {
		{ 0.3, 0.82, 0.7, 0.82 },
		{ 0.3, 0.82, 0.3, 0.3 },
		{ 0.7, 0.82, 0.7, 0.3 },
		{ 0.3, 0.3, 0.5, 0.08 },
		{ 0.5, 0.08, 0.7, 0.3 },
		{ 0.3, 0.65, 0.7, 0.65 },
	},
	Eye = {
		{ 0.05, 0.5, 0.3, 0.23 },
		{ 0.3, 0.23, 0.7, 0.23 },
		{ 0.7, 0.23, 0.95, 0.5 },
		{ 0.95, 0.5, 0.7, 0.77 },
		{ 0.7, 0.77, 0.3, 0.77 },
		{ 0.3, 0.77, 0.05, 0.5 },
		{ 0.5, 0.38, 0.5, 0.62 },
	},
}

function HudKit.panel(
	parent: Instance,
	name: string,
	position: UDim2,
	anchor: Vector2,
	size: UDim2,
	surface: boolean?
): Frame
	local root = Instance.new("Frame")
	root.Name = name
	root.BackgroundTransparency = 1
	root.Position, root.AnchorPoint, root.Size = position, anchor, size
	root.Parent = parent
	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.Position = UDim2.fromOffset(graphics.ShadowOffsetPixels, graphics.ShadowOffsetPixels)
	shadow.Size = UDim2.fromScale(1, 1)
	shadow.BorderSizePixel = 0
	shadow.BackgroundColor3 = Color3.new(0, 0, 0)
	shadow.BackgroundTransparency = 1
	shadow.Parent = root
	local back = Instance.new("Frame")
	back.Name = "Backdrop"
	back.Size = UDim2.fromScale(1, 1)
	back.BorderSizePixel = 0
	back.BackgroundColor3 = graphics.PanelColor
	back.BackgroundTransparency = if surface then ui.FloatingHud.SurfaceTransparency else 1
	back.Parent = root
	for _, frame in { shadow, back } do
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, graphics.CornerPixels)
		corner.Parent = frame
	end
	local border = Instance.new("UIStroke")
	border.Color = graphics.BorderColor
	border.Transparency = if surface then 0.7 else 1
	border.Thickness = graphics.StrokePixels
	border.Parent = back
	local accent = Instance.new("Frame")
	accent.Name = "MapAccent"
	accent.Visible = surface == true
	accent.BorderSizePixel = 0
	accent.BackgroundColor3 = graphics.AccentColor
	accent.Position = UDim2.fromOffset(graphics.PaddingPixels, 0)
	accent.Size = UDim2.new(graphics.AccentWidthFraction, 0, 0, graphics.AccentThicknessPixels)
	accent.Parent = back
	HudScale.bind(root, if parent:IsA("GuiObject") then parent else nil)
	return back
end

function HudKit.icon(
	parent: Instance,
	name: string,
	position: UDim2,
	pixels: number,
	color: Color3,
	drawing: { { number } }?,
	strokeFraction: number? -- line thickness against the icon size; the HUD's own by default
): Frame
	local segments = drawing or ICONS[name]
	assert(segments, `Unknown HUD icon {name}`)
	local root = Instance.new("Frame")
	root.Name = name .. "Icon"
	root.BackgroundTransparency = 1
	root.Position = position
	root.Size = UDim2.fromOffset(pixels, pixels)
	root.Parent = parent
	for _, points in segments do
		local x, y = points[3] - points[1], points[4] - points[2]
		local line = Instance.new("Frame")
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.Position = UDim2.fromScale((points[1] + points[3]) / 2, (points[2] + points[4]) / 2)
		line.Size = UDim2.fromOffset(
			math.sqrt(x * x + y * y) * pixels,
			pixels * (strokeFraction or graphics.IconStrokeFraction)
		)
		line.Rotation = math.deg(math.atan2(y, x))
		line.BackgroundColor3 = color
		line.BorderSizePixel = 0
		local shadow = Instance.new("UIStroke")
		shadow.Color = Color3.new(0, 0, 0)
		shadow.Thickness = graphics.StrokePixels
		shadow.Transparency = ui.FloatingHud.LineShadowTransparency
		shadow.Parent = line
		line.Parent = root
	end
	return root
end

-- A continuous clockwise stroke over a dim circular track. Chords overlap at their joins;
-- only the leading chord changes length between whole segments, so progress does not jump by ticks.
function HudKit.ring(parent: Instance, name: string, pixels: number): (number, Color3) -> ()
	local config = ui.FloatingHud
	local radius = pixels / 2 - config.RingInsetPixels
	local root = Instance.new("Frame")
	root.Name = name .. "Loop"
	root.BackgroundTransparency = 1
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromOffset(pixels, pixels)
	root.Parent = parent
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.BackgroundTransparency = 1
	track.AnchorPoint = Vector2.new(0.5, 0.5)
	track.Position = UDim2.fromScale(0.5, 0.5)
	track.Size = UDim2.fromOffset(radius * 2, radius * 2)
	track.Parent = root
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = track
	local border = Instance.new("UIStroke")
	border.Thickness = config.RingStrokePixels
	border.Transparency = config.InactiveTransparency
	border.Parent = track
	local segments: { Frame } = {}
	local lastFraction = -1
	local lastColor: Color3? = nil
	local function point(turn: number): Vector2
		local angle = turn * math.pi * 2
		return Vector2.new(pixels / 2 + math.sin(angle) * radius, pixels / 2 - math.cos(angle) * radius)
	end
	local function shape(segment: Frame, index: number, amount: number)
		local a = point((index - 1) / config.RingSegments)
		local b = point((index - 1 + amount) / config.RingSegments)
		local delta = b - a
		segment.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
		segment.Size = UDim2.fromOffset(delta.Magnitude + config.RingOverlapPixels, config.RingStrokePixels)
		segment.Rotation = math.deg(math.atan2(delta.Y, delta.X))
	end
	for index = 1, config.RingSegments do
		local segment = Instance.new("Frame")
		segment.Name = `{name}{index}`
		segment.AnchorPoint = Vector2.new(0.5, 0.5)
		segment.BorderSizePixel = 0
		segment.Visible = false
		segment.Parent = root
		shape(segment, index, 1)
		table.insert(segments, segment)
	end
	return function(fraction: number, color: Color3)
		fraction = math.clamp(fraction, 0, 1)
		if fraction == lastFraction and color == lastColor then
			return
		end
		local previous = lastFraction * #segments
		local progress = fraction * #segments
		border.Color = color
		for index, segment in segments do
			local amount = math.clamp(progress - index + 1, 0, 1)
			local oldAmount = math.clamp(previous - index + 1, 0, 1)
			if amount ~= oldAmount or lastFraction < 0 then
				segment.Visible = amount > 0
				if amount > 0 then
					shape(segment, index, amount)
				end
			end
			if color ~= lastColor then
				segment.BackgroundColor3 = color
			end
		end
		lastFraction, lastColor = fraction, color
	end
end

function HudKit.screen(name: string): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return gui
end

function HudKit.text(parent: Instance, name: string, position: UDim2, anchor: Vector2, size: UDim2): TextLabel
	local text = Instance.new("TextLabel")
	text.Name = name
	text.BackgroundTransparency = 1
	text.Font = graphics.Font
	text.TextSize = ui.TextSize
	text.TextColor3 = graphics.TextColor
	text.TextStrokeColor3 = Color3.new(0, 0, 0)
	text.TextStrokeTransparency = ui.FloatingHud.TextShadowTransparency
	text.AnchorPoint = anchor
	text.Position = position
	text.Size = size
	text.Parent = parent
	return text
end

-- Where each side's glow sits, and which way its gradient runs so it is strongest at the screen edge.
local SIDES = {
	Top = { position = UDim2.fromScale(0, 0), size = UDim2.new(1, 0, 0, ui.GlowPixels), rotation = 90 },
	Bottom = { position = UDim2.new(0, 0, 1, -ui.GlowPixels), size = UDim2.new(1, 0, 0, ui.GlowPixels), rotation = 270 },
	Left = { position = UDim2.fromScale(0, 0), size = UDim2.new(0, ui.GlowPixels, 1, 0), rotation = 0 },
	Right = { position = UDim2.new(1, -ui.GlowPixels, 0, 0), size = UDim2.new(0, ui.GlowPixels, 1, 0), rotation = 180 },
}

function HudKit.edgeGlow(parent: Instance, color: Color3): EdgeGlow
	local frames: { [string]: Frame } = {}
	for name, side in SIDES do
		local frame = Instance.new("Frame")
		frame.Name = `Glow{name}`
		frame.Position = side.position
		frame.Size = side.size
		frame.BackgroundColor3 = color
		frame.BackgroundTransparency = 1
		frame.BorderSizePixel = 0
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = side.rotation
		gradient.Transparency = NumberSequence.new(0, 1)
		gradient.Parent = frame
		frame.Parent = parent
		frames[name] = frame
	end
	return {
		setSide = function(side: string, transparency: number)
			frames[side].BackgroundTransparency = transparency
		end,
		setAll = function(transparency: number)
			for _, frame in frames do
				frame.BackgroundTransparency = transparency
			end
		end,
	}
end

return HudKit
