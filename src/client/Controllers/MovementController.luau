--!strict
-- Walking (step 8B.5, SPEC_CHANGES 6.8 / 8.1). The game has no PlayerModule and RigService turns Roblox's own keyboard
-- controls off, so this is the player's movement: keys and the left stick give a direction relative to the camera, and
-- the walk eases up from a stop over GameConfig.Movement.AccelSeconds and down to one over DecelSeconds. NPCs ease with
-- the same two numbers on the server, so a smooth start or stop is never a tell.
--
-- Humanoid:Move walks at WalkSpeed times the length of the vector, so easing the vector eases the speed; the server's
-- WalkSpeed (disguise role, sprint, crouch) still sets how fast "full" is.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

local MovementController = {}

local controls = GameConfig.Controls
local movement = GameConfig.Movement
local localPlayer = Players.LocalPlayer
local BIND_NAME = "CoverStoryMovement"

local humanoid: Humanoid? = nil
local moving = Vector3.zero -- the eased move vector, length 0 to 1

local function anyDown(keys: { Enum.KeyCode }): boolean
	for _, key in keys do
		if UserInputService:IsKeyDown(key) then
			return true
		end
	end
	return false
end

-- Where the player is asking to go: x right, y forward, length up to 1.
local function wanted(): Vector2
	if UserInputService:GetFocusedTextBox() then
		return Vector2.zero
	end
	local x = (if anyDown(controls.MoveRight) then 1 else 0) - (if anyDown(controls.MoveLeft) then 1 else 0)
	local y = (if anyDown(controls.MoveForward) then 1 else 0) - (if anyDown(controls.MoveBack) then 1 else 0)
	local keys = Vector2.new(x, y)
	for _, input in UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1) do
		if input.KeyCode == Enum.KeyCode.Thumbstick1 then
			local stick = Vector2.new(input.Position.X, input.Position.Y)
			if stick.Magnitude > controls.StickDeadzone then
				keys += stick
			end
		end
	end
	return if keys.Magnitude > 1 then keys.Unit else keys
end

local function step(dt: number)
	local body, camera = humanoid, workspace.CurrentCamera
	if not (body and camera and body.Health > 0) then
		moving = Vector3.zero
		return
	end
	local input = wanted()
	local look = camera.CFrame.LookVector
	local forward = Vector3.new(look.X, 0, look.Z)
	forward = if forward.Magnitude > 1e-3 then forward.Unit else Vector3.zAxis
	local right = Vector3.new(-forward.Z, 0, forward.X)
	local target = right * input.X + forward * input.Y

	-- Speed up over AccelSeconds, slow down over DecelSeconds; a turn blends through the change.
	local seconds = if target.Magnitude > moving.Magnitude then movement.AccelSeconds else movement.DecelSeconds
	local change = target - moving
	local maxStep = dt / seconds
	moving = if change.Magnitude <= maxStep then target else moving + change.Unit * maxStep
	body:Move(moving, false)
end

local function onJump(_: string, state: Enum.UserInputState): Enum.ContextActionResult
	local body = humanoid
	if state == Enum.UserInputState.Begin and body and not UserInputService:GetFocusedTextBox() then
		body.Jump = true
	end
	return Enum.ContextActionResult.Pass
end

local function onCharacter(character: Model)
	humanoid = character:WaitForChild("Humanoid") :: Humanoid
	moving = Vector3.zero
end

function MovementController.Init() end

function MovementController.Start()
	localPlayer.CharacterAdded:Connect(onCharacter)
	if localPlayer.Character then
		task.spawn(onCharacter, localPlayer.Character)
	end
	ContextActionService:BindAction("CoverStoryJump", onJump, false, controls.Jump, controls.JumpPad)
	RunService:BindToRenderStep(BIND_NAME, Enum.RenderPriority.Input.Value, step)
end

return MovementController
