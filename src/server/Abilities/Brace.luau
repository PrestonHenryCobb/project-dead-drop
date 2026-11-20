--!strict
-- Talent Brace (ticket kits-24): for a few seconds the player takes less damage (CombatService reads the DamageTaken effect).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local Effects = require(script.Parent.Parent.Combat.Effects)
local MatchService = require(script.Parent.Parent.Services.MatchService)
local Ability = require(script.Parent.Ability)
local Body = require(script.Parent.Body)

local config = GameConfig.Talents.Brace

local Brace: Ability.Ability = {
	activate = function(player: Player): (boolean, string?)
		if not Body.of(player) or not MatchService.isInMatch() then
			return false, nil
		end
		Effects.set(player, "DamageTaken", config.DamageTakenMult, config.Seconds)
		return true, nil
	end,
}

return Brace
