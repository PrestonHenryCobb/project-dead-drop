--!strict
-- Talent Screen (ticket kits-24): a smoke cloud set just ahead of the player for a few seconds. The server's sight checks treat it like
-- the Smoke SMG's clouds (Combat/Smoke); shots, sound and cameras go through it. Everyone sees the cloud; nothing else is revealed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Types = require(Shared:WaitForChild("Types"))
local Smoke = require(script.Parent.Parent.Combat.Smoke)
local Spot = require(script.Parent.Parent.Gadgets.Spot)
local MatchService = require(script.Parent.Parent.Services.MatchService)
local RemoteService = require(script.Parent.Parent.Services.RemoteService)
local Ability = require(script.Parent.Ability)
local Body = require(script.Parent.Body)

local config = GameConfig.Talents.Screen
local probe = GameConfig.Agents.Suture.MendField.FloorProbe

local Screen: Ability.Ability = {
	activate = function(player: Player): (boolean, string?)
		local root = Body.of(player)
		if not root or not MatchService.isInMatch() then
			return false, nil
		end
		local at = Spot.ahead(root, config.Ahead, probe.Up, probe.Down)
		local cloud: Types.SmokeCloudInfo = {
			Position = at,
			Radius = config.Radius,
			ExpiresAt = workspace:GetServerTimeNow() + config.Seconds,
		}
		Smoke.add(cloud.Position, cloud.Radius, cloud.ExpiresAt)
		RemoteService.fireAllClients("SmokeCloud", cloud)
		return true, nil
	end,
}

return Screen
