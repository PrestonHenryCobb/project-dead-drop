--!strict
-- Long Lens (docs/GADGETS_DRAFT.md, Infiltration): hack an Intel station, a camera or a keycard door the user is aiming at, in
-- sight and up to RangeStuds away, taking TimeMult times as long. The hack is the ordinary one (its own checks and clearance
-- rules apply, and it is as suspicious if witnessed) but is measured from a point beside the target while the user keeps it in
-- sight (ReachService). A charge is spent only when the hack begins.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local DownedService = require(script.Parent.Parent.Services.DownedService)
local InteractService = require(script.Parent.Parent.Services.InteractService)
local ReachService = require(script.Parent.Parent.Services.ReachService)
local Gadget = require(script.Parent.Gadget)

local config = GameConfig.Gadgets.LongLens
local MIN_DOT = math.cos(math.rad(config.AimDegrees))

-- What can be hacked from afar: the tag, the hold kind, and the attribute that names the target to the hold.
local TARGETS = {
	{ tag = Enums.Tag.IntelSpawn, kind = "Intel", attribute = "IntelId" },
	{ tag = Enums.Tag.SecurityCamera, kind = "Camera", attribute = "SecurityId" },
	{ tag = Enums.Tag.KeycardDoor, kind = "Lockpick", attribute = "SecurityId" },
	{ tag = Enums.Tag.ClearanceDoor, kind = "DoorHack", attribute = "SecurityId" }, -- a tier door, for its intel cost (18a)
}

-- Rays in the character group meet only the map.
local sight = RaycastParams.new()
sight.CollisionGroup = GameConfig.Rig.CollisionGroup
sight.RespectCanCollide = true

local LongLens: Gadget.Gadget = {
	deploy = function(player: Player, _: { [string]: any }, aim: Vector3?): (boolean, string?)
		local character = player.Character
		local head = character and character:FindFirstChild("Head")
		if not (head and head:IsA("BasePart") and aim) or DownedService.isOut(player) then
			return false, nil
		end
		local best: BasePart? = nil
		local bestKind, bestId = "", ""
		local bestDot = MIN_DOT
		for _, target in TARGETS do
			for _, instance in CollectionService:GetTagged(target.tag) do
				local id = instance:GetAttribute(target.attribute)
				if instance:IsA("BasePart") and type(id) == "string" then
					local offset = instance.Position - head.Position
					local distance = offset.Magnitude
					if distance > 1e-3 and distance <= config.RangeStuds then
						local dot = offset.Unit:Dot(aim)
						if dot >= bestDot then
							local hit = workspace:Raycast(head.Position, offset, sight)
							if hit == nil or hit.Instance == instance or hit.Instance.Parent == instance.Parent then
								best, bestKind, bestId, bestDot = instance, target.kind, id, dot
							end
						end
					end
				end
			end
		end
		if not best then
			return false, "Nothing to hack in sight"
		end
		ReachService.setLens(player, best)
		if InteractService.start(player, bestKind, bestId) then
			return true, nil
		end
		ReachService.clearLens(player)
		return false, "You can't hack that"
	end,
}

return LongLens
