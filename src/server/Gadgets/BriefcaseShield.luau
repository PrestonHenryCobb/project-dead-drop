--!strict
-- Briefcase Shield (docs/GADGETS_DRAFT.md, Support): the user snaps open an armoured briefcase and holds it in front of them
-- (Combat/Shields, 80 HP, covering head and chest) for up to Seconds. They walk at SpeedMult, cannot sprint or shoot, and it breaks
-- Cover. It ends when it is shot to pieces, the time is up, the user puts it away (the aim button) or is downed. Parapet's Riot
-- Wall is far stronger, and the user's own shots are not what it is for: it is for crossing a gap or reaching a downed teammate.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local Shields = require(script.Parent.Parent.Combat.Shields)
local CombatService = require(script.Parent.Parent.Services.CombatService)
local CoverService = require(script.Parent.Parent.Services.CoverService)
local DisguiseService = require(script.Parent.Parent.Services.DisguiseService)
local DownedService = require(script.Parent.Parent.Services.DownedService)
local MatchService = require(script.Parent.Parent.Services.MatchService)
local Gadget = require(script.Parent.Gadget)

local config = GameConfig.Gadgets.BriefcaseShield
local held: { [Player]: Shields.Shield } = {}

local function aliveBody(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") and not DownedService.isOut(player) then
		return root
	end
	return nil
end

-- The briefcase goes away and the user can walk, sprint and shoot again.
local function lower(player: Player, shield: Shields.Shield)
	Shields.destroy(shield)
	if held[player] == shield then
		held[player] = nil
		DisguiseService.setSprintBlocked(player, false)
		DisguiseService.applySlow(player, 1, config.CheckSeconds) -- ends the slow at once
		CombatService.setFrozen(player, false)
	end
end

local BriefcaseShield: Gadget.Gadget = {
	deploy = function(player: Player): (boolean, string?)
		local root = aliveBody(player)
		if not root or held[player] or not MatchService.isInMatch() then
			return false, nil
		end
		CoverService.expose(player, "BriefcaseShield")
		local shield = Shields.create(player, root, config)
		held[player] = shield
		DisguiseService.setSprintBlocked(player, true)
		DisguiseService.applySlow(player, config.SpeedMult, config.Seconds)
		CombatService.setFrozen(player, true) -- no shooting from behind it
		local character = player.Character
		local endsAt = os.clock() + config.Seconds
		task.spawn(function()
			while
				Shields.isUp(shield)
				and os.clock() < endsAt
				and player.Character == character
				and aliveBody(player)
			do
				task.wait(config.CheckSeconds)
			end
			lower(player, shield)
		end)
		return true, nil
	end,

	-- The aim button puts the briefcase away.
	alternate = function(player: Player)
		local shield = held[player]
		if shield then
			lower(player, shield)
		end
	end,
}

return BriefcaseShield
