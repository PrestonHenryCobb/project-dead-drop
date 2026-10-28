--!strict
-- Lattice's ability, Sparrow Drone (spec 15.3): fly a drone (DroneService).

local DroneService = require(script.Parent.Parent.Services.DroneService)
local Ability = require(script.Parent.Ability)

local Lattice: Ability.Ability = {
	activate = function(player: Player): (boolean, string?)
		return DroneService.begin(player)
	end,
}

return Lattice
