--!strict
-- Animations built from code (spec 5.3, 6.7). The default Roblox animations cover walking and idling; everything an
-- NPC does at a node, and how it reacts, is posed here and turned into playable animations by Util/PoseAnimation.
-- The same set is what players get on the Blend wheel (Step 6).
--
-- Each animation lists keyframes. A keyframe gives joint poses in degrees: { rx, ry, rz } and optionally
-- { rx, ry, rz, tx, ty, tz } to also move the joint (used to lower the hips). Joints are named after the body part
-- they move. Joints an animation never mentions keep playing the base walk or idle animation underneath.
--
-- Directions, measured on the rig (it faces -Z; its right hand is +X):
--   arms:      +rx raises the arm forward, +rz raises it out to the side (the left side mirrors y and z)
--   elbows:    +rx bends the forearm up and forward
--   hips:      +rx lifts the leg forward          knees: -rx bends the shin back
--   waist:     +rx leans back, -rx leans forward  neck:  +rx looks up, +ry looks left

local GameConfig = require(script.Parent.Parent.GameConfig)
local Types = require(script.Parent.Parent.Types)

type PoseDef = Types.PoseDef
type JointPose = Types.JointPose
type Joints = { [string]: JointPose }

-- One arm: shoulder and elbow. The left arm mirrors the right, so outward and inward swap sides.
local function arm(side: "Right" | "Left", shoulder: JointPose, elbow: JointPose): Joints
	local sign = if side == "Right" then 1 else -1
	return {
		[side .. "UpperArm"] = { shoulder[1], shoulder[2] * sign, shoulder[3] * sign },
		[side .. "LowerArm"] = { elbow[1], elbow[2] * sign, elbow[3] * sign },
	}
end

-- One leg: hip and knee. Mirrors like the arms.
local function leg(side: "Right" | "Left", hip: JointPose, knee: JointPose): Joints
	local sign = if side == "Right" then 1 else -1
	return {
		[side .. "UpperLeg"] = { hip[1], hip[2] * sign, hip[3] * sign },
		[side .. "LowerLeg"] = { knee[1], knee[2] * sign, knee[3] * sign },
	}
end

local function frame(time: number, ...: Joints): Types.PoseKeyframe
	local merged: Joints = {}
	for _, part in { ... } do
		for name, pose in part do
			merged[name] = pose
		end
	end
	return { Time = time, Joints = merged }
end

local function body(torso: JointPose, head: JointPose): Joints
	return { UpperTorso = torso, Head = head }
end

local glance = GameConfig.NPC.GlanceDegrees
local STRAIGHT = { 0, 0, 0 }

local PoseDefs: { [string]: PoseDef } = {
	-- Studying a painting: one hand at the chin, head slowly scanning.
	LookAtArt = {
		Loop = true,
		Priority = "Action",
		Keyframes = {
			frame(
				0,
				body({ -3, 0, 0 }, { 5, 12, 0 }),
				arm("Right", { 35, 0, 0 }, { 115, 0, 0 }),
				arm("Left", { 20, 0, 0 }, { 70, 0, 0 })
			),
			frame(
				3,
				body({ -3, 0, 0 }, { 8, -12, 0 }),
				arm("Right", { 35, 0, 0 }, { 108, 0, 0 }),
				arm("Left", { 20, 0, 0 }, { 70, 0, 0 })
			),
			frame(
				6,
				body({ -3, 0, 0 }, { 5, 12, 0 }),
				arm("Right", { 35, 0, 0 }, { 115, 0, 0 }),
				arm("Left", { 20, 0, 0 }, { 70, 0, 0 })
			),
		},
	},
	-- Talking with gestures and nods.
	Talk = {
		Loop = true,
		Priority = "Action",
		Keyframes = {
			frame(
				0,
				body({ 0, 6, 0 }, { 2, 0, 0 }),
				arm("Right", { 40, 0, 12 }, { 70, 0, 0 }),
				arm("Left", { 15, 0, 4 }, { 45, 0, 0 })
			),
			frame(
				1,
				body({ 0, -4, 0 }, { -4, 8, 0 }),
				arm("Right", { 55, 0, 18 }, { 95, 0, 0 }),
				arm("Left", { 15, 0, 4 }, { 45, 0, 0 })
			),
			frame(
				2,
				body({ 0, 5, 0 }, { 3, -6, 0 }),
				arm("Right", { 35, 0, 8 }, { 60, 0, 0 }),
				arm("Left", { 30, 0, 10 }, { 70, 0, 0 })
			),
			frame(
				3,
				body({ 0, -5, 0 }, { -3, 6, 0 }),
				arm("Right", { 50, 0, 15 }, { 85, 0, 0 }),
				arm("Left", { 15, 0, 4 }, { 45, 0, 0 })
			),
			frame(
				4,
				body({ 0, 6, 0 }, { 2, 0, 0 }),
				arm("Right", { 40, 0, 12 }, { 70, 0, 0 }),
				arm("Left", { 15, 0, 4 }, { 45, 0, 0 })
			),
		},
	},
	-- On the phone: right hand at the ear.
	Phone = {
		Loop = true,
		Priority = "Action",
		Keyframes = {
			frame(
				0,
				body(STRAIGHT, { 3, -10, 0 }),
				arm("Right", { 25, 0, 28 }, { 135, 0, 0 }),
				arm("Left", { 15, 0, 5 }, { 75, 0, 0 })
			),
			frame(
				3,
				body(STRAIGHT, { 0, -4, 0 }),
				arm("Right", { 25, 0, 28 }, { 128, 0, 0 }),
				arm("Left", { 15, 0, 5 }, { 75, 0, 0 })
			),
			frame(
				6,
				body(STRAIGHT, { 3, -10, 0 }),
				arm("Right", { 25, 0, 28 }, { 135, 0, 0 }),
				arm("Left", { 15, 0, 5 }, { 75, 0, 0 })
			),
		},
	},
	-- Sipping a drink.
	Drink = {
		Loop = true,
		Priority = "Action",
		Keyframes = {
			frame(
				0,
				body(STRAIGHT, STRAIGHT),
				arm("Right", { 20, 0, 8 }, { 75, 0, 0 }),
				arm("Left", { 10, 0, 3 }, { 40, 0, 0 })
			),
			frame(
				2,
				body(STRAIGHT, { 18, 0, 0 }),
				arm("Right", { 50, 0, 10 }, { 125, 0, 0 }),
				arm("Left", { 10, 0, 3 }, { 40, 0, 0 })
			),
			frame(
				3.5,
				body(STRAIGHT, { 18, 0, 0 }),
				arm("Right", { 50, 0, 10 }, { 125, 0, 0 }),
				arm("Left", { 10, 0, 3 }, { 40, 0, 0 })
			),
			frame(
				5,
				body(STRAIGHT, STRAIGHT),
				arm("Right", { 20, 0, 8 }, { 75, 0, 0 }),
				arm("Left", { 10, 0, 3 }, { 40, 0, 0 })
			),
			frame(
				7,
				body(STRAIGHT, STRAIGHT),
				arm("Right", { 20, 0, 8 }, { 75, 0, 0 }),
				arm("Left", { 10, 0, 3 }, { 40, 0, 0 })
			),
		},
	},
	-- Seated, hands on thighs. The hips drop and the thighs go level; there is no chair in the graybox.
	Sit = {
		Loop = true,
		Priority = "Action",
		Keyframes = (function()
			local function seated(time: number): Types.PoseKeyframe
				return frame(
					time,
					body({ -4, 0, 0 }, STRAIGHT),
					{ LowerTorso = { 0, 0, 0, 0, -1.25, 0 } },
					leg("Right", { 90, 0, 3 }, { -90, 0, 0 }),
					leg("Left", { 90, 0, 3 }, { -90, 0, 0 }),
					arm("Right", { 25, 0, 5 }, { 55, 0, 0 }),
					arm("Left", { 25, 0, 5 }, { 55, 0, 0 })
				)
			end
			return { seated(0), seated(2) }
		end)(),
	},
	-- Leaning back with arms crossed.
	Lean = {
		Loop = true,
		Priority = "Action",
		Keyframes = (function()
			local function leaning(time: number, look: number): Types.PoseKeyframe
				return frame(
					time,
					body({ 10, 0, 0 }, { -3, look, 0 }),
					arm("Right", { 35, 0, -22 }, { 125, 0, 0 }),
					arm("Left", { 35, 0, -22 }, { 125, 0, 0 }),
					leg("Right", { 0, 0, -6 }, STRAIGHT)
				)
			end
			return { leaning(0, 5), leaning(3, -5), leaning(6, 5) }
		end)(),
	},
	-- At a keyboard: head down, both forearms tapping.
	Typing = {
		Loop = true,
		Priority = "Action",
		Keyframes = (function()
			local function typing(time: number, right: number, left: number): Types.PoseKeyframe
				return frame(
					time,
					body({ -8, 0, 0 }, { -14, 0, 0 }),
					arm("Right", { 35, 0, 5 }, { right, 0, 0 }),
					arm("Left", { 35, 0, 5 }, { left, 0, 0 })
				)
			end
			return {
				typing(0, 85, 80),
				typing(0.25, 95, 85),
				typing(0.5, 85, 95),
				typing(0.75, 80, 85),
				typing(1, 85, 80),
			}
		end)(),
	},
	-- A guard at a post: feet apart, hands clasped in front, slowly scanning the room.
	GuardStance = {
		Loop = true,
		Priority = "Action",
		Keyframes = (function()
			local function watching(time: number, look: number): Types.PoseKeyframe
				return frame(
					time,
					body({ 2, 0, 0 }, { 0, look, 0 }),
					arm("Right", { 12, 0, -6 }, { 75, 0, 0 }),
					arm("Left", { 12, 0, -6 }, { 75, 0, 0 }),
					leg("Right", { 0, 0, 5 }, STRAIGHT),
					leg("Left", { 0, 0, 5 }, STRAIGHT)
				)
			end
			return { watching(0, 0), watching(1.5, 14), watching(3, 0), watching(4.5, -14), watching(6, 0) }
		end)(),
	},
	-- Crouched with arms over the head, shuddering (spec 5.4).
	Cower = {
		Loop = true,
		Priority = "Action",
		Keyframes = (function()
			local function crouched(time: number, lean: number): Types.PoseKeyframe
				return frame(
					time,
					body({ lean, 0, 0 }, { lean + 10, 0, 0 }),
					{ LowerTorso = { 0, 0, 0, 0, -1.15, 0 } },
					leg("Right", { 70, 0, 4 }, { -95, 0, 0 }),
					leg("Left", { 70, 0, 4 }, { -95, 0, 0 }),
					arm("Right", { 140, 0, 15 }, { 110, 0, 0 }),
					arm("Left", { 140, 0, 15 }, { 110, 0, 0 })
				)
			end
			return { crouched(0, -35), crouched(0.3, -39), crouched(0.6, -35) }
		end)(),
	},
	-- A sharp intake of breath at a body (spec 5.4): head back, hands to the mouth. Plays once.
	Gasp = {
		Loop = false,
		Priority = "Action",
		Keyframes = (function()
			local function gasping(time: number, amount: number): Types.PoseKeyframe
				return frame(
					time,
					body({ 8 * amount, 0, 0 }, { 20 * amount, 0, 0 }),
					arm("Right", { 45 * amount, 0, 10 * amount }, { 135 * amount, 0, 0 }),
					arm("Left", { 45 * amount, 0, 10 * amount }, { 135 * amount, 0, 0 })
				)
			end
			return { gasping(0, 0), gasping(0.2, 1), gasping(1.3, 1), gasping(1.6, 0) }
		end)(),
	},
	-- A quick look to one side and back (spec 8.1). Head only, and above the other animations so it always shows.
	GlanceLeft = {
		Loop = false,
		Priority = "Action2",
		Keyframes = {
			{ Time = 0, Joints = { Head = STRAIGHT } },
			{ Time = 0.35, Joints = { Head = { 0, glance, 0 } } },
			{ Time = 1.1, Joints = { Head = { 0, glance, 0 } } },
			{ Time = 1.6, Joints = { Head = STRAIGHT } },
		},
	},
	GlanceRight = {
		Loop = false,
		Priority = "Action2",
		Keyframes = {
			{ Time = 0, Joints = { Head = STRAIGHT } },
			{ Time = 0.35, Joints = { Head = { 0, -glance, 0 } } },
			{ Time = 1.1, Joints = { Head = { 0, -glance, 0 } } },
			{ Time = 1.6, Joints = { Head = STRAIGHT } },
		},
	},
}

return PoseDefs
