--!strict
-- Disguise Kit (docs/GADGETS_DRAFT.md, Evasion): at once, a Guest disguise without scanning anyone. Refused while Security
-- tracks the user, in combat lockout, or carrying the Package (DisguiseService.kitChange). Discreet: a Security NPC or camera
-- that sees it breaks Cover.

local CoverService = require(script.Parent.Parent.Services.CoverService)
local DisguiseService = require(script.Parent.Parent.Services.DisguiseService)
local Gadget = require(script.Parent.Gadget)

local DisguiseKit: Gadget.Gadget = {
	deploy = function(player: Player): (boolean, string?)
		local changed, reason = DisguiseService.kitChange(player)
		if changed then
			CoverService.useDiscreetly(player, "DisguiseKit")
		end
		return changed, reason
	end,
}

return DisguiseKit
