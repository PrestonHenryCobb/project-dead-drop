--!strict
-- Ticket 19-coverbreak-feedback: prebuilt UI-only broken corners, with no central fill or world/character effects.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = script.Parent:FindFirstChild("SharedOverride") or ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)
local HudScale = require(Shared.Util.HudScale)
local config = GameConfig.UI.CoverBreak
local CoverBreakFx = {}
CoverBreakFx.__index = CoverBreakFx

export type Effect = typeof(setmetatable({} :: { root: Frame, bars: { Frame }, startedAt: number }, CoverBreakFx))

function CoverBreakFx.transparency(age: number, reducedMotion: boolean): number
	if reducedMotion or age < 0 or age >= config.Seconds then
		return 1
	end
	return config.StartTransparency + (1 - config.StartTransparency) * age / config.Seconds
end

function CoverBreakFx.new(parent: Instance): Effect
	local root = Instance.new("Frame")
	root.Name = "CoverBreakGeometry"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Visible = false
	root.Parent = parent
	local bars: { Frame } = {}
	-- Drawing coordinates: two short diagonal fragments per screen corner, leaving the middle unobstructed.
	for _, x in { -1, 1 } do
		for _, y in { -1, 1 } do
			local corner = Instance.new("Frame")
			corner.BackgroundTransparency = 1
			corner.AnchorPoint = Vector2.new(0.5, 0.5)
			corner.Size = UDim2.fromOffset(config.ArmPixels, config.ArmPixels)
			corner.Position = UDim2.fromScale(
				if x < 0 then config.EdgeInsetFraction else 1 - config.EdgeInsetFraction,
				if y < 0 then config.EdgeInsetFraction else 1 - config.EdgeInsetFraction
			)
			corner.Parent = root
			HudScale.bind(corner)
			for _, arm in { -1, 1 } do
				local bar = Instance.new("Frame")
				bar.BorderSizePixel = 0
				bar.BackgroundColor3 = GameConfig.UI.CoverColors.Exposed
				bar.BackgroundTransparency = 1
				bar.AnchorPoint = Vector2.new(0.5, 0.5)
				bar.Size = UDim2.fromOffset(config.ArmPixels, config.StrokePixels)
				bar.Position = UDim2.fromScale(0.5 + arm * x / 2, 0.5)
				bar.Rotation = arm * x * y * 35
				bar.Parent = corner
				table.insert(bars, bar)
			end
		end
	end
	return setmetatable({ root = root, bars = bars, startedAt = -math.huge }, CoverBreakFx)
end

function CoverBreakFx.trigger(self: Effect, now: number)
	self.startedAt = now
end

function CoverBreakFx.update(self: Effect, now: number, reducedMotion: boolean)
	local alpha = CoverBreakFx.transparency(now - self.startedAt, reducedMotion)
	if alpha >= 1 and not self.root.Visible then
		return
	end
	self.root.Visible = alpha < 1
	for _, bar in self.bars do
		bar.BackgroundTransparency = alpha
	end
end

function CoverBreakFx.reset(self: Effect)
	self.startedAt = -math.huge
	self.root.Visible = false
end

function CoverBreakFx.destroy(self: Effect)
	self.root:Destroy()
end

return CoverBreakFx
