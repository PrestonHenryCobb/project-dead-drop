--!strict
-- What GadgetService needs from a gadget (src/server/Gadgets). deploy is the fire button: it returns whether the gadget was
-- used (a charge is spent only then) and, when refused, a short reason to show the player. rules are the GameConfig.Agents
-- numbers of the user's agent. aim is the direction of the user's crosshair (a unit vector the client sent, or nil), for a
-- gadget that works on what is aimed at. alternate, if given, is the aim button (recalling a deployable).

export type Gadget = {
	deploy: (player: Player, rules: { [string]: any }, aim: Vector3?) -> (boolean, string?),
	alternate: ((player: Player) -> ())?,
	start: (() -> ())?, -- called once at boot, for a deployable's loop
	-- A deployable's answer to the Jammer: it is held down for `seconds` if it is within `radius` of `position` and belongs to
	-- someone who is not the jammer's teammate.
	jamAt: ((position: Vector3, radius: number, jammer: Player, seconds: number) -> ())?,
}

return {}
