--!strict
-- Talent ColdRead (ticket kits-24): for a few seconds scans take less time and reach further (DisguiseService reads ScanTime and ScanRange).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local Effects = require(script.Parent.Parent.Combat.Effects)
local MatchService = require(script.Parent.Parent.Services.MatchService)
local Ability = require(script.Parent.Ability)
local Body = require(script.Parent.Body)

local config = GameConfig.Talents.ColdRead

local ColdRead: Ability.Ability = {
	activate = function(player: Player): (boolean, string?)
		if not Body.of(player) or not MatchService.isInMatch() then
			return false, nil
		end
		Effects.set(player, "ScanTime", config.ScanTimeMult, config.Seconds)
		Effects.set(player, "ScanRange", config.ScanRangeMult, config.Seconds)
		return true, nil
	end,
}

return ColdRead
