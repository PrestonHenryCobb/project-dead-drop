--!strict
-- Parapet's ability, Riot Wall (spec 15.2): a shield carried in front of him that stops other people's shots (his own pass
-- through) until it has taken HP damage or Seconds have passed. Putting it up breaks Cover: a glowing wall is no disguise.
-- The shield itself, and what it stops, is Combat/Shields.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local Shields = require(script.Parent.Parent.Combat.Shields)
local CoverService = require(script.Parent.Parent.Services.CoverService)
local DownedService = require(script.Parent.Parent.Services.DownedService)
local MatchService = require(script.Parent.Parent.Services.MatchService)
local Ability = require(script.Parent.Ability)

local config = GameConfig.Agents.Parapet.RiotWall
local up: { [Player]: Shields.Shield } = {}

local function stillCarried(player: Player): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0 and not DownedService.isOut(player) and MatchService.isInMatch()
end

local Parapet: Ability.Ability = {
	activate = function(player: Player): (boolean, string?)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not (root and root:IsA("BasePart")) or not stillCarried(player) then
			return false, nil
		end
		local old = up[player]
		if old then
			Shields.destroy(old)
		end
		CoverService.expose(player, "RiotWall")
		local shield = Shields.create(player, root)
		up[player] = shield
		local endsAt = os.clock() + config.Seconds
		task.spawn(function()
			while
				Shields.isUp(shield)
				and os.clock() < endsAt
				and player.Character == character
				and stillCarried(player)
			do
				task.wait(config.CheckSeconds)
			end
			Shields.destroy(shield)
			if up[player] == shield then
				up[player] = nil
			end
		end)
		return true, nil
	end,
}

return Parapet
