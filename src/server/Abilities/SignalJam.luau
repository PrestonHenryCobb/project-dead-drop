--!strict
-- Talent SignalJam (ticket kits-24): every working camera within a radius of the player goes dark for a few seconds
-- (CameraService.jamAt, the same call as the Jammer gadget).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local CameraService = require(script.Parent.Parent.Services.CameraService)
local MatchService = require(script.Parent.Parent.Services.MatchService)
local Ability = require(script.Parent.Ability)
local Body = require(script.Parent.Body)

local config = GameConfig.Talents.SignalJam

local SignalJam: Ability.Ability = {
	activate = function(player: Player): (boolean, string?)
		local root = Body.of(player)
		if not root or not MatchService.isInMatch() then
			return false, nil
		end
		CameraService.jamAt(root.Position, config.RadiusStuds, config.Seconds)
		return true, nil
	end,
}

return SignalJam
