--!strict
-- Ticket 8.5d-dmr: exact optical magnification while retaining existing guns' FOV multipliers.
local WeaponAim = {}

function WeaponAim.fov(baseFov: number, legacyZoom: number, magnification: number?): number
	if magnification then
		return math.deg(2 * math.atan(math.tan(math.rad(baseFov) / 2) / magnification))
	end
	return baseFov * legacyZoom
end

return table.freeze(WeaponAim)
