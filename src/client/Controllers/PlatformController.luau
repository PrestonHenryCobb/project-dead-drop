--!strict
-- Rides moving platforms (the gondola, BUILD_ORDER Step 7B pass 2b). The server moves the gondola; each client moves its
-- own character with it, since the client runs its character's physics: every frame, if the character stands on the
-- gondola's floor, it is shifted by however far the floor moved since the last frame.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Enums = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Enums"))

local PlatformController = {}

local PROBE_DEPTH = 6 -- studs below the character's root to look for a platform under its feet

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include

local lastPosition: Vector3? = nil
local lastFloor: BasePart? = nil

local function refreshFilter()
	rayParams.FilterDescendantsInstances = CollectionService:GetTagged(Enums.Tag.Gondola)
end

function PlatformController.Init()
	refreshFilter()
end

function PlatformController.Start()
	-- The gondola streams in and out; keep the probe's list current.
	CollectionService:GetInstanceAddedSignal(Enums.Tag.Gondola):Connect(refreshFilter)
	CollectionService:GetInstanceRemovedSignal(Enums.Tag.Gondola):Connect(refreshFilter)
	RunService.PreSimulation:Connect(function()
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not (root and root:IsA("BasePart")) or root.Anchored then
			lastFloor, lastPosition = nil, nil
			return
		end
		-- First carry the character by however far the floor it stood on has moved (even a big jump after a network
		-- hitch), then look for the floor under it again.
		if lastFloor and lastPosition and lastFloor.Parent then
			local moved = lastFloor.Position - lastPosition
			if moved.Magnitude > 0 then
				root.CFrame += moved
			end
		end
		local hit = workspace:Raycast(root.Position, Vector3.new(0, -PROBE_DEPTH, 0), rayParams)
		local floor = if hit and hit.Instance:IsA("BasePart") then hit.Instance else nil
		lastFloor = floor
		lastPosition = if floor then floor.Position else nil
	end)
end

return PlatformController
