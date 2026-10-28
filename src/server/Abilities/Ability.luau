--!strict
-- What AbilityService needs from an agent's ability. activate returns whether it was used (the cooldown starts only then)
-- and, when refused, a short reason to show the player. start, if given, is called once at boot with a way to ask which
-- agent a player is, for an agent's passive that needs a loop of its own.

export type Ability = {
	activate: (player: Player) -> (boolean, string?),
	start: ((agentOf: (Player) -> string?) -> ())?,
}

return {}
