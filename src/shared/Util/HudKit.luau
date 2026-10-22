--!strict
-- Small helpers for building the HUD from code (STYLE_QUESTIONS D2: minimal, bold pixel-style font). Client only.
--
--   HudKit.screen(name) -> ScreenGui                    a gui that survives respawns, under PlayerGui
--   HudKit.text(parent, name, position, anchor, size) -> TextLabel
--   HudKit.edgeGlow(parent, color) -> EdgeGlow          soft colored glow along the screen edges

local Players = game:GetService("Players")

local GameConfig = require(script.Parent.Parent.GameConfig)

local ui = GameConfig.UI

export type EdgeGlow = {
	setSide: (side: string, transparency: number) -> (), -- "Top", "Bottom", "Left" or "Right"
	setAll: (transparency: number) -> (),
}

local HudKit = {}

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
	text.Font = ui.Font
	text.TextSize = ui.TextSize
	text.TextColor3 = ui.TextColor
	text.TextStrokeTransparency = 0.5
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
