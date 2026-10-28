--!strict
-- What GadgetService needs from a gadget (src/server/Gadgets). deploy is the fire button: it returns whether the gadget was
-- used (a charge is spent only then) and, when refused, a short reason to show the player. rules are the GameConfig.Agents
-- numbers of the user's agent. alternate, if given, is the aim button (recalling a deployable).

export type Gadget = {
	deploy: (player: Player, rules: { [string]: any }) -> (boolean, string?),
	alternate: ((player: Player) -> ())?,
	start: (() -> ())?, -- called once at boot, for a deployable's loop
}

return {}
