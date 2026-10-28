--!strict
-- Ticket 7B-glass-elevators: players and the glass elevators (ElevatorService owns the cabs, the stops and the doors).
--
--   * Call: hold Interact (kind "ElevatorCall", Doors.Elevators.CallSeconds, quiet) on a call panel (tag ElevatorCall, CallId
--     "<ShaftId>:<Level>") within CallStuds and in sight. The cab comes. Its doors open on arrival only if the caller's
--     clearance reaches the stop's Tier; otherwise they hack the door (SecurityService, kind "ElevatorHack") or walk in behind
--     someone who opened it.
--   * Ride: RequestElevatorFloor(level) from a player standing in a cab. The server carries nothing: the client's
--     PlatformController moves its own character with the cab floor, as for the gondola.
--   * The Sanctum elevator stays locked until the vault terminals are hacked (VaultService).
--   Riding changes no Cover state: a rider is as covered as when walking (SPEC_CHANGES, glass elevators).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local DownedService = require(script.Parent.DownedService)
local ElevatorService = require(script.Parent.ElevatorService)
local InteractService = require(script.Parent.InteractService)
local MatchService = require(script.Parent.MatchService)
local RemoteService = require(script.Parent.RemoteService)

local ElevatorRideService = {}

local config = GameConfig.Doors.Elevators
local panels: { [string]: { BasePart } } = {} -- a stop with two doors has two panels

local mapParams = RaycastParams.new()
mapParams.CollisionGroup = GameConfig.Rig.CollisionGroup
mapParams.RespectCanCollide = true

local function playing(player: Player): boolean
	return MatchService.isInMatch() and not DownedService.isOut(player)
end

local function beginCall(player: Player, callId: string): InteractService.Interaction?
	local list = panels[callId]
	local shaftId, level = string.match(callId, "^(%w+):(%a+)$")
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not (list and shaftId and level and root and root:IsA("BasePart")) or not playing(player) then
		return nil
	end
	local function inReach(): boolean
		for _, panel in list do
			local offset = panel:GetClosestPointOnSurface(root.Position) - root.Position
			if offset.Magnitude <= config.CallStuds then
				local hit = workspace:Raycast(
					root.Position,
					offset - offset.Unit * math.min(GameConfig.Assets.WallSlackStuds, offset.Magnitude),
					mapParams
				)
				if hit == nil or hit.Instance == panel or hit.Instance.Parent == panel.Parent then
					return true
				end
			end
		end
		return false
	end
	if not inReach() then
		return nil
	end
	if ElevatorService.isLocked(shaftId) then
		RemoteService.fireClient("Notification", player, "Out of service")
		return nil
	end
	return {
		label = "Call elevator",
		seconds = config.CallSeconds,
		stillValid = function()
			return playing(player) and inReach()
		end,
		complete = function()
			ElevatorService.callFor(shaftId, level, player)
		end,
	}
end

local function onFloor(player: Player, level: unknown)
	if type(level) ~= "string" or #level > 8 or not playing(player) then
		return
	end
	local shaftId = ElevatorService.cabHolding(player)
	if shaftId and ElevatorService.requestFloor(shaftId, level, player) then
		RemoteService.fireClient("Notification", player, `Elevator: level {level}`)
	end
end

function ElevatorRideService.Init() end

function ElevatorRideService.Start()
	for _, instance in CollectionService:GetTagged(Enums.Tag.ElevatorCall) do
		if instance:IsA("BasePart") then
			local id = `{instance:GetAttribute("ShaftId")}:{instance:GetAttribute("Level")}`
			instance:SetAttribute("CallId", id)
			panels[id] = panels[id] or {}
			table.insert(panels[id], instance)
		end
	end
	InteractService.register("ElevatorCall", beginCall)
	RemoteService.onRequest("RequestElevatorFloor", onFloor)
end

return ElevatorRideService
