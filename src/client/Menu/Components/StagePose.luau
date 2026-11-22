--!strict
-- Authored local menu poses, evaluated during finite transitions only. No animation assets or gameplay rig edits.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local config = require(ReplicatedStorage.Shared.GameConfig).Menu.Stage.Portrait
local StagePose = {}
export type Preset = {
	BodyYawDegrees: number,
	SupportWeapon: boolean,
	SupportCuff: boolean?,
	Joints: { [string]: Vector3 },
}
local screens = config.Screens :: { [string]: Preset }
export type State = {
	BodyYawDegrees: number,
	Joints: { [string]: Vector3 },
	SupportWeapon: number,
	SupportCuff: number,
}
type Link = { a: BasePart, b: BasePart, relative: CFrame }

local function rotation(degrees: Vector3): CFrame
	return CFrame.Angles(math.rad(degrees.X), math.rad(degrees.Y), math.rad(degrees.Z))
end

local function links(rig: Model, offsets: { [string]: Vector3 }): { Link }
	local result: { Link } = {}
	local attached: { [BasePart]: boolean } = {}
	-- AddAccessory's generated weld can lag a freshly built preview. Resolve from the authored attachment pair
	-- immediately, rather than leaving an anchored Handle behind and repeatedly lifting it with the feet.
	for _, accessory in rig:GetChildren() do
		if not accessory:IsA("Accessory") then
			continue
		end
		local handle = accessory:FindFirstChild("Handle")
		if not (handle and handle:IsA("BasePart")) then
			continue
		end
		for _, attachment in handle:GetChildren() do
			if not attachment:IsA("Attachment") then
				continue
			end
			for _, body in rig:GetChildren() do
				if not body:IsA("BasePart") then
					continue
				end
				local target = body:FindFirstChild(attachment.Name)
				if target and target:IsA("Attachment") then
					table.insert(
						result,
						{ a = body, b = handle, relative = target.CFrame * attachment.CFrame:Inverse() }
					)
					attached[handle] = true
					break
				end
			end
			if attached[handle] then
				break
			end
		end
	end
	for _, item in rig:GetDescendants() do
		if item:IsA("Motor6D") or item:IsA("Weld") then
			local a, b = item.Part0, item.Part1
			if a and b and a:IsDescendantOf(rig) and b:IsDescendantOf(rig) then
				item.Enabled = false
				if (attached[a] and b.Parent == rig) or (attached[b] and a.Parent == rig) then
					continue
				end
				local pose = if item:IsA("Motor6D") then offsets[b.Name] else nil
				table.insert(result, {
					a = a,
					b = b,
					relative = item.C0 * (if pose then rotation(pose) else CFrame.identity) * item.C1:Inverse(),
				})
			end
		elseif item:IsA("RigidConstraint") then
			local a, b = item.Attachment0, item.Attachment1
			if
				a
				and b
				and a.Parent
				and b.Parent
				and a.Parent:IsA("BasePart")
				and b.Parent:IsA("BasePart")
				and a:IsDescendantOf(rig)
				and b:IsDescendantOf(rig)
			then
				item.Enabled = false
				if
					(attached[a.Parent] and b.Parent.Parent == rig) or (attached[b.Parent] and a.Parent.Parent == rig)
				then
					continue
				end
				table.insert(result, { a = a.Parent, b = b.Parent, relative = a.CFrame * b.CFrame:Inverse() })
			end
		elseif item:IsA("WeldConstraint") then
			local a, b = item.Part0, item.Part1
			if a and b and a:IsDescendantOf(rig) and b:IsDescendantOf(rig) then
				item.Enabled = false
				if (attached[a] and b.Parent == rig) or (attached[b] and a.Parent == rig) then
					continue
				end
				table.insert(result, { a = a, b = b, relative = a.CFrame:ToObjectSpace(b.CFrame) })
			end
		end
	end
	return result
end

-- Accessory welds can point in either direction. Resolve outward from known body frames, with a finite pass bound.
local function resolve(edges: { Link }, known: { [BasePart]: CFrame })
	for _ = 1, #edges do
		local changed = false
		for _, edge in edges do
			local a, b = known[edge.a], known[edge.b]
			if a and not b then
				known[edge.b] = a * edge.relative
				changed = true
			elseif b and not a then
				known[edge.a] = b * edge.relative:Inverse()
				changed = true
			end
		end
		if not changed then
			break
		end
	end
	for part, frame in known do
		part.CFrame = frame
	end
	return known
end

function StagePose.describe(screen: string, family: string): State
	local preset = screens[screen] or screens.Play
	local offsets: { [string]: Vector3 } = table.clone(preset.Joints :: { [string]: Vector3 })
	if screen == "Hardware" and family == "OneHanded" then
		for _, limb in { "LeftUpperArm", "LeftLowerArm", "LeftHand" } do
			offsets[limb] = screens.Play.Joints[limb]
		end
	end
	if screen == "Agents" and family == "Dual" then
		for _, limb in { "RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperArm", "LeftLowerArm", "LeftHand" } do
			offsets[limb] = screens.Hardware.Joints[limb]
		end
	end
	return {
		BodyYawDegrees = preset.BodyYawDegrees,
		Joints = offsets,
		SupportWeapon = if preset.SupportWeapon and family == "TwoHanded" then 1 else 0,
		SupportCuff = if preset.SupportCuff and family ~= "Dual" then 1 else 0,
	}
end

function StagePose.blend(from: State, to: State, alpha: number): State
	local joints: { [string]: Vector3 } = {}
	for name, value in from.Joints do
		joints[name] = value:Lerp(to.Joints[name] or Vector3.zero, alpha)
	end
	for name, value in to.Joints do
		if not joints[name] then
			joints[name] = Vector3.zero:Lerp(value, alpha)
		end
	end
	return {
		BodyYawDegrees = from.BodyYawDegrees + (to.BodyYawDegrees - from.BodyYawDegrees) * alpha,
		Joints = joints,
		SupportWeapon = from.SupportWeapon + (to.SupportWeapon - from.SupportWeapon) * alpha,
		SupportCuff = from.SupportCuff + (to.SupportCuff - from.SupportCuff) * alpha,
	}
end

function StagePose.apply(rig: Model, state: State, feet: CFrame)
	local root = rig:FindFirstChild("HumanoidRootPart") :: BasePart
	local humanoid = rig:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.RequiresNeck = false
	humanoid.BreakJointsOnDeath = false
	for _, item in rig:GetDescendants() do
		if item:IsA("BasePart") then
			item.Anchored = true
		end
	end
	local edges = links(rig, state.Joints)
	root.CFrame = feet
		* CFrame.Angles(0, math.rad(state.BodyYawDegrees), 0)
		* CFrame.new(0, humanoid.HipHeight + root.Size.Y / 2, 0)
	local posed = resolve(edges, { [root] = root.CFrame })
	-- Ground the lowest sole after the weight shift, without changing the actual player rig or HipHeight.
	local lowest = math.huge
	for _, name in { "LeftFoot", "RightFoot" } do
		local foot = rig:FindFirstChild(name)
		if foot and foot:IsA("BasePart") then
			for _, x in { -1, 1 } do
				for _, y in { -1, 1 } do
					for _, z in { -1, 1 } do
						lowest = math.min(lowest, foot.CFrame:PointToWorldSpace(foot.Size * Vector3.new(x, y, z) / 2).Y)
					end
				end
			end
		end
	end
	if lowest < math.huge then
		local lift = Vector3.new(0, feet.Position.Y - lowest, 0)
		for item in posed do
			item.CFrame += lift
		end
	end
end

-- Fit the support arm to the selected weapon's actual grip, keeping body proportions and a natural elbow bend.
function StagePose.reachLeftHand(rig: Model, target: CFrame)
	local upper = rig:FindFirstChild("LeftUpperArm") :: BasePart
	local lower = rig:FindFirstChild("LeftLowerArm") :: BasePart
	local hand = rig:FindFirstChild("LeftHand") :: BasePart
	local torso = rig:FindFirstChild("UpperTorso") :: BasePart
	local shoulder = upper:FindFirstChild("LeftShoulderRigAttachment") :: Attachment
	local elbowTop = upper:FindFirstChild("LeftElbowRigAttachment") :: Attachment
	local elbowBottom = lower:FindFirstChild("LeftElbowRigAttachment") :: Attachment
	local wrist = lower:FindFirstChild("LeftWristRigAttachment") :: Attachment
	local handWrist = hand:FindFirstChild("LeftWristRigAttachment") :: Attachment
	if not (shoulder and elbowTop and elbowBottom and wrist and handWrist) then
		return
	end
	local edges = links(rig, {})
	local start = shoulder.WorldPosition
	local finish = target:PointToWorldSpace(handWrist.Position)
	local delta = finish - start
	local first = (shoulder.Position - elbowTop.Position).Magnitude
	local second = (elbowBottom.Position - wrist.Position).Magnitude
	local epsilon = config.MinimumSegmentStuds
	if delta.Magnitude <= epsilon or first <= epsilon or second <= epsilon then
		return
	end
	local direction = delta.Unit
	local distance = math.clamp(
		delta.Magnitude,
		math.abs(first - second) + epsilon,
		(first + second) * config.TwoHandedReachFraction
	)
	finish = start + direction * distance
	local along = (first * first - second * second + distance * distance) / (2 * distance)
	local pole = -torso.CFrame.RightVector - torso.CFrame.UpVector
	local bend = pole - direction * pole:Dot(direction)
	if bend.Magnitude <= epsilon then
		return
	end
	bend = bend.Unit
	local middle = start + direction * along + bend * math.sqrt(math.max(0, first * first - along * along))
	local upperRotation = (CFrame.lookAt(start, middle, bend) * CFrame.Angles(math.pi / 2, 0, 0)).Rotation
	local lowerRotation = (CFrame.lookAt(middle, finish, bend) * CFrame.Angles(math.pi / 2, 0, 0)).Rotation
	upper.CFrame = CFrame.new(start) * upperRotation * CFrame.new(-shoulder.Position)
	lower.CFrame = CFrame.new(middle) * lowerRotation * CFrame.new(-elbowBottom.Position)
	hand.CFrame = CFrame.new(finish) * target.Rotation * CFrame.new(-handWrist.Position)
	-- Refit attached local artwork without moving the already solved body joints.
	local known: { [BasePart]: CFrame } = {}
	for _, item in rig:GetChildren() do
		if item:IsA("BasePart") then
			known[item] = item.CFrame
		end
	end
	resolve(edges, known)
end

return StagePose
