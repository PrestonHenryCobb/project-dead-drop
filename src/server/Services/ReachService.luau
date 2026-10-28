--!strict
-- Ticket 17c: where a player's hacks reach from. Normally from their body; Lattice's drone (DroneService) reaches from where it
-- hovers, and the Long Lens gadget reaches from a point beside whatever the player aimed at, up to LongLens.RangeStuds away, for
-- as long as the player keeps it in sight and keeps holding. The services that time hacks (IntelService, CameraService,
-- SecurityService's lockpick) ask here for the point to measure from, and fall back to the body when there is none.
--
--   ReachService.origin(player) -> Vector3?      the drone's position, or the lens point, or nil
--   ReachService.setLens(player, part)           the player aimed the Long Lens at this part (called just before the hold starts)
--   ReachService.clearLens(player)
--   ReachService.lensActive(player) -> boolean   is the player hacking through the lens right now (it takes longer)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local DroneService = require(script.Parent.DroneService)
local InteractService = require(script.Parent.InteractService)

type Lens = { part: BasePart, since: number }

local ReachService = {}

local config = GameConfig.Gadgets.LongLens
local lenses: { [Player]: Lens } = {}

-- Rays in the character group meet only the map.
local sight = RaycastParams.new()
sight.CollisionGroup = GameConfig.Rig.CollisionGroup
sight.RespectCanCollide = true

function ReachService.setLens(player: Player, part: BasePart)
	lenses[player] = { part = part, since = os.clock() }
end

function ReachService.clearLens(player: Player)
	lenses[player] = nil
end

-- The lens ends with the hold it was aimed for.
local function liveLens(player: Player): Lens?
	local lens = lenses[player]
	if lens and not InteractService.isBusy(player) and os.clock() - lens.since > config.GraceSeconds then
		lenses[player] = nil
		return nil
	end
	return lens
end

function ReachService.lensActive(player: Player): boolean
	return liveLens(player) ~= nil
end

local function lensPoint(player: Player): Vector3?
	local lens = liveLens(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not lens or not lens.part.Parent or not (root and root:IsA("BasePart")) then
		return nil
	end
	local offset = root.Position - lens.part.Position
	if offset.Magnitude > config.RangeStuds or offset.Magnitude < 1e-3 then
		return nil
	end
	local hit = workspace:Raycast(root.Position, -offset, sight)
	if hit and hit.Instance ~= lens.part and hit.Instance.Parent ~= lens.part.Parent then
		return nil -- something is in the way: the lens does not see through it
	end
	return lens.part.Position + offset.Unit * math.min(config.NearStuds, offset.Magnitude)
end

function ReachService.origin(player: Player): Vector3?
	return DroneService.position(player) or lensPoint(player)
end

function ReachService.Init() end

function ReachService.Start()
	Players.PlayerRemoving:Connect(function(player)
		lenses[player] = nil
	end)
end

return ReachService
