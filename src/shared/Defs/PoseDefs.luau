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
	-- Crouching (spec 6.8): knees bent, hips lowered, leaning forward, arms loose. Players only; NPCs never crouch.
	Crouch = {
		Loop = true,
		Priority = "Action",
		Keyframes = (function()
			local function lowered(time: number, lean: number): Types.PoseKeyframe
				return frame(
					time,
					body({ lean, 0, 0 }, { -lean * 0.6, 0, 0 }),
					{ LowerTorso = { 0, 0, 0, 0, -1.1, 0 } },
					leg("Right", { 65, 0, 3 }, { -90, 0, 0 }),
					leg("Left", { 65, 0, 3 }, { -90, 0, 0 }),
					arm("Right", { 20, 0, 8 }, { 25, 0, 0 }),
					arm("Left", { 20, 0, 8 }, { 25, 0, 0 })
				)
			end
			return { lowered(0, -22), lowered(0.5, -24), lowered(1, -22) }
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

-- Going down, lying, crawling and dying (R4-body-animation, owner decisions 2026-10-25). Original procedural poses,
-- shared by NPCs and players (Util/Knockdown picks which). The server lays the root flat (face down when prone, face up
-- when supine), so every pose here is relative to a lying root and moves the whole body through LowerTorso (the Root
-- joint): a knockdown starts by turning the body back upright and raising it, then lets it fall to the lying pose.
-- Every down pose names every joint, so nothing from the walk or idle animations shows through.
do
	local knock = GameConfig.Downed.Knockdown
	local rise = knock.RiseStuds -- a standing root's height above a lying one
	local fallTime = knock.Seconds

	-- The whole body, turned and raised from the lying root. Up for a prone root is its +Z; for a supine root, its -Z.
	local function whole(rx: number, ry: number, up: number, supine: boolean): Joints
		return { LowerTorso = { rx, ry, 0, 0, 0, if supine then -up else up } }
	end
	-- Torso, head, then each limb as { upper joint, lower joint }.
	local function limbs(
		torso: JointPose,
		head: JointPose,
		rightArm: { JointPose },
		leftArm: { JointPose },
		rightLeg: { JointPose },
		leftLeg: { JointPose }
	): Joints
		local joints: Joints = body(torso, head)
		for _, part in
			{
				arm("Right", rightArm[1], rightArm[2]),
				arm("Left", leftArm[1], leftArm[2]),
				leg("Right", rightLeg[1], rightLeg[2]),
				leg("Left", leftLeg[1], leftLeg[2]),
			}
		do
			for name, pose in part do
				joints[name] = pose
			end
		end
		return joints
	end
	local function still(): { JointPose }
		return { STRAIGHT, STRAIGHT }
	end

	local standing = limbs(STRAIGHT, STRAIGHT, still(), still(), still(), still())
	-- On the front, up on the forearms, head raised to look ahead.
	local proneRest = limbs(
		{ 10, 0, 0 },
		{ 35, 0, 0 },
		{ { 150, 0, 18 }, { 75, 0, 0 } },
		{ { 150, 0, 18 }, { 75, 0, 0 } },
		{ { 0, 0, 4 }, { -6, 0, 0 } },
		{ { 0, 0, 4 }, { -6, 0, 0 } }
	)
	-- One forearm reaching, the other pulling, the opposite knee drawn up to push.
	local proneReachRight = limbs(
		{ 10, 6, 0 },
		{ 35, -6, 0 },
		{ { 170, 0, 10 }, { 25, 0, 0 } },
		{ { 120, 0, 25 }, { 100, 0, 0 } },
		{ { 0, 0, 4 }, { -6, 0, 0 } },
		{ { 20, 0, 35 }, { -80, 0, 0 } }
	)
	local proneReachLeft = limbs(
		{ 10, -6, 0 },
		{ 35, 6, 0 },
		{ { 120, 0, 25 }, { 100, 0, 0 } },
		{ { 170, 0, 10 }, { 25, 0, 0 } },
		{ { 20, 0, 35 }, { -80, 0, 0 } },
		{ { 0, 0, 4 }, { -6, 0, 0 } }
	)
	-- On the back, propped on the elbows, knees up, looking toward the feet.
	local supineRest = limbs(
		{ -18, 0, 0 },
		{ -25, 0, 0 },
		{ { -35, 0, 22 }, { 70, 0, 0 } },
		{ { -35, 0, 22 }, { 70, 0, 0 } },
		{ { 45, 0, 6 }, { -90, 0, 0 } },
		{ { 45, 0, 6 }, { -90, 0, 0 } }
	)
	-- Pushing backward with one heel, then the other.
	local supinePushRight = limbs(
		{ -20, 4, 0 },
		{ -25, 0, 0 },
		{ { -45, 0, 22 }, { 80, 0, 0 } },
		{ { -25, 0, 22 }, { 60, 0, 0 } },
		{ { 65, 0, 6 }, { -115, 0, 0 } },
		{ { 20, 0, 6 }, { -40, 0, 0 } }
	)
	local supinePushLeft = limbs(
		{ -20, -4, 0 },
		{ -25, 0, 0 },
		{ { -25, 0, 22 }, { 60, 0, 0 } },
		{ { -45, 0, 22 }, { 80, 0, 0 } },
		{ { 20, 0, 6 }, { -40, 0, 0 } },
		{ { 65, 0, 6 }, { -115, 0, 0 } }
	)
	-- Still: limbs slack, head turned to one side.
	local proneDead = limbs(
		STRAIGHT,
		{ 0, 30, 0 },
		{ { 100, 0, 45 }, { 10, 0, 0 } },
		{ { 15, 0, 10 }, { 5, 0, 0 } },
		{ { 0, 0, 8 }, STRAIGHT },
		{ { 0, 0, 10 }, { -10, 0, 0 } }
	)
	local supineDead = limbs(
		STRAIGHT,
		{ 0, 30, 0 },
		{ { -10, 0, 40 }, { 5, 0, 0 } },
		{ { -10, 0, 30 }, { 10, 0, 0 } },
		{ { 5, 0, 10 }, { -5, 0, 0 } },
		{ { 15, 0, 6 }, { -25, 0, 0 } }
	)
	-- Arms thrown forward to break a forward fall; flung out going backward or sideways.
	local bracing = limbs(
		{ -10, 0, 0 },
		{ 15, 0, 0 },
		{ { 80, 0, 10 }, { 20, 0, 0 } },
		{ { 80, 0, 10 }, { 20, 0, 0 } },
		{ { 10, 0, 4 }, { -20, 0, 0 } },
		{ { 10, 0, 4 }, { -20, 0, 0 } }
	)
	local flailing = limbs(
		{ 10, 0, 0 },
		{ -15, 0, 0 },
		{ { 40, 0, 60 }, { 30, 0, 0 } },
		{ { 40, 0, 60 }, { 30, 0, 0 } },
		{ { 25, 0, 6 }, { -30, 0, 0 } },
		{ { 10, 0, 6 }, { -10, 0, 0 } }
	)

	local flat, flatSupine = whole(0, 0, 0, false), whole(0, 0, 0, true)
	local function once(...: Types.PoseKeyframe): PoseDef
		return { Loop = false, Priority = "Action", Keyframes = { ... } }
	end
	local function looped(...: Types.PoseKeyframe): PoseDef
		return { Loop = true, Priority = "Action", Keyframes = { ... } }
	end
	local cycle = knock.CrawlCycleSeconds

	local downPoses: { [string]: PoseDef } = {
		KnockdownForward = once(
			frame(0, standing, whole(90, 0, rise, false)),
			frame(fallTime * 0.4, bracing, whole(50, 0, rise * 0.6, false)),
			frame(fallTime, proneRest, flat)
		),
		KnockdownBackward = once(
			frame(0, standing, whole(-90, 0, rise, true)),
			frame(fallTime * 0.4, flailing, whole(-55, 0, rise * 0.6, true)),
			frame(fallTime, supineRest, flatSupine)
		),
		-- Down onto one side, then a roll onto the front.
		KnockdownLeft = once(
			frame(0, standing, whole(90, 0, rise, false)),
			frame(fallTime * 0.45, flailing, whole(0, 80, knock.SideLiftStuds, false)),
			frame(fallTime, proneRest, flat)
		),
		KnockdownRight = once(
			frame(0, standing, whole(90, 0, rise, false)),
			frame(fallTime * 0.45, flailing, whole(0, -80, knock.SideLiftStuds, false)),
			frame(fallTime, proneRest, flat)
		),
		LieProne = looped(
			frame(0, proneRest, flat),
			frame(1.5, proneRest, whole(2, 0, 0, false)),
			frame(3, proneRest, flat)
		),
		LieSupine = looped(
			frame(0, supineRest, flatSupine),
			frame(1.5, supineRest, whole(-2, 0, 0, true)),
			frame(3, supineRest, flatSupine)
		),
		CrawlProne = looped(
			frame(0, proneReachRight, flat),
			frame(cycle / 2, proneReachLeft, flat),
			frame(cycle, proneReachRight, flat)
		),
		CrawlSupine = looped(
			frame(0, supinePushRight, flatSupine),
			frame(cycle / 2, supinePushLeft, flatSupine),
			frame(cycle, supinePushRight, flatSupine)
		),
		-- A brief settle into stillness, then held (not a ragdoll).
		DeadProne = looped(
			frame(0, proneRest, flat),
			frame(knock.CollapseSeconds, proneDead, flat),
			frame(knock.DeadHoldSeconds, proneDead, flat)
		),
		DeadSupine = looped(
			frame(0, supineRest, flatSupine),
			frame(knock.CollapseSeconds, supineDead, flatSupine),
			frame(knock.DeadHoldSeconds, supineDead, flatSupine)
		),
	}
	for name, def in downPoses do
		PoseDefs[name] = def
	end
end

return PoseDefs
