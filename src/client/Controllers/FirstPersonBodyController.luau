--!strict
-- Ticket 8.15: cosmetic FPS arms use the avatar's meshes/colors in a local camera rig. The real avatar is hidden
-- only from its owner. Its locomotion-facing rotation and animations remain untouched for everyone else.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Janitor = require(Shared:WaitForChild("Util"):WaitForChild("Janitor"))
local WeaponController = require(script.Parent.WeaponController)

type Arm = {
	side: number,
	upper: BasePart,
	lower: BasePart,
	hand: BasePart,
	sourceUpper: BasePart,
	sourceLower: BasePart,
	sourceHand: BasePart,
	heldTarget: CFrame?,
}

local FirstPersonBodyController = {}
local config = GameConfig.Combat.FirstPersonArms
local localPlayer = Players.LocalPlayer
local janitor = Janitor.new()
local characterJanitor = Janitor.new()
local rigJanitor = Janitor.new()
local character: Model? = nil
local rig: Model? = nil
local parts: { BasePart } = {}
local arms: { Arm } = {}
local dirty = false
local lastTick = -1

local function clear()
	characterJanitor:Cleanup()
	rigJanitor:Cleanup()
	for _, part in parts do
		part.LocalTransparencyModifier = 0
	end
	table.clear(parts)
	table.clear(arms)
	character, rig = nil, nil
	lastTick = -1
end

local function cloneLimb(source: BasePart, parent: Model): BasePart
	local limb = source:Clone() :: BasePart
	-- Strip joints, constraints, scripts and attachments before parenting: cosmetic meshes never drive the avatar.
	for _, item in limb:GetDescendants() do
		if not (item:IsA("DataModelMesh") or item:IsA("SurfaceAppearance") or item:IsA("Decal")) then
			item:Destroy()
		end
	end
	limb.Anchored = true
	limb.CanCollide, limb.CanQuery, limb.CanTouch, limb.CastShadow = false, false, false, false
	limb.Transparency = 1
	limb.LocalTransparencyModifier = 0
	limb.Parent = parent
	return limb
end

local function refresh(model: Model, camera: Camera)
	rigJanitor:Cleanup()
	table.clear(parts)
	table.clear(arms)
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			table.insert(parts, item)
		end
	end
	local cosmetic = Instance.new("Model")
	cosmetic.Name = "FirstPersonArms"
	cosmetic.Parent = camera
	rig = cosmetic
	rigJanitor:Add(cosmetic)
	for _, side in { "Right", "Left" } do
		local upper = model:FindFirstChild(side .. "UpperArm")
		local lower = model:FindFirstChild(side .. "LowerArm")
		local hand = model:FindFirstChild(side .. "Hand")
		if upper and upper:IsA("BasePart") and lower and lower:IsA("BasePart") and hand and hand:IsA("BasePart") then
			table.insert(arms, {
				side = if side == "Right" then 1 else -1,
				upper = cloneLimb(upper, cosmetic),
				lower = cloneLimb(lower, cosmetic),
				hand = cloneLimb(hand, cosmetic),
				sourceUpper = upper,
				sourceLower = lower,
				sourceHand = hand,
				heldTarget = nil,
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

local function appearance(part: BasePart, source: BasePart)
	part.Color = source.Color
	part.Material = source.Material
end

local function segment(
	part: BasePart,
	source: BasePart,
	start: Vector3,
	finish: Vector3,
	pole: Vector3,
	drawScale: number
)
	local size = source.Size * config.Scale * drawScale
	part.Size = Vector3.new(size.X, (finish - start).Magnitude, size.Z)
	part.CFrame = CFrame.lookAt((start + finish) / 2, finish, pole) * CFrame.Angles(math.pi / 2, 0, 0)
	appearance(part, source)
	part.Transparency = 0
end

local function drawArm(arm: Arm, target: CFrame, camera: Camera, drawScale: number)
	local offset = config.ShoulderOffset * drawScale
	local start = camera.CFrame:PointToWorldSpace(Vector3.new(offset.X * arm.side, offset.Y, offset.Z))
	arm.hand.Size = arm.sourceHand.Size * config.Scale * drawScale
	local wrist = target:PointToWorldSpace(Vector3.new(0, arm.hand.Size.Y / 2, 0))
	local delta = wrist - start
	local distance = delta.Magnitude
	if distance <= config.MinimumSegmentStuds * 2 then
		return
	end
	local direction = delta / distance
	local upperLength = arm.sourceUpper.Size.Y * config.Scale.Y * drawScale
	local lowerLength = arm.sourceLower.Size.Y * config.Scale.Y * drawScale
	-- A cosmetic rig may stretch offscreen at the shoulder; hands remain attached to the rendered weapon.
	local reach = math.max(1, distance * (1 + config.ReachSlackFraction) / (upperLength + lowerLength))
	upperLength *= reach
	lowerLength *= reach
	local along = math.clamp(
		(upperLength * upperLength - lowerLength * lowerLength + distance * distance) / (2 * distance),
		config.MinimumSegmentStuds,
		distance - config.MinimumSegmentStuds
	)
	local pole = camera.CFrame.RightVector * arm.side - camera.CFrame.UpVector
	local bend = pole - direction * pole:Dot(direction)
	if bend.Magnitude <= config.MinimumSegmentStuds then
		bend = camera.CFrame.LookVector:Cross(direction)
	end
	if bend.Magnitude <= config.MinimumSegmentStuds then
		return
	end
	bend = bend.Unit
	local middle = start + direction * along + bend * math.sqrt(math.max(0, upperLength * upperLength - along * along))
	segment(arm.upper, arm.sourceUpper, start, middle, bend, drawScale)
	segment(arm.lower, arm.sourceLower, middle, wrist, bend, drawScale)
	arm.hand.CFrame = target
	appearance(arm.hand, arm.sourceHand)
	arm.hand.Transparency = 0
end

local function render()
	local model, camera = character, workspace.CurrentCamera
	if not (model and camera) then
		return
	end
	if dirty or not rig or rig.Parent ~= camera then
		refresh(model, camera)
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local ownerView = camera.CameraSubject == humanoid or camera.CameraSubject == nil
	for _, part in parts do
		part.LocalTransparencyModifier = if ownerView then 1 else 0
	end
	local right, left, drawScale = WeaponController.getHandTargets()
	local tick = math.floor(workspace:GetServerTimeNow() * GameConfig.Animation.StepHz)
	for _, arm in arms do
		arm.upper.Transparency, arm.lower.Transparency, arm.hand.Transparency = 1, 1, 1
		local target = if arm.side > 0 then right else left
		if target and ownerView then
			-- Hold animation in camera space: looking and walking never inherit the body's facing rotation.
			if tick ~= lastTick or not arm.heldTarget then
				local relative = camera.CFrame:ToObjectSpace(target)
				arm.heldTarget = CFrame.new(relative.Position / drawScale) * relative.Rotation
			end
			local relative = arm.heldTarget :: CFrame
			drawArm(
				arm,
				camera.CFrame * (CFrame.new(relative.Position * drawScale) * relative.Rotation),
				camera,
				drawScale
			)
		else
			arm.heldTarget = nil
		end
	end
	lastTick = tick
end

function FirstPersonBodyController.Init() end

function FirstPersonBodyController.Start()
	janitor:Add(localPlayer.CharacterAdded:Connect(onCharacter))
	janitor:Add(localPlayer.CharacterRemoving:Connect(clear))
	if localPlayer.Character then
		onCharacter(localPlayer.Character)
	end
	RunService:BindToRenderStep("FirstPersonBody", Enum.RenderPriority.Camera.Value + 3, render)
	janitor:Add(function()
		RunService:UnbindFromRenderStep("FirstPersonBody")
		clear()
		characterJanitor:Destroy()
		rigJanitor:Destroy()
	end)
	janitor:Add(script.Destroying:Connect(function()
		janitor:Destroy()
	end))
end

return FirstPersonBodyController
