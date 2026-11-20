--!strict
-- Talent Adrenaline (ticket kits-24): heals the player at once and shakes off any slowing effect. Not while downed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local CombatService = require(script.Parent.Parent.Services.CombatService)
local DisguiseService = require(script.Parent.Parent.Services.DisguiseService)
local MatchService = require(script.Parent.Parent.Services.MatchService)
local Ability = require(script.Parent.Ability)
local Body = require(script.Parent.Body)

local config = GameConfig.Talents.Adrenaline

local Adrenaline: Ability.Ability = {
	activate = function(player: Player): (boolean, string?)
		if not Body.of(player) or not MatchService.isInMatch() then
			return false, nil
		end
		if not CombatService.isHurt(player) then
			return false, "Already at full health"
		end
		CombatService.heal(player, config.Heal)
		DisguiseService.applySlow(player, 1, 0) -- a slow of no length: the walk speed goes back to normal
		return true, nil
	end,
}

return Adrenaline
