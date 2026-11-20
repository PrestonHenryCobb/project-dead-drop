--!strict
-- Talent TwinDouble (ticket kits-24): two Doubles (Feint's first Talent, Abilities/Feint) of the player's current look walk off at an
-- angle either side of their aim, with the Double's own numbers. Each is an ordinary NPC rig that pops when hit.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local DisguiseService = require(script.Parent.Parent.Services.DisguiseService)
local MatchService = require(script.Parent.Parent.Services.MatchService)
local NPCService = require(script.Parent.Parent.Services.NPCService)
local Ability = require(script.Parent.Ability)
local Body = require(script.Parent.Body)

local double = GameConfig.Agents.Feint.Double
local config = GameConfig.Talents.TwinDouble

local TwinDouble: Ability.Ability = {
	activate = function(player: Player): (boolean, string?)
		local root = Body.of(player)
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		local worn = DisguiseService.wornOutfit(player)
		if not (root and humanoid and worn) or not MatchService.isInMatch() then
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
		local angle = math.rad(config.AngleDegrees)
		local made = 0
		for _, turn in { angle, -angle } do
			local direction = CFrame.Angles(0, turn, 0):VectorToWorldSpace(flat.Unit)
			local decoy = NPCService.spawnDecoy(
				worn,
				feet + direction * double.Ahead,
				direction,
				speed,
				double.Seconds,
				double.StepStuds
			)
			if decoy then
				made += 1
			end
		end
		return made > 0, nil
	end,
}

return TwinDouble
