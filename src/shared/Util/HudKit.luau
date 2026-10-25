--!strict
-- Small helpers for building the HUD from code (STYLE_QUESTIONS D2: minimal, bold pixel-style font). Client only.
--
--   HudKit.screen(name) -> ScreenGui                    a gui that survives respawns, under PlayerGui
--   HudKit.text(parent, name, position, anchor, size) -> TextLabel
--   HudKit.edgeGlow(parent, color) -> EdgeGlow          soft colored glow along the screen edges

local Players = game:GetService("Players")

local GameConfig = require(script.Parent.Parent.GameConfig)
local HudTheme = require(script.Parent.HudTheme)

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

function HudKit.panel(parent: Instance, name: string, position: UDim2, anchor: Vector2, size: UDim2): Frame
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
	shadow.BackgroundTransparency = graphics.ShadowTransparency
	shadow.Parent = root
	local back = Instance.new("Frame")
	back.Name = "Backdrop"
	back.Size = UDim2.fromScale(1, 1)
	back.BorderSizePixel = 0
	back.BackgroundColor3 = graphics.PanelColor
	back.BackgroundTransparency = graphics.PanelTransparency
	back.Parent = root
	for _, frame in { shadow, back } do
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, graphics.CornerPixels)
		corner.Parent = frame
	end
	local border = Instance.new("UIStroke")
	border.Color = graphics.BorderColor
	border.Transparency = graphics.BorderTransparency
	border.Thickness = graphics.StrokePixels
	border.Parent = back
	local accent = Instance.new("Frame")
	accent.Name = "MapAccent"
	accent.BorderSizePixel = 0
	accent.BackgroundColor3 = graphics.AccentColor
	accent.Position = UDim2.fromOffset(graphics.PaddingPixels, 0)
	accent.Size = UDim2.new(graphics.AccentWidthFraction, 0, 0, graphics.AccentThicknessPixels)
	accent.Parent = back
	return back
end

function HudKit.icon(parent: Instance, name: string, position: UDim2, pixels: number, color: Color3): Frame
	local segments = ICONS[name]
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
		line.Size = UDim2.fromOffset(math.sqrt(x * x + y * y) * pixels, pixels * graphics.IconStrokeFraction)
		line.Rotation = math.deg(math.atan2(y, x))
		line.BackgroundColor3 = color
		line.BorderSizePixel = 0
		line.Parent = root
	end
	return root
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
	text.TextColor3 = if parent.Name == "Backdrop" then graphics.TextColor else ui.TextColor
	text.TextStrokeTransparency = if parent.Name == "Backdrop" then 1 else 0.5
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
