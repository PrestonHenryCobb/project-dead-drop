--!strict
-- Scanner Pulse (docs/GADGETS_DRAFT.md, Recon): every enemy agent within RadiusStuds, disguised or not, glows for the user alone
-- (TargetGlow, to the user only) for GlowSeconds. There is no wave and no source to see; each agent it caught is told only that
-- they have been scanned. Discreet.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Types = require(Shared:WaitForChild("Types"))
local History = require(script.Parent.Parent.Combat.History)
local CoverService = require(script.Parent.Parent.Services.CoverService)
local DownedService = require(script.Parent.Parent.Services.DownedService)
local RemoteService = require(script.Parent.Parent.Services.RemoteService)
local TeamService = require(script.Parent.Parent.Services.TeamService)
local Gadget = require(script.Parent.Gadget)

local config = GameConfig.Gadgets.ScannerPulse

local ScannerPulse: Gadget.Gadget = {
	deploy = function(player: Player): (boolean, string?)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not (root and root:IsA("BasePart")) or DownedService.isOut(player) then
			return false, nil
		end
		CoverService.useDiscreetly(player, "ScannerPulse")
		local expiresAt = workspace:GetServerTimeNow() + config.GlowSeconds
		for _, target in History.targets do
			local other = target.player
			if
				other
				and other ~= player
				and not TeamService.areTeammates(player, other)
				and (target.rootPart.Position - root.Position).Magnitude <= config.RadiusStuds
			then
				local glow: Types.TargetGlowInfo = { TargetId = target.id, ExpiresAt = expiresAt }
				RemoteService.fireClient("TargetGlow", player, glow)
				RemoteService.fireClient("Notification", other, "You've been scanned")
			end
		end
		return true, nil
	end,
}

return ScannerPulse
