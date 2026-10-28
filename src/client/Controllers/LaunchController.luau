--!strict
-- Ticket 17b: a Spring Pad threw this player (docs/GADGETS_DRAFT.md). The character's physics belong to this client, so the server
-- sends the velocity and it is taken here, at once, and the body is let go into a fall.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Janitor = require(Shared:WaitForChild("Util"):WaitForChild("Janitor"))
local RemoteController = require(script.Parent.RemoteController)

local LaunchController = {}

function LaunchController.Init() end

function LaunchController.Start()
	local janitor = Janitor.new()
	janitor:Add(RemoteController.connect("Launch", function(velocity: Vector3)
		local character = Players.LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") and typeof(velocity) == "Vector3" then
			humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
			root.AssemblyLinearVelocity = velocity
		end
	end))
	janitor:Add(script.Destroying:Connect(function()
		janitor:Destroy()
	end))
end

return LaunchController
