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
local AlarmService = require(script.Parent.AlarmService)
local CoverService = require(script.Parent.CoverService)
local DoorService = require(script.Parent.DoorService)
local DownedService = require(script.Parent.DownedService)
local GuardService = require(script.Parent.GuardService)
local InteractService = require(script.Parent.InteractService)
local MatchService = require(script.Parent.MatchService)
local ReachService = require(script.Parent.ReachService)

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
	CoverService.noteHacking(player)
	return {
		label = "Pick lock",
		seconds = settings.LockpickSeconds,
		stillValid = function()
			CoverService.noteHacking(player)
			return not DownedService.isOut(player) and inReach() and DoorService.keycardDoor(targetName) ~= nil
		end,
		complete = function()
			CoverService.expose(player, "Lockpick")
			DoorService.openKeycardDoor(targetName, settings.OpenSeconds)
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
end

return SecurityService
