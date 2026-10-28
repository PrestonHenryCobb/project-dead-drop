--!strict
-- Ticket 16b: Parapet's Riot Wall (spec 15.2). The server makes the shield and welds it in front of its owner; the only thing
-- done here is that your own shield is clearer to you, so it does not hide what you are aiming at. Nothing is changed for
-- anyone else, and nothing is put on a character.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Janitor = require(Shared:WaitForChild("Util"):WaitForChild("Janitor"))

local ShieldController = {}

local config = GameConfig.Agents.Parapet.RiotWall
local localPlayer = Players.LocalPlayer
local NEAR_STUDS = config.Offset + config.Size.Z -- a shield this close to my body is mine

function ShieldController.Init() end

function ShieldController.Start()
	local janitor = Janitor.new()
	janitor:Add(RunService.RenderStepped:Connect(function()
		local folder = workspace:FindFirstChild("Shields")
		local character = localPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not (folder and root and root:IsA("BasePart")) then
			return
		end
		for _, part in folder:GetChildren() do
			if part:IsA("BasePart") then
				part.LocalTransparencyModifier = if (part.Position - root.Position).Magnitude <= NEAR_STUDS
					then config.OwnerFade
					else 0
			end
		end
	end))
	janitor:Add(script.Destroying:Connect(function()
		janitor:Destroy()
	end))
end

return ShieldController
