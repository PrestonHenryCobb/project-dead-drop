--!strict
-- Ticket 19-camera-comfort: optional pitch/yaw only. Remove our last transform before the default camera runs,
-- and never restore a stale transform over another view. Weapon recoil/state and all server data are untouched.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)
local Janitor = require(Shared.Util.Janitor)
local Types = require(Shared.Types)
local Settings = require(script.Parent.SettingsController)
local HeldItem = require(script.Parent.HeldItemController)
local CameraGuard = require(script.Parent.Parent.Combat.CameraGuard)
local Remote = require(script.Parent.RemoteController)
local CameraComfortController = {}
local config = GameConfig.CameraComfort
local janitor = Janitor.new()
local UNDO = "CoverStoryComfortUndo"
local APPLY = "CoverStoryComfortApply"
local started = -math.huge
local degrees = 0
local takedown = false
local lastCamera: Camera? = nil
local lastBase: CFrame? = nil
local lastWritten: CFrame? = nil

local function restore()
	local camera = workspace.CurrentCamera
	if camera and camera == lastCamera and lastBase and lastWritten and camera.CFrame == lastWritten then
		camera.CFrame = lastBase
	end
	lastCamera, lastBase, lastWritten = nil, nil, nil
end

local function pulse(strength: number)
	if Settings.cameraShakeEnabled() and HeldItem.canAct() and not CameraGuard.remoteViewing() then
		started = os.clock()
		degrees = math.max(degrees, strength)
	end
end

local function reset()
	restore()
	started, degrees, takedown = -math.huge, 0, false
end

function CameraComfortController.Init() end

function CameraComfortController.Start()
	RunService:BindToRenderStep(UNDO, Enum.RenderPriority.Camera.Value - 1, restore)
	RunService:BindToRenderStep(APPLY, Enum.RenderPriority.Camera.Value + 3, function()
		local camera = workspace.CurrentCamera
		local progress = (os.clock() - started) / config.Seconds
		if
			not camera
			or progress >= 1
			or not Settings.cameraShakeEnabled()
			or not HeldItem.canAct()
			or CameraGuard.remoteViewing()
		then
			degrees = 0
			return
		end
		local envelope = math.sin(progress * math.pi) * (1 - progress)
		local phase = progress * config.Oscillations * math.pi * 2
		local magnitude = math.rad(degrees) * envelope
		lastCamera, lastBase = camera, camera.CFrame
		camera.CFrame *= CFrame.Angles(math.sin(phase) * magnitude, math.cos(phase) * magnitude, 0)
		lastWritten = camera.CFrame
	end)
	janitor:Add(Remote.connect("DamageTaken", function()
		pulse(config.DamageDegrees)
	end))
	janitor:Add(Remote.connect("MeleeState", function(info: Types.MeleeState)
		local active = info.Active and info.Kind == "Takedown"
		if active and not takedown then
			pulse(config.TakedownDegrees)
		end
		takedown = active
	end))
	janitor:Add(Players.LocalPlayer.CharacterRemoving:Connect(reset))
	janitor:Add(function()
		RunService:UnbindFromRenderStep(UNDO)
		RunService:UnbindFromRenderStep(APPLY)
		reset()
	end)
	janitor:Add(script.Destroying:Connect(function()
		janitor:Destroy()
	end))
end

return CameraComfortController
