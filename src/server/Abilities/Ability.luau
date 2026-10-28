--!strict
-- What AbilityService needs from an agent's ability. activate returns whether it was used (the cooldown starts only then)
-- and, when refused, a short reason to show the player.

export type Ability = {
	activate: (player: Player) -> (boolean, string?),
}

return {}
