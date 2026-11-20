--!strict
-- Ticket 16c: Lattice's Sparrow Drone on the client (spec 15.3). While the server says the drone is up, the camera views from
-- it: the mouse turns the view, W/A/S/D fly along it, Jump goes up and Crouch down. The wanted direction goes to the server
-- (RequestSparrowMove), which moves the drone; the camera glides to wherever the drone is. When it ends the view returns.
-- Interact still works from the drone (IntelController, SecurityInteractController read DroneController.part()).
-- Keyboard/mouse and gamepad share the same server-validated movement requests.
--
--   DroneController.part() -> BasePart?    the drone, while this player is flying one

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local InputHints = require(Shared.Util.InputHints)
local Janitor = require(Shared:WaitForChild("Util"):WaitForChild("Janitor"))
local Types = require(Shared:WaitForChild("Types"))
local RemoteController = require(script.Parent.RemoteController)
local HeldItemController = require(script.Parent.HeldItemController)
local CameraGuard = require(script.Parent.Parent.Combat.CameraGuard)
local FlightInput = require(script.Parent.Parent.Combat.FlightInput)
local HudKit = require(Shared.Util.HudKit)
local HudTheme = require(Shared.Util.HudTheme)

local DroneController = {}

local config = GameConfig.Agents.Lattice.SparrowDrone
local look = GameConfig.Spectate.Camera
local controls = GameConfig.Controls
local STEP_NAME = "CoverStoryDrone"

local drone: BasePart? = nil
local yaw, pitch = 0, 0
local viewAt = Vector3.zero
local sendElapsed = 0
local savedMouse = Enum.MouseBehavior.Default
local session = Janitor.new()
local generation = 0
local phase: Types.Phase? = nil
local finish: () -> ()
local pilotHint: TextLabel? = nil

function DroneController.part(): BasePart?
	return drone
end

-- Intel and security are usable from the Sparrow while it is the foreground view; newer dialogs still block it.
function DroneController.inputBlocked(): boolean
	return HeldItemController.isInputBlocked(if drone then script else nil)
end

local function anyDown(keys: { Enum.KeyCode }): boolean
	for _, key in keys do
		if UserInputService:IsKeyDown(key) then
			return true
		end
	end
	return false
end

-- The way the player wants to fly, in world space, no longer than 1.
local function wanted(cframe: CFrame, padMove: Vector2, padUp: number): Vector3
	local forward = (if anyDown(controls.MoveForward) then 1 else 0) - (if anyDown(controls.MoveBack) then 1 else 0)
	local right = (if anyDown(controls.MoveRight) then 1 else 0) - (if anyDown(controls.MoveLeft) then 1 else 0)
	local up = (if UserInputService:IsKeyDown(controls.Jump) then 1 else 0)
		- (if UserInputService:IsKeyDown(controls.Crouch) then 1 else 0)
	local direction = cframe.LookVector * (forward + padMove.Y)
		+ cframe.RightVector * (right + padMove.X)
		+ Vector3.new(0, up + padUp, 0)
	return if direction.Magnitude > 1 then direction.Unit else direction
end

local function step(dt: number)
	local camera = workspace.CurrentCamera
	local body = drone
	if not (camera and body) then
		return
	end
	if not body:IsDescendantOf(workspace) then
		finish()
		return
	end
	if CameraGuard.menuOpen() then
		finish()
		return
	end
	local blocked = DroneController.inputBlocked()
	local padMove, padLook, padUp = FlightInput.read()
	camera.CameraType = Enum.CameraType.Scriptable
	UserInputService.MouseBehavior = if blocked then Enum.MouseBehavior.Default else Enum.MouseBehavior.LockCenter
	if not blocked then
		local delta = UserInputService:GetMouseDelta()
		local radians = math.rad(look.DegreesPerPixel)
		local limit = math.rad(look.PitchLimitDegrees)
		local stickRadians = math.rad(GameConfig.ClientFlight.LookDegreesPerSecond) * dt
		yaw -= delta.X * radians + padLook.X * stickRadians
		pitch = math.clamp(pitch - delta.Y * radians + padLook.Y * stickRadians, -limit, limit)
	end
	viewAt = viewAt:Lerp(body.Position, 1 - math.exp(-config.CameraSmoothRate * dt))
	local orientation = CFrame.fromOrientation(pitch, yaw, 0)
	camera.CFrame = CFrame.new(viewAt) * orientation
	sendElapsed += dt
	if sendElapsed >= 1 / config.MoveHz then
		sendElapsed = 0
		local direction = if not blocked then wanted(orientation, padMove, padUp) else Vector3.zero
		RemoteController.fire("RequestSparrowMove", direction)
	end
end

function finish()
	session:Cleanup()
	drone = nil
	HeldItemController.setInterfaceBlocked(script, false)
	CameraGuard.setRemoteView(script, false)
	UserInputService.MouseBehavior = savedMouse
	CameraGuard.restoreGameplay()
	if pilotHint then
		pilotHint.Visible = false
	end
end

local function begin(body: BasePart)
	if drone then
		finish()
	end
	drone = body
	HeldItemController.setInterfaceBlocked(script, true, true)
	CameraGuard.setRemoteView(script, true)
	savedMouse = UserInputService.MouseBehavior
	local camera = workspace.CurrentCamera
	if camera then
		local _, cameraYaw, _ = camera.CFrame:ToOrientation()
		yaw, pitch = cameraYaw, 0
	end
	viewAt = body.Position
	if pilotHint then
		pilotHint.Visible = true
	end
	sendElapsed = 0
	RunService:BindToRenderStep(STEP_NAME, Enum.RenderPriority.Camera.Value + 2, step) -- after DisguiseFacing
	session:Add(function()
		RunService:UnbindFromRenderStep(STEP_NAME)
	end)
end

-- My drone: the Drone part that appears beside my body when the server says it took off. It is sent no other way (nothing
-- on the part says whose it is), and may arrive a moment after the message, so wait for it a little.
local function findOwn(requestGeneration: number): BasePart?
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return nil
	end
	local deadline = os.clock() + config.FindSeconds
	repeat
		if generation ~= requestGeneration or Players.LocalPlayer.Character ~= character then
			return nil
		end
		local folder = workspace:FindFirstChild("Shields")
		if folder then
			for _, part in folder:GetChildren() do
				if
					part:IsA("BasePart")
					and part.Name == "Drone"
					and (part.Position - root.Position).Magnitude <= config.HeightAbove + config.FindSlackStuds
				then
					return part
				end
			end
		end
		task.wait()
	until os.clock() >= deadline
	return nil
end

function DroneController.Init() end

function DroneController.Start()
	local janitor = Janitor.new()
	local theme = HudTheme.get()
	local gui = HudKit.screen("SparrowPilotHud")
	janitor:Add(gui)
	local hint = HudKit.text(
		gui,
		"FlightControls",
		UDim2.new(0.5, 0, 1, -theme.MarginPixels),
		Vector2.new(0.5, 1),
		UDim2.fromOffset(theme.ActionWidthPixels * 2, theme.ActionHeightPixels)
	)
	hint.TextSize = theme.CaptionSize
	hint.TextWrapped = true
	hint.Visible = false
	pilotHint = hint
	local function refreshHint()
		hint.Text = InputHints.text(
			`SPARROW · WASD FLY · MOUSE LOOK · {InputHints.name(controls.Jump)} / {InputHints.name(controls.Crouch)} UP / DOWN`,
			"SPARROW · LEFT STICK FLY · RIGHT STICK LOOK · A / B UP / DOWN"
		)
	end
	refreshHint()
	janitor:Add(InputHints.onChange(refreshHint))
	local function reset()
		generation += 1
		if drone then
			finish()
		end
	end
	janitor:Add(RemoteController.connect("SparrowState", function(info: Types.SparrowStateInfo)
		generation += 1
		local requestGeneration = generation
		if info.Active then
			if phase == "Lobby" or phase == "Insertion" or phase == "Results" then
				return
			end
			local own = findOwn(requestGeneration)
			if own and generation == requestGeneration then
				begin(own)
			end
		elseif drone then
			finish()
		end
	end))
	janitor:Add(Players.LocalPlayer.CharacterRemoving:Connect(reset))
	janitor:Add(RemoteController.connect("Downed", reset))
	janitor:Add(RemoteController.connect("Eliminated", reset))
	janitor:Add(RemoteController.connect("PhaseChanged", function(value: Types.Phase)
		phase = value
		if value == "Lobby" or value == "Insertion" or value == "Results" then
			reset()
		end
	end))
	janitor:Add(reset)
	janitor:Add(script.Destroying:Connect(function()
		janitor:Destroy()
	end))
end

return DroneController
