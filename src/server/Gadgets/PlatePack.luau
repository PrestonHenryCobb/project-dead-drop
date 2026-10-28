--!strict
-- Plate Pack (docs/GADGETS_DRAFT.md, Support): puts one armour plate on the user, or on the nearest teammate within ReachStuds
-- who has room for one, after Seconds (halved for Parapet's Plated); the user cannot shoot meanwhile. No HP. Quiet in a public
-- zone, Discreet elsewhere.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local CombatService = require(script.Parent.Parent.Services.CombatService)
local CoverService = require(script.Parent.Parent.Services.CoverService)
local DownedService = require(script.Parent.Parent.Services.DownedService)
local TeamService = require(script.Parent.Parent.Services.TeamService)
local ZoneService = require(script.Parent.Parent.Services.ZoneService)
local Gadget = require(script.Parent.Gadget)

local config = GameConfig.Gadgets.PlatePack
local using: { [Player]: boolean } = {}

local function rootOf(player: Player): BasePart?
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") and not DownedService.isOut(player) then root else nil
end

-- The nearest teammate in reach who can take a plate, else the user if they can.
local function pickTarget(user: Player, userRoot: BasePart): Player?
	local best: Player? = nil
	local bestDistance = config.ReachStuds
	for _, other in Players:GetPlayers() do
		local root = if other ~= user and TeamService.areTeammates(user, other) then rootOf(other) else nil
		if root and CombatService.canTakePlate(other) then
			local distance = (root.Position - userRoot.Position).Magnitude
			if distance <= bestDistance then
				best, bestDistance = other, distance
			end
		end
	end
	if best then
		return best
	end
	return if CombatService.canTakePlate(user) then user else nil
end

local PlatePack: Gadget.Gadget = {
	deploy = function(player: Player, rules: { [string]: any }): (boolean, string?)
		local root = rootOf(player)
		if not root or using[player] then
			return false, nil
		end
		local target = pickTarget(player, root)
		if not target then
			return false, "Nobody needs a plate"
		end
		if ZoneService.tierAt(root.Position) >= 1 then
			CoverService.useDiscreetly(player, "PlatePack")
		end
		using[player] = true
		CombatService.setFrozen(player, true) -- no shooting while the plate goes on
		task.spawn(function()
			task.wait(config.Seconds * (rules.PlateMult or 1))
			CombatService.setFrozen(player, false)
			using[player] = nil
			local userRoot, targetRoot = rootOf(player), rootOf(target)
			if
				userRoot
				and targetRoot
				and (targetRoot.Position - userRoot.Position).Magnitude <= config.ReachStuds + config.SlackStuds
			then
				CombatService.addPlate(target)
			end
		end)
		return true, nil
	end,
}

return PlatePack
