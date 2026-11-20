--!strict
-- Talent Focus (ticket kits-24): for a few seconds the player's hits hurt more (CombatService reads the DamageDealt effect).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local Effects = require(script.Parent.Parent.Combat.Effects)
local MatchService = require(script.Parent.Parent.Services.MatchService)
local Ability = require(script.Parent.Ability)
local Body = require(script.Parent.Body)

local config = GameConfig.Talents.Focus

local Focus: Ability.Ability = {
	activate = function(player: Player): (boolean, string?)
		if not Body.of(player) or not MatchService.isInMatch() then
			return false, nil
		end
		Effects.set(player, "DamageDealt", config.DamageMult, config.Seconds)
		return true, nil
	end,
}

return Focus
