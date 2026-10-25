--!strict
-- Step 8B.2: show the real body below the camera, hide head-mounted items, and pose the real arms locally.
-- Motor6D.Transform and LocalTransparencyModifier do not create replicated identity markers or animations.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Janitor = require(Shared:WaitForChild("Util"):WaitForChild("Janitor"))
local WeaponController = require(script.Parent.WeaponController)

type Arm = {
	shoulder: Motor6D,
	elbow: Motor6D,
	wrist: Motor6D,
	side: number,
	heldShoulder: CFrame,
	heldElbow: CFrame,
	heldWrist: CFrame,
	posed: boolean,
}

local FirstPersonBodyController = {}
local localPlayer = Players.LocalPlayer
local janitor = Janitor.new()
local characterJanitor = Janitor.new()
local character: Model? = nil
local parts: { [BasePart]: boolean } = {} -- true means hidden; body accessories stay visible
local arms: { Arm } = {}
local dirty = false
local lastTick = -1
local epsilon = GameConfig.Combat.Feedback.ShotVisualMinStuds

local function clear()
	characterJanitor:Cleanup()
	for part in parts do
		part.LocalTransparencyModifier = 0
	end
	for _, arm in arms do
		arm.shoulder.Transform = CFrame.identity
		arm.elbow.Transform = CFrame.identity
		arm.wrist.Transform = CFrame.identity
	end
	table.clear(parts)
	table.clear(arms)
	character = nil
	lastTick = -1
end

local function refresh(model: Model)
	table.clear(parts)
	table.clear(arms)
	local head = model:FindFirstChild("Head")
	local joints: { [string]: Motor6D } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Motor6D") and descendant.Part1 then
			joints[descendant.Part1.Name] = descendant
		elseif descendant:IsA("BasePart") then
			local hidden = descendant == head or descendant.Name == "HumanoidRootPart"
			local accessory = descendant:FindFirstAncestorOfClass("Accessory")
			if accessory then
				local handle = accessory:FindFirstChild("Handle")
				if handle then
					for _, item in handle:GetChildren() do
						if
							(item:IsA("Attachment") and head and head:FindFirstChild(item.Name))
							or (item:IsA("Weld") and (item.Part0 == head or item.Part1 == head))
						then
							hidden = true
						end
					end
				end
			end
			parts[descendant] = hidden
		end
	end
	for _, side in { "Right", "Left" } do
		local shoulder, elbow, wrist = joints[side .. "UpperArm"], joints[side .. "LowerArm"], joints[side .. "Hand"]
		if shoulder and elbow and wrist then
			table.insert(arms, {
				shoulder = shoulder,
				elbow = elbow,
				wrist = wrist,
				side = if side == "Right" then 1 else -1,
				heldShoulder = CFrame.identity,
				heldElbow = CFrame.identity,
				heldWrist = CFrame.identity,
				posed = false,
			})
		end
	end
	dirty = false
	lastTick = -1
end

local function onCharacter(model: Model)
	clear()
	character = model
	dirty = true
	characterJanitor:Add(model.DescendantAdded:Connect(function()
		dirty = true
	end))
	characterJanitor:Add(model.DescendantRemoving:Connect(function()
		dirty = true
	end))
end

local function limbFrame(start: Vector3, finish: Vector3, bend: Vector3, pivot: Vector3): CFrame
	-- R15 limb local +Y points toward the proximal joint, and -Y toward the distal joint.
	return CFrame.lookAt(start, finish, bend) * CFrame.Angles(math.pi / 2, 0, 0) * CFrame.new(-pivot)
end

local function solve(arm: Arm, hand: CFrame, camera: Camera)
	local shoulder, elbow, wrist = arm.shoulder, arm.elbow, arm.wrist
	local torso = shoulder.Part0
	if not torso then
		return
	end
	local start = (torso.CFrame * shoulder.C0).Position
	local target = (hand * wrist.C1).Position
	local upperLength = (elbow.C0.Position - shoulder.C1.Position).Magnitude
	local lowerLength = (wrist.C0.Position - elbow.C1.Position).Magnitude
	if upperLength <= epsilon or lowerLength <= epsilon then
		return
	end
	local delta = target - start
	if delta.Magnitude <= epsilon then
		return
	end
	local direction = delta.Unit
	local distance =
		math.clamp(delta.Magnitude, math.abs(upperLength - lowerLength) + epsilon, upperLength + lowerLength - epsilon)
	local pole = camera.CFrame.RightVector * arm.side - camera.CFrame.UpVector
	local bend = pole - direction * pole:Dot(direction)
	if bend.Magnitude <= epsilon then
		bend = camera.CFrame.LookVector:Cross(direction)
	end
	if bend.Magnitude <= epsilon then
		return
	end
	bend = bend.Unit
	local along = (upperLength * upperLength - lowerLength * lowerLength + distance * distance) / (2 * distance)
	local height = math.sqrt(math.max(0, upperLength * upperLength - along * along))
	local middle = start + direction * along + bend * height
	local finish = start + direction * distance
	local upper = limbFrame(start, middle, bend, shoulder.C1.Position)
	local lower = limbFrame(middle, finish, bend, elbow.C1.Position)
	local reachableHand = CFrame.new(finish) * hand.Rotation * CFrame.new(-wrist.C1.Position)
	arm.heldShoulder = shoulder.C0:Inverse() * torso.CFrame:Inverse() * upper * shoulder.C1
	arm.heldElbow = elbow.C0:Inverse() * upper:Inverse() * lower * elbow.C1
	arm.heldWrist = wrist.C0:Inverse() * lower:Inverse() * reachableHand * wrist.C1
	arm.posed = true
end

local function pose()
	local camera = workspace.CurrentCamera
	local model = character
	if not (camera and model) then
		return
	end
	if dirty then
		refresh(model)
	end
	local right, left = WeaponController.getHandTargets()
	local tick = math.floor(workspace:GetServerTimeNow() * GameConfig.Animation.StepHz)
	for _, arm in arms do
		local target = if arm.side > 0 then right else left
		if target then
			if tick ~= lastTick or not arm.posed then
				solve(arm, target, camera)
			end
			if arm.posed then
				arm.shoulder.Transform = arm.heldShoulder
				arm.elbow.Transform = arm.heldElbow
				arm.wrist.Transform = arm.heldWrist
			end
		elseif arm.posed then
			arm.shoulder.Transform = CFrame.identity
			arm.elbow.Transform = CFrame.identity
			arm.wrist.Transform = CFrame.identity
			arm.posed = false
		end
	end
	lastTick = tick
end

local function visibility()
	local model = character
	if not model then
		return
	end
	if dirty then
		refresh(model)
	end
	for part, hidden in parts do
		part.LocalTransparencyModifier = if hidden then 1 else 0
	end
end

function FirstPersonBodyController.Init() end

function FirstPersonBodyController.Start()
	janitor:Add(localPlayer.CharacterAdded:Connect(onCharacter))
	janitor:Add(localPlayer.CharacterRemoving:Connect(clear))
	if localPlayer.Character then
		onCharacter(localPlayer.Character)
	end
	janitor:Add(RunService.PreSimulation:Connect(pose))
	RunService:BindToRenderStep("FirstPersonBody", Enum.RenderPriority.Camera.Value + 3, visibility)
	janitor:Add(function()
		RunService:UnbindFromRenderStep("FirstPersonBody")
		clear()
		characterJanitor:Destroy()
	end)
	janitor:Add(script.Destroying:Connect(function()
		janitor:Destroy()
	end))
end

return FirstPersonBodyController
