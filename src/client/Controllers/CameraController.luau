--!strict
-- Ticket 14: security cameras on the client (spec 18.1). The server never moves a camera; it publishes attributes on the
-- camera part (CameraState, SweepPhase, SweepSince, SweepRate) and every client swings its own copy from them, so a sweep
-- costs the network nothing. Each camera shows its cone as a faint light on the floor (white while it sweeps, red when it
-- has locked on); a disabled or destroyed camera goes dark. Only map props change, never a character.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Janitor = require(Shared:WaitForChild("Util"):WaitForChild("Janitor"))

type Tracked = { base: CFrame, light: SpotLight, color: Color3, state: string }

local CameraController = {}

local config = GameConfig.Security.Camera
local look = GameConfig.Security.CameraLook

local tracked: { [BasePart]: Tracked } = {}

local function stateColor(state: string): Color3
	if state == "Locked" then
		return look.LockedColor
	elseif state == "Sweep" then
		return look.SweepColor
	end
	return look.OffColor
end

local function track(instance: Instance)
	if not instance:IsA("BasePart") or tracked[instance] then
		return
	end
	local light = Instance.new("SpotLight")
	light.Name = "CameraCone"
	light.Face = Enum.NormalId.Front
	light.Angle = config.ConeDegrees
	light.Range = config.Range
	light.Brightness = look.Brightness
	light.Shadows = false
	light.Parent = instance
	tracked[instance] = { base = instance.CFrame, light = light, color = instance.Color, state = "" }
end

function CameraController.Init() end

function CameraController.Start()
	local janitor = Janitor.new()
	janitor:Add(CollectionService:GetInstanceAddedSignal(Enums.Tag.SecurityCamera):Connect(track))
	janitor:Add(CollectionService:GetInstanceRemovedSignal(Enums.Tag.SecurityCamera):Connect(function(instance)
		tracked[instance :: BasePart] = nil
	end))
	for _, instance in CollectionService:GetTagged(Enums.Tag.SecurityCamera) do
		track(instance)
	end
	janitor:Add(RunService.Heartbeat:Connect(function()
		local now = workspace:GetServerTimeNow()
		for part, entry in tracked do
			if not part.Parent then
				tracked[part] = nil
				continue
			end
			local state = part:GetAttribute("CameraState")
			if type(state) ~= "string" then
				continue
			end
			local phase = (
				part:GetAttribute("SweepPhase") :: number
				+ (part:GetAttribute("SweepRate") :: number) * (now - (part:GetAttribute("SweepSince") :: number))
			) % 1
			local yaw = math.rad(config.SweepDegrees / 2) * math.sin(2 * math.pi * phase)
			part.CFrame = CFrame.new(part.Position) * CFrame.Angles(0, yaw, 0) * entry.base.Rotation
			if state ~= entry.state then
				entry.state = state
				local color = stateColor(state)
				entry.light.Color = color
				entry.light.Enabled = state == "Sweep" or state == "Locked"
				part.Color = if state == "Locked" then color elseif state == "Sweep" then entry.color else look.OffColor
			end
		end
	end))
	janitor:Add(function()
		for part, entry in tracked do
			entry.light:Destroy()
			part.CFrame = entry.base
		end
		table.clear(tracked)
	end)
	janitor:Add(script.Destroying:Connect(function()
		janitor:Destroy()
	end))
end

return CameraController
