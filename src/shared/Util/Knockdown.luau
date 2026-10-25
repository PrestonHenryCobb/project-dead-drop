--!strict
-- How a body goes down (R4-body-animation, owner decisions 2026-10-25). One set of rules for NPCs and players, so a
-- downed player and a downed NPC fall, lie, crawl and die the same way.
--
--   * The fall comes from where the final damaging hit came from, relative to the way the body faced: a hit from
--     behind (or no attacker, such as a fall) drops it forward onto its front; a hit from the front drops it backward
--     onto its back; a hit from the left or right drops it to the other side, then it rolls onto its front.
--   * Prone bodies crawl head first on their forearms; supine bodies push backward with their legs, head first too.
--   * The server classifies (it alone knows where hits come from); clients only receive the animation names.
--
--   Knockdown.classify(look, bodyPosition, from?) -> Fall       "Forward" | "Backward" | "Left" | "Right"
--   Knockdown.posture(fall) -> Posture                          "Prone" | "Supine"
--   Knockdown.lyingYaw(fall, facingYaw) -> number               the way the head points once down
--   Knockdown.lyingCFrame(ground, yaw, posture) -> CFrame       the root of a body lying there
--   Knockdown.animation(stage, fall, posture, moving?) -> string    the pose to play (Defs/PoseDefs)

local GameConfig = require(script.Parent.Parent.GameConfig)

export type Fall = "Forward" | "Backward" | "Left" | "Right"
export type Posture = "Prone" | "Supine"
export type Stage = "Knockdown" | "Down" | "Dead"

local Knockdown = {}

local config = GameConfig.Downed.Knockdown

function Knockdown.classify(look: Vector3, bodyPosition: Vector3, from: Vector3?): Fall
	if not from then
		return "Forward"
	end
	local toHit = Vector3.new(from.X - bodyPosition.X, 0, from.Z - bodyPosition.Z)
	local facing = Vector3.new(look.X, 0, look.Z)
	if toHit.Magnitude < config.MinSourceStuds or facing.Magnitude < 1e-3 then
		return "Forward" -- no direction to speak of (a fall, or a hit from inside the body): the standard collapse
	end
	toHit, facing = toHit.Unit, facing.Unit
	local front = toHit:Dot(facing)
	local edge = math.cos(math.rad(config.FrontBackDegrees / 2))
	if front >= edge then
		return "Backward"
	elseif front <= -edge then
		return "Forward"
	end
	local right = Vector3.new(-facing.Z, 0, facing.X)
	return if toHit:Dot(right) > 0 then "Left" else "Right" -- pushed away from the side the hit came from
end

function Knockdown.posture(fall: Fall): Posture
	return if fall == "Backward" then "Supine" else "Prone"
end

-- A prone body's head points the way it faced; a supine body fell backward, so its head points behind it.
function Knockdown.lyingYaw(fall: Fall, facingYaw: number): number
	return if fall == "Backward" then facingYaw + math.pi else facingYaw
end

-- The root of a body lying with its head toward `yaw`: face down when prone, face up when supine.
function Knockdown.lyingCFrame(ground: Vector3, yaw: number, posture: Posture): CFrame
	local lift = Vector3.new(0, GameConfig.NPC.Death.RootLiftStuds, 0)
	if posture == "Supine" then
		return CFrame.new(ground + lift) * CFrame.Angles(0, yaw + math.pi, 0) * CFrame.Angles(math.pi / 2, 0, 0)
	end
	return CFrame.new(ground + lift) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(-math.pi / 2, 0, 0)
end

-- The pose for a stage: the fall itself, then lying or crawling, then dead.
function Knockdown.animation(stage: Stage, fall: Fall, posture: Posture, moving: boolean?): string
	if stage == "Knockdown" then
		return "Knockdown" .. fall
	elseif stage == "Dead" then
		return "Dead" .. posture
	end
	return (if moving then "Crawl" else "Lie") .. posture
end

return Knockdown
