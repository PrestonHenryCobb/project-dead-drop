--!strict
-- Ticket 19-hud-motion: use Roblox's own Reduce Motion preference, including live changes.
-- Client presentation only; never changes weapon recoil, spread, action durations or authoritative numbers.
local GuiService = game:GetService("GuiService")
local UiAccessibility = {}

-- Older Studio API snapshots may not expose this property. Probe once, not once per rendered frame.
local supported = pcall(function()
	return GuiService.ReducedMotionEnabled
end)

function UiAccessibility.reducedMotion(): boolean
	return supported and GuiService.ReducedMotionEnabled
end

return table.freeze(UiAccessibility)
