--!strict
-- Talent MarkedMan (ticket kits-24): the nearest Exposed enemy agent the player can see, within a range, glows for the player alone
-- (the existing TargetGlow, through walls) for a few seconds. Only an Exposed agent is marked, so it shows nothing a clear view would not.
-- The glow names the body by its model name, never the internal player id.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Types = require(Shared:WaitForChild("Types"))
local History = require(script.Parent.Parent.Combat.History)
local CoverService = require(script.Parent.Parent.Services.CoverService)
local MatchService = require(script.Parent.Parent.Services.MatchService)
local RemoteService = require(script.Parent.Parent.Services.RemoteService)
local TeamService = require(script.Parent.Parent.Services.TeamService)
local Ability = require(script.Parent.Ability)
local Body = require(script.Parent.Body)

local config = GameConfig.Talents.MarkedMan

-- Rays in the character group skip characters and meet only the map (and what blocks shots).
local sight = RaycastParams.new()
sight.CollisionGroup = GameConfig.Rig.CollisionGroup
sight.RespectCanCollide = true

local MarkedMan: Ability.Ability = {
	activate = function(player: Player): (boolean, string?)
		local root = Body.of(player)
		if not root or not MatchService.isInMatch() then
			return false, nil
		end
		local best: Model? = nil
		local bestDistance = config.RangeStuds
		for _, target in History.targets do
			local other = target.player
			local model = target.rootPart.Parent
			if
				other
				and other ~= player
				and model
				and model:IsA("Model")
				and not TeamService.areTeammates(player, other)
				and CoverService.isExposed(other)
			then
				local offset = target.rootPart.Position - root.Position
				if offset.Magnitude <= bestDistance and workspace:Raycast(root.Position, offset, sight) == nil then
					best, bestDistance = model, offset.Magnitude
				end
			end
		end
		if not best then
			return false, "No Exposed agent in sight"
		end
		local glow: Types.TargetGlowInfo = {
			TargetId = best.Name,
			ExpiresAt = workspace:GetServerTimeNow() + config.Seconds,
			ThroughWalls = true,
		}
		RemoteService.fireClient("TargetGlow", player, glow)
		return true, nil
	end,
}

return MarkedMan
