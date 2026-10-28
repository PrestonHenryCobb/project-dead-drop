--!strict
-- Guise's ability, Quick Change (spec 15.1): switch to a stored disguise at once, even in combat lockout (DisguiseService).

local DisguiseService = require(script.Parent.Parent.Services.DisguiseService)
local Ability = require(script.Parent.Ability)

local Guise: Ability.Ability = {
	activate = function(player: Player): (boolean, string?)
		return DisguiseService.quickChange(player)
	end,
}

return Guise
