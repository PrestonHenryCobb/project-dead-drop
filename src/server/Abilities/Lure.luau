--!strict
-- Talent Lure (ticket kits-24): a loud noise a set distance ahead of the player. Guards investigate it and the crowd looks (the same
-- call as the Noise Maker gadget, NPCService.noise). It does not break Cover: nothing says who made it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local MatchService = require(script.Parent.Parent.Services.MatchService)
local NPCService = require(script.Parent.Parent.Services.NPCService)
local Ability = require(script.Parent.Ability)
local Body = require(script.Parent.Body)

local config = GameConfig.Talents.Lure

local Lure: Ability.Ability = {
	activate = function(player: Player): (boolean, string?)
		local root = Body.of(player)
		if not root or not MatchService.isInMatch() then
			return false, nil
		end
		local flat = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
		if flat.Magnitude < 1e-3 then
			return false, nil
		end
		NPCService.noise(root.Position + flat.Unit * config.Ahead, config.RadiusStuds)
		return true, nil
	end,
}

return Lure
