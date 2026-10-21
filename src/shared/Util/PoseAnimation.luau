--!strict
-- Turns the pose data in Defs/PoseDefs into animations that can be played on an R15 rig, in the same way for NPCs
-- and for players. The animations are registered with the local client, so call this on each client.
--
--   local animations = PoseAnimation.registerAll()   -- { [name]: Animation }
--   animator:LoadAnimation(animations.Talk):Play()

local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")

local PoseDefs = require(script.Parent.Parent.Defs.PoseDefs)
local Types = require(script.Parent.Parent.Types)

type PoseDef = Types.PoseDef
type JointPose = Types.JointPose

local PoseAnimation = {}

-- The rig's joint hierarchy: each name is the part a joint moves, listed under the part it hangs from.
local TREE: { [string]: { string } } = {
	HumanoidRootPart = { "LowerTorso" },
	LowerTorso = { "UpperTorso", "LeftUpperLeg", "RightUpperLeg" },
	UpperTorso = { "Head", "LeftUpperArm", "RightUpperArm" },
	LeftUpperArm = { "LeftLowerArm" },
	LeftLowerArm = { "LeftHand" },
	RightUpperArm = { "RightLowerArm" },
	RightLowerArm = { "RightHand" },
	LeftUpperLeg = { "LeftLowerLeg" },
	LeftLowerLeg = { "LeftFoot" },
	RightUpperLeg = { "RightLowerLeg" },
	RightLowerLeg = { "RightFoot" },
}

local KNOWN_JOINTS: { [string]: boolean } =
	{ Head = true, LeftHand = true, RightHand = true, LeftFoot = true, RightFoot = true }
for parent, children in TREE do
	KNOWN_JOINTS[parent] = true
	for _, child in children do
		KNOWN_JOINTS[child] = true
	end
end

local function toCFrame(pose: JointPose): CFrame
	local rotation = CFrame.Angles(math.rad(pose[1] or 0), math.rad(pose[2] or 0), math.rad(pose[3] or 0))
	return CFrame.new(pose[4] or 0, pose[5] or 0, pose[6] or 0) * rotation
end

-- A joint the animation uses is posed at full weight in every keyframe; every other joint has weight zero, so the
-- base walk and idle animations keep control of it.
local function buildPose(name: string, joints: { [string]: JointPose }, used: { [string]: boolean }): Pose
	local pose = Instance.new("Pose")
	pose.Name = name
	if used[name] then
		pose.CFrame = toCFrame(joints[name] or { 0, 0, 0 })
		pose.Weight = 1
	else
		pose.Weight = 0
	end
	pose.EasingStyle = Enum.PoseEasingStyle.Cubic
	pose.EasingDirection = Enum.PoseEasingDirection.InOut
	for _, child in TREE[name] or {} do
		buildPose(child, joints, used).Parent = pose
	end
	return pose
end

function PoseAnimation.build(name: string, def: PoseDef): KeyframeSequence
	local used: { [string]: boolean } = {}
	for _, keyframe in def.Keyframes do
		for joint in keyframe.Joints do
			assert(KNOWN_JOINTS[joint], `{name}: unknown joint {joint}`)
			used[joint] = true
		end
	end

	local sequence = Instance.new("KeyframeSequence")
	sequence.Name = name
	sequence.Loop = def.Loop
	sequence.Priority = Enum.AnimationPriority[def.Priority]
	for _, keyframeDef in def.Keyframes do
		local keyframe = Instance.new("Keyframe")
		keyframe.Time = keyframeDef.Time
		buildPose("HumanoidRootPart", keyframeDef.Joints, used).Parent = keyframe
		keyframe.Parent = sequence
	end
	return sequence
end

function PoseAnimation.registerAll(): { [string]: Animation }
	local animations: { [string]: Animation } = {}
	for name, def in PoseDefs do
		local animation = Instance.new("Animation")
		animation.Name = name
		animation.AnimationId = KeyframeSequenceProvider:RegisterKeyframeSequence(PoseAnimation.build(name, def))
		animations[name] = animation
	end
	return animations
end

return PoseAnimation
