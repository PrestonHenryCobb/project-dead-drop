--!strict
-- Ticket kits-24: the living, standing body of a player who may act (not downed, not eliminated), shared by the Talents.

local DownedService = require(script.Parent.Parent.Services.DownedService)

local Body = {}

function Body.of(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") and not DownedService.isOut(player) then
		return root
	end
	return nil
end

return Body
