--!strict
-- Reticle's ability, Tracer Glass (spec 15.4): for Seconds, while she is scoped, every agent who is Exposed or more than half
-- suspicious inside a cone ahead of her glows for her alone (the existing TargetGlow, sent to her only). Her passive, Still
-- Water, is in CoverService (QuietScope) and CombatService (FallDamageMult).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Types = require(Shared:WaitForChild("Types"))
local History = require(script.Parent.Parent.Combat.History)
local CombatService = require(script.Parent.Parent.Services.CombatService)
local CoverService = require(script.Parent.Parent.Services.CoverService)
local DownedService = require(script.Parent.Parent.Services.DownedService)
local MatchService = require(script.Parent.Parent.Services.MatchService)
local RemoteService = require(script.Parent.Parent.Services.RemoteService)
local TeamService = require(script.Parent.Parent.Services.TeamService)
local Ability = require(script.Parent.Ability)

local config = GameConfig.Agents.Reticle.TracerGlass
local CONE_COS = math.cos(math.rad(config.ConeDegrees / 2))
local active: { [Player]: boolean } = {}

local function bodyOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") and not DownedService.isOut(player) then
		return root
	end
	return nil
end

-- Lights up the agents worth seeing, if she is scoped.
local function sweep(player: Player, root: BasePart)
	if not CombatService.isAiming(player) then
		return
	end
	local look = root.CFrame.LookVector
	for _, target in History.targets do
		local other = target.player
		if other and other ~= player and not TeamService.areTeammates(player, other) then
			local offset = target.rootPart.Position - root.Position
			if
				offset.Magnitude <= config.RangeStuds
				and offset.Magnitude > 0
				and offset.Unit:Dot(look) >= CONE_COS
				and (
					CoverService.isExposed(other)
					or CoverService.suspicionOf(other) > config.SuspicionOver * GameConfig.Cover.SuspicionMax
				)
			then
				local glow: Types.TargetGlowInfo =
					{ TargetId = target.id, ExpiresAt = workspace:GetServerTimeNow() + config.GlowSeconds }
				RemoteService.fireClient("TargetGlow", player, glow)
			end
		end
	end
end

local Reticle: Ability.Ability = {
	activate = function(player: Player): (boolean, string?)
		if not bodyOf(player) or active[player] or not MatchService.isInMatch() then
			return false, nil
		end
		active[player] = true
		local character = player.Character
		local endsAt = os.clock() + GameConfig.Agents.Reticle.TracerGlass.Seconds
		task.spawn(function()
			while os.clock() < endsAt and player.Character == character and MatchService.isInMatch() do
				local root = bodyOf(player)
				if not root then
					break
				end
				sweep(player, root)
				task.wait(config.CheckSeconds)
			end
			active[player] = nil
		end)
		return true, nil
	end,
}

return Reticle
