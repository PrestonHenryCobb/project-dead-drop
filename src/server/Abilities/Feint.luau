--!strict
-- Feint's ability, Double (spec 15.7): an NPC that looks like her right now (True Form if she is Exposed) is set just ahead of
-- her and walks her aim line for a few seconds (NPCService.spawnDecoy). Disguised, it walks at the pace of the role it wears,
-- like any NPC; in True Form it sprints. Shot, it gives the red hitmarker of an agent and pops (CombatService).
-- Her passive, Smoke and Mirrors, is in CoverService (PingOffset) and DisguiseService (DisguiseSeconds).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local DisguiseService = require(script.Parent.Parent.Services.DisguiseService)
local DownedService = require(script.Parent.Parent.Services.DownedService)
local MatchService = require(script.Parent.Parent.Services.MatchService)
local NPCService = require(script.Parent.Parent.Services.NPCService)
local Ability = require(script.Parent.Ability)

local config = GameConfig.Agents.Feint.Double

local Feint: Ability.Ability = {
	activate = function(player: Player): (boolean, string?)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local worn = DisguiseService.wornOutfit(player)
		if
			not (humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") and worn)
			or DownedService.isOut(player)
			or not MatchService.isInMatch()
		then
			return false, nil
		end
		local flat = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
		if flat.Magnitude < 1e-3 then
			return false, nil
		end
		local feet = root.Position - Vector3.new(0, humanoid.HipHeight + root.Size.Y / 2, 0)
		local speed = if DisguiseService.isExposed(player)
			then GameConfig.Speeds.Sprint
			else GameConfig.NPC.WalkSpeed[worn.Role]
		local decoy =
			NPCService.spawnDecoy(worn, feet + flat.Unit * config.Ahead, flat, speed, config.Seconds, config.StepStuds)
		return decoy ~= nil, nil
	end,
}

return Feint
