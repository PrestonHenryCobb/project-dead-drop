--!strict
-- Talent PlateSlam (ticket kits-24): one armour plate at once, if there is room for it.

local MatchService = require(script.Parent.Parent.Services.MatchService)
local CombatService = require(script.Parent.Parent.Services.CombatService)
local Ability = require(script.Parent.Ability)
local Body = require(script.Parent.Body)

local PlateSlam: Ability.Ability = {
	activate = function(player: Player): (boolean, string?)
		if not Body.of(player) or not MatchService.isInMatch() then
			return false, nil
		end
		if not CombatService.addPlate(player) then
			return false, "You already wear every plate you can"
		end
		return true, nil
	end,
}

return PlateSlam
