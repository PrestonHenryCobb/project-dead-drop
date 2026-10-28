--!strict
-- Med Injector (docs/GADGETS_DRAFT.md, Support): heals Heal HP over Seconds, self only, and stops if the user takes damage.
-- Quiet in a public zone, Discreet elsewhere (a Security NPC or camera that sees it breaks Cover).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local CombatService = require(script.Parent.Parent.Services.CombatService)
local CoverService = require(script.Parent.Parent.Services.CoverService)
local DownedService = require(script.Parent.Parent.Services.DownedService)
local ZoneService = require(script.Parent.Parent.Services.ZoneService)
local Gadget = require(script.Parent.Gadget)

local config = GameConfig.Gadgets.MedInjector
local using: { [Player]: boolean } = {}

local MedInjector: Gadget.Gadget = {
	deploy = function(player: Player): (boolean, string?)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not (root and root:IsA("BasePart")) or using[player] or DownedService.isOut(player) then
			return false, nil
		end
		if not CombatService.isHurt(player) then
			return false, "Already at full health"
		end
		if ZoneService.tierAt(root.Position) >= 1 then
			CoverService.useDiscreetly(player, "MedInjector")
		end
		using[player] = true
		task.spawn(function()
			local ticks = math.floor(config.Seconds * config.HealHz)
			local startedAt = os.clock()
			for _ = 1, ticks do
				task.wait(1 / config.HealHz)
				-- Damage since the injection began ends it; so does leaving the match or being downed.
				if
					player.Character ~= character
					or DownedService.isOut(player)
					or CombatService.secondsSinceDamaged(player) < os.clock() - startedAt
				then
					break
				end
				CombatService.heal(player, config.Heal / ticks)
			end
			using[player] = nil
		end)
		return true, nil
	end,
}

return MedInjector
