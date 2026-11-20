--!strict
-- Ticket 19-hud-motion: use Roblox's own Reduce Motion preference, including live changes.
-- Client presentation only; never changes weapon recoil, spread, action durations or authoritative numbers.
local GuiService = game:GetService("GuiService")
local UiAccessibility = {}
local requestedReducedMotion = false

-- Older Studio API snapshots may not expose this property. Probe once, not once per rendered frame.
local supported = pcall(function()
	return GuiService.ReducedMotionEnabled
end)

function UiAccessibility.reducedMotion(): boolean
	return requestedReducedMotion or (supported and GuiService.ReducedMotionEnabled)
end

-- An extra local comfort preference can enable reduced motion; it never disables the Roblox preference.
function UiAccessibility.setReducedMotion(on: boolean)
	requestedReducedMotion = on
end

return table.freeze(UiAccessibility)
