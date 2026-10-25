--!strict
-- Which way the player's body faces, and where their head looks (spec 8.1; OPEN_QUESTIONS C5; STYLE_QUESTIONS A1, A3).
--
-- The camera is first person, so the real direction a player is looking is where the camera points. Other players see
-- something different: the body faces where it walks, at the NPC turn rate, exactly like an NPC; only the head turns
-- toward the camera, up to Cover.NeckMaxYaw sideways. Standing still, the body turns slowly to the camera once it has
-- been idle for IdleTurnDelay, like an NPC glancing around.
--
-- Root rotation follows network ownership; neck posing is local visual feedback. RigService converts the rig to
-- Motor6D joints. Accept AnimationConstraint too while a legacy rig is present in Studio.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

local FacingController = {}

local config = GameConfig.Cover
local localPlayer = Players.LocalPlayer
local STOP_TURNING_DEGREES = 3 -- an idle turn ends when the body is this close to the camera

local humanoid: Humanoid? = nil
local root: BasePart? = nil
local neck: (Motor6D | AnimationConstraint)? = nil
local idleSeconds = 0
local idleTurning = false

-- Yaw such that CFrame.Angles(0, yaw, 0) looks along the direction (the same convention the server uses for NPCs).
local function yawOf(direction: Vector3): number
	return math.atan2(-direction.X, -direction.Z)
end

local function wrap(angle: number): number
	return (angle + math.pi) % (2 * math.pi) - math.pi
end

local function turnToward(current: number, target: number, maxStep: number): number
	return current + math.clamp(wrap(target - current), -maxStep, maxStep)
end

local function onCharacter(newCharacter: Model)
	humanoid = newCharacter:WaitForChild("Humanoid") :: Humanoid
	root = newCharacter:WaitForChild("HumanoidRootPart") :: BasePart
	local head = newCharacter:WaitForChild("Head")
	local joint = head:WaitForChild("Neck")
	neck = if joint:IsA("Motor6D") or joint:IsA("AnimationConstraint") then joint else nil
	idleSeconds = 0
	idleTurning = false; -- We rotate the body ourselves; the default would face the camera.
	(humanoid :: Humanoid).AutoRotate = false
end

local function step(dt: number)
	local body, rootPart, camera = humanoid, root, workspace.CurrentCamera
	if not (body and rootPart and camera and body.Health > 0) then
		return
	end

	local cameraLook = camera.CFrame.LookVector
	local cameraYaw = yawOf(Vector3.new(cameraLook.X, 0, cameraLook.Z))
	local look = rootPart.CFrame.LookVector
	local bodyYaw = yawOf(Vector3.new(look.X, 0, look.Z))

	local moving = body.MoveDirection.Magnitude > 0.1
	if moving then
		idleSeconds = 0
		idleTurning = false
		bodyYaw = turnToward(bodyYaw, yawOf(body.MoveDirection), math.rad(GameConfig.NPC.MaxYawRate) * dt)
	else
		idleSeconds += dt
		local gap = math.abs(wrap(cameraYaw - bodyYaw))
		if idleTurning and gap < math.rad(STOP_TURNING_DEGREES) then
			idleTurning = false
		elseif not idleTurning and idleSeconds >= config.IdleTurnDelay and gap > math.rad(config.IdleTurnDeadband) then
			idleTurning = true
		end
		if idleTurning then
			bodyYaw = turnToward(bodyYaw, cameraYaw, math.rad(config.IdleTurnRate) * dt)
		end
	end
	rootPart.CFrame = CFrame.new(rootPart.Position) * CFrame.Angles(0, bodyYaw, 0)

	-- The head follows the camera, within what a neck can do.
	local headMotor = neck
	if headMotor then
		local yaw = math.clamp(wrap(cameraYaw - bodyYaw), -math.rad(config.NeckMaxYaw), math.rad(config.NeckMaxYaw))
		local pitch = math.clamp(math.asin(cameraLook.Y), -math.rad(config.NeckMaxPitch), math.rad(config.NeckMaxPitch))
		headMotor.Transform = CFrame.Angles(pitch, yaw, 0)
	end
end

function FacingController.Init() end

function FacingController.Start()
	localPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
	localPlayer.CharacterAdded:Connect(onCharacter)
	if localPlayer.Character then
		task.spawn(onCharacter, localPlayer.Character)
	end
	-- After the camera has moved this frame, so the head follows where the camera ended up.
	RunService:BindToRenderStep("DisguiseFacing", Enum.RenderPriority.Camera.Value + 1, step)
end

return FacingController
