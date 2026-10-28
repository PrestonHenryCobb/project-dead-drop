--!strict
-- Ticket 14: ties the security systems (spec 18) to the match and to each other.
--
--   * The alarm only counts while a match runs and starts each match Calm (AlarmService). The guards fight only while a
--     match runs (GuardService).
--   * Lockdown seals every keycard door (DoorService.seal) for LockdownDoorSealSeconds.
--   * Lockpicking: hold Interact (kind "Lockpick") on a keycard door for KeycardDoor.LockpickSeconds. It breaks Cover
--     (spec 7.2 #12) and opens the door for OpenSeconds.
--
-- Cameras, laser grids and fuse boxes are CameraService and LaserService.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local AbilityService = require(script.Parent.AbilityService)
local AlarmService = require(script.Parent.AlarmService)
local AssetService = require(script.Parent.AssetService)
local CoverService = require(script.Parent.CoverService)
local DoorService = require(script.Parent.DoorService)
local DownedService = require(script.Parent.DownedService)
local DroneService = require(script.Parent.DroneService)
local GuardService = require(script.Parent.GuardService)
local InteractService = require(script.Parent.InteractService)
local IntelService = require(script.Parent.IntelService)
local MatchService = require(script.Parent.MatchService)
local ReachService = require(script.Parent.ReachService)
local RemoteService = require(script.Parent.RemoteService)
local SupplyService = require(script.Parent.SupplyService)
local TeamService = require(script.Parent.TeamService)

local SecurityService = {}

local settings = GameConfig.Security.KeycardDoor

local function beginLockpick(player: Player, targetName: string): InteractService.Interaction?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local door = DoorService.keycardDoor(targetName)
	if not (door and root and root:IsA("BasePart")) or not MatchService.isInMatch() or DownedService.isOut(player) then
		return nil
	end
	local function inReach(): boolean
		local origin = ReachService.origin(player) or root.Position -- the Long Lens reaches from beside the door
		return (door.Position - origin).Magnitude <= settings.InteractStuds
	end
	if not inReach() then
		return nil
	end
	-- Ticket 18c: with a Security Keycard the door opens in KeycardSeconds and Cover is safe; otherwise it is picked.
	local keycard = SupplyService.keycardUses(player) > 0
	if not keycard then
		CoverService.noteHacking(player)
	end
	return {
		label = if keycard then "Use keycard" else "Pick lock",
		seconds = if keycard then GameConfig.Economy.Shop.KeycardSeconds else settings.LockpickSeconds,
		stillValid = function()
			if not keycard then
				CoverService.noteHacking(player)
			end
			return not DownedService.isOut(player) and inReach() and DoorService.keycardDoor(targetName) ~= nil
		end,
		complete = function()
			if not (keycard and SupplyService.useKeycard(player)) then
				CoverService.expose(player, "Lockpick")
			end
			DoorService.openDoor(targetName, settings.OpenSeconds)
		end,
	}
end

-- Ticket 18a (SPEC_CHANGES, tier doors): hold Interact (kind "DoorHack") on a shut tier door to hack it open, which costs the
-- team HackCost intel (taken when the hack is done): Staff 3, Security 6, Executive 8 and more for the special doors. Lattice's
-- Wired takes TierDoorDiscount off (never below 1). The door then stays open Doors.HackOpenSeconds. It is as suspicious as any
-- hack if witnessed; a drone or the Long Lens may do it from afar (ReachService).
local function beginDoorHack(player: Player, targetName: string): InteractService.Interaction?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local door, hackCost = DoorService.clearanceDoor(targetName)
	local teamId = TeamService.teamOf(player)
	if
		not (door and hackCost and teamId and root and root:IsA("BasePart"))
		or not MatchService.isInMatch()
		or DownedService.isOut(player)
	then
		return nil
	end
	local price =
		AssetService.discounted(player, math.max(1, hackCost - (AbilityService.rulesOf(player).TierDoorDiscount or 0))) -- Wired, then Deep Pockets
	local function inReach(): boolean
		local origin = ReachService.origin(player) or root.Position
		return (door.Position - origin).Magnitude <= GameConfig.Doors.HackStuds
	end
	if not inReach() then
		return nil
	end
	if IntelService.balance(teamId) < price then
		RemoteService.fireClient("Notification", player, `Needs {price} intel`)
		return nil
	end
	local flying = DroneService.position(player) ~= nil
	if not flying then
		CoverService.noteHacking(player)
	end
	return {
		label = "Hack door",
		seconds = GameConfig.Doors.HackSeconds,
		stillValid = function()
			if not flying then
				CoverService.noteHacking(player)
			end
			return not DownedService.isOut(player)
				and inReach()
				and DoorService.clearanceDoor(targetName) ~= nil
				and IntelService.balance(teamId) >= price
		end,
		complete = function()
			if IntelService.spend(teamId, price) then
				DoorService.openDoor(targetName, GameConfig.Doors.HackOpenSeconds)
			end
		end,
	}
end

function SecurityService.Init() end

function SecurityService.Start()
	MatchService.onPhaseChanged(function(phase)
		AlarmService.setArmed(MatchService.isInMatch())
		GuardService.setActive(MatchService.isInMatch())
		if phase == "Lobby" or phase == "Insertion" then
			AlarmService.reset()
		end
	end)
	AlarmService.onChange(function(level)
		if level >= Enums.AlarmLevel.Lockdown then
			DoorService.seal(GameConfig.Security.Alarm.LockdownDoorSealSeconds)
		end
	end)
	InteractService.register("Lockpick", beginLockpick)
	InteractService.register("DoorHack", beginDoorHack)
end

return SecurityService
