--!strict
-- Keycard Clone (docs/GADGETS_DRAFT.md, Infiltration): opens the nearest closed keycard door within ReachStuds that the user can
-- see, for the door's usual open time, and does not break Cover unless a Security NPC or camera sees it (Discreet). Opening a tier
-- door with no intel cost joins it when tier doors can be hacked (Step 18).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local CoverService = require(script.Parent.Parent.Services.CoverService)
local DoorService = require(script.Parent.Parent.Services.DoorService)
local DownedService = require(script.Parent.Parent.Services.DownedService)
local Gadget = require(script.Parent.Gadget)

local config = GameConfig.Gadgets.KeycardClone

-- Rays in the character group meet only the map.
local sight = RaycastParams.new()
sight.CollisionGroup = GameConfig.Rig.CollisionGroup
sight.RespectCanCollide = true

local KeycardClone: Gadget.Gadget = {
	deploy = function(player: Player): (boolean, string?)
		local character = player.Character
		local head = character and character:FindFirstChild("Head")
		if not (head and head:IsA("BasePart")) or DownedService.isOut(player) then
			return false, nil
		end
		local best: string? = nil
		local bestDistance = config.ReachStuds
		for _, instance in CollectionService:GetTagged(Enums.Tag.KeycardDoor) do
			local id = instance:GetAttribute("SecurityId")
			if instance:IsA("BasePart") and type(id) == "string" and DoorService.keycardDoor(id) then
				local offset = instance.Position - head.Position
				if offset.Magnitude <= bestDistance then
					local hit = workspace:Raycast(head.Position, offset, sight)
					if hit == nil or hit.Instance == instance or hit.Instance.Parent == instance.Parent then
						best, bestDistance = id, offset.Magnitude
					end
				end
			end
		end
		if not best then
			return false, "No keycard door in reach"
		end
		DoorService.openKeycardDoor(best, GameConfig.Security.KeycardDoor.OpenSeconds)
		CoverService.useDiscreetly(player, "KeycardClone")
		return true, nil
	end,
}

return KeycardClone
