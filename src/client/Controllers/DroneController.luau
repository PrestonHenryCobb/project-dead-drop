--!strict
-- Ticket 16c: Lattice's Sparrow Drone on the client (spec 15.3). While the server says the drone is up, the camera views from
-- it: the mouse turns the view, W/A/S/D fly along it, Jump goes up and Crouch down. The wanted direction goes to the server
-- (RequestSparrowMove), which moves the drone; the camera glides to wherever the drone is. When it ends the view returns.
-- Interact still works from the drone (IntelController, SecurityInteractController read DroneController.part()).
-- SPEC-QUESTION / gap: keyboard and mouse only; a gamepad cannot fly it yet.
--
--   DroneController.part() -> BasePart?    the drone, while this player is flying one

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Janitor = require(Shared:WaitForChild("Util"):WaitForChild("Janitor"))
local Types = require(Shared:WaitForChild("Types"))
local RemoteController = require(script.Parent.RemoteController)

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

function DroneController.part(): BasePart?
	return drone
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
local function wanted(cframe: CFrame): Vector3
	local forward = (if anyDown(controls.MoveForward) then 1 else 0) - (if anyDown(controls.MoveBack) then 1 else 0)
	local right = (if anyDown(controls.MoveRight) then 1 else 0) - (if anyDown(controls.MoveLeft) then 1 else 0)
	local up = (if UserInputService:IsKeyDown(controls.Jump) then 1 else 0)
		- (if UserInputService:IsKeyDown(controls.Crouch) then 1 else 0)
	local direction = cframe.LookVector * forward + cframe.RightVector * right + Vector3.new(0, up, 0)
	return if direction.Magnitude > 1 then direction.Unit else direction
end

local function step(dt: number)
	local camera = workspace.CurrentCamera
	local body = drone
	if not (camera and body) then
		return
	end
	camera.CameraType = Enum.CameraType.Scriptable
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	if UserInputService:GetFocusedTextBox() == nil then
		local delta = UserInputService:GetMouseDelta()
		local radians = math.rad(look.DegreesPerPixel)
		local limit = math.rad(look.PitchLimitDegrees)
		yaw -= delta.X * radians
		pitch = math.clamp(pitch - delta.Y * radians, -limit, limit)
	end
	viewAt = viewAt:Lerp(body.Position, 1 - math.exp(-config.CameraSmoothRate * dt))
	local orientation = CFrame.fromOrientation(pitch, yaw, 0)
	camera.CFrame = CFrame.new(viewAt) * orientation
	sendElapsed += dt
	if sendElapsed >= 1 / config.MoveHz then
		sendElapsed = 0
		local direction = if UserInputService:GetFocusedTextBox() == nil then wanted(orientation) else Vector3.zero
		RemoteController.fire("RequestSparrowMove", direction)
	end
end

local function finish()
	session:Cleanup()
	drone = nil
	UserInputService.MouseBehavior = savedMouse
	local camera = workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Custom
	end
end

local function begin(body: BasePart)
	if drone then
		finish()
	end
	drone = body
	savedMouse = UserInputService.MouseBehavior
	local camera = workspace.CurrentCamera
	if camera then
		local _, cameraYaw, _ = camera.CFrame:ToOrientation()
		yaw, pitch = cameraYaw, 0
	end
	viewAt = body.Position
	sendElapsed = 0
	RunService:BindToRenderStep(STEP_NAME, Enum.RenderPriority.Camera.Value + 2, step) -- after DisguiseFacing
	session:Add(function()
		RunService:UnbindFromRenderStep(STEP_NAME)
	end)
end

-- My drone: the Drone part that appears beside my body when the server says it took off. It is sent no other way (nothing
-- on the part says whose it is), and may arrive a moment after the message, so wait for it a little.
local function findOwn(): BasePart?
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return nil
	end
	local deadline = os.clock() + config.FindSeconds
	repeat
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
	janitor:Add(RemoteController.connect("SparrowState", function(info: Types.SparrowStateInfo)
		if info.Active then
			local own = findOwn()
			if own then
				begin(own)
			end
		elseif drone then
			finish()
		end
	end))
	janitor:Add(function()
		if drone then
			finish()
		end
	end)
	janitor:Add(script.Destroying:Connect(function()
		janitor:Destroy()
	end))
end

return DroneController
