--!strict
-- The glass elevators (relayout-1 built the shafts, cabs and doors; docs/MAP_PLAN_RELAYOUT.md).
--
-- A shaft has a cab (an ElevatorCab part, tagged with ShaftId and "Stops": "G:0,M:24,T:48") that waits at its lowest stop,
-- and a door (an ElevatorDoor blocker) at every stop. The server moves the cab, opens a stop's door while the cab is
-- there, and carries its riders. A cab is called to a level, loads for DwellSeconds, then takes its riders where they asked
-- to go, stopping at each of their stops in turn.
--
-- Riders are NPCs (Staff and above, by the clearance of the doors and the stops: NPCService) and players (ticket
-- 7B-glass-elevators). A locked shaft (the Sanctum elevator, locked until all three terminals are hacked) never moves.
--
-- Who a stop's doors open for (SPEC_CHANGES: Staff and above ride free; a Guest hacks the door or tailgates): when the cab
-- arrives at a stop its doors open only if that stop was authorized: an NPC called it, a player whose clearance reaches the
-- stop's door Tier called it or rides to it, or someone hacked the door with intel (hackOpen). The doors then stay open for
-- DwellSeconds, and anyone may walk in or out of them: that is the tailgating the game allows. Riders are carried by
-- PlatformController on the client. The cab part's State and Level attributes tell clients where it is.
--
--   ElevatorService.call(shaft, y)              ask for the cab at the stop at height y
--   ElevatorService.ready(shaft, y): boolean    the cab is at y with its doors open and room for another rider
--   ElevatorService.board(shaft, rider, toY): boolean
--   ElevatorService.position(shaft, rider): Vector3?   where a rider stands, nil once it has left the cab
--   ElevatorService.arrived(shaft, rider): boolean     the cab is at the rider's stop with its doors open (the rider is released)
--   ElevatorService.setLocked(shaftId, locked)  VaultService opens the Sanctum elevator (ticket 12a)
--   ElevatorService.leave(shaft, rider)         a rider that cannot ride on (downed) leaves the list
--   ElevatorService.callFor(shaft, level, player) -> boolean   a player pressed the call panel at a level ("G", "M", ...)
--   ElevatorService.requestFloor(shaft, level, player) -> boolean   a player in the cab asks for a level
--   ElevatorService.cabHolding(player) -> string?   the shaft whose cab the player stands in
--   ElevatorService.hackableDoor(doorId) -> (BasePart?, number?)   a shut stop door (DoorId "L1", ...) and its intel HackCost
--   ElevatorService.takesTierCard(doorId) -> boolean   a Tier 4 door: a Tier 4 keycard opens it
--   ElevatorService.hackOpen(doorId, seconds)   authorizes that stop and opens its doors for that long (calls the cab if needed)

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local DisguiseService = require(script.Parent.DisguiseService)

type Rider = { rider: any, toY: number, slot: number }

type Shaft = {
	id: string,
	model: Model,
	floor: BasePart,
	stops: { number }, -- stop heights, lowest first
	doors: { [number]: { BasePart } }, -- by stop height
	names: { [string]: number }, -- stop height by level name ("G", "M", ...)
	authorized: { [number]: number }, -- by stop height: until when (os.clock) the doors open when the cab arrives
	y: number, -- the cab floor now
	state: string, -- "Idle", "Moving" or "Open"
	target: number,
	openUntil: number,
	calls: { [number]: boolean },
	riders: { Rider },
	locked: boolean,
}

local ElevatorService = {}

local config = GameConfig.NPC.Elevator
local rideConfig = GameConfig.Doors.Elevators
local doorsById: { [string]: { part: BasePart, shaftId: string, y: number } } = {}
local shafts: { [string]: Shaft } = {}
local cabCapacity = GameConfig.NPC.Routes.CabCapacity

local function setDoors(shaft: Shaft, y: number, open: boolean)
	for _, door in shaft.doors[y] or {} do
		door.CanCollide = not open
		door:SetAttribute("Open", open)
	end
end

local function middle(shaft: Shaft): Vector3
	return Vector3.new(shaft.floor.Position.X, shaft.y, shaft.floor.Position.Z)
end

local function seatOf(shaft: Shaft, slot: number): Vector3
	local angle = slot * math.pi * 0.5 + math.pi * 0.25
	return middle(shaft) + Vector3.new(math.cos(angle), 0, math.sin(angle)) * config.RiderSpreadStuds
end

local function freeSlot(shaft: Shaft): number?
	for slot = 0, cabCapacity - 1 do
		local taken = false
		for _, entry in shaft.riders do
			taken = taken or entry.slot == slot
		end
		if not taken then
			return slot
		end
	end
	return nil
end

local function stopAt(shaft: Shaft, y: number): number?
	for _, stop in shaft.stops do
		if math.abs(stop - y) < 0.5 then
			return stop
		end
	end
	return nil
end

local function moveCab(shaft: Shaft, y: number)
	shaft.y = y
	shaft.model:PivotTo(shaft.model:GetPivot() + Vector3.new(0, y - shaft.floor.Position.Y + 0.2, 0))
end

-- The next stop the cab should go to: where a rider wants to get off, else where it was called (the nearest first).
local function nextTarget(shaft: Shaft): number?
	local best: number? = nil
	local bestDistance = math.huge
	for _, entry in shaft.riders do
		local distance = math.abs(entry.toY - shaft.y)
		if distance < bestDistance then
			best, bestDistance = entry.toY, distance
		end
	end
	if best then
		return best
	end
	for y in shaft.calls do
		local distance = math.abs(y - shaft.y)
		if distance < bestDistance then
			best, bestDistance = y, distance
		end
	end
	return best
end

local function nameAt(shaft: Shaft, y: number): string
	for name, height in shaft.names do
		if math.abs(height - y) < 0.5 then
			return name
		end
	end
	return ""
end

-- Tells clients where the cab is: the level it stands at, or "" while it moves.
local function publish(shaft: Shaft)
	shaft.floor:SetAttribute("State", shaft.state)
	shaft.floor:SetAttribute("Level", if shaft.state == "Moving" then "" else nameAt(shaft, shaft.y))
end

-- The clearance a stop's doors ask of a player (the doors at one stop share a Tier).
local function stopTier(shaft: Shaft, y: number): number
	local door = (shaft.doors[y] or {})[1]
	local tier = door and door:GetAttribute("Tier")
	return if type(tier) == "number" then tier else 0
end

local function isPlayer(rider: any): boolean
	return typeof(rider) == "Instance"
end

-- A rider on board who gets off here and may open this stop's doors: any NPC, or a player with the clearance.
local function ridersOpen(shaft: Shaft, y: number): boolean
	local tier = stopTier(shaft, y)
	for _, entry in shaft.riders do
		if entry.toY == y and (not isPlayer(entry.rider) or DisguiseService.getClearance(entry.rider) >= tier) then
			return true
		end
	end
	return false
end

local function arrive(shaft: Shaft, now: number)
	local y = shaft.y
	shaft.state = "Open"
	shaft.openUntil = now + config.DwellSeconds
	shaft.calls[y] = nil
	local allowed = (shaft.authorized[y] or 0) > now or ridersOpen(shaft, y)
	shaft.authorized[y] = nil
	-- A player who got off here is done riding; they ask again for another level.
	for index = #shaft.riders, 1, -1 do
		local entry = shaft.riders[index]
		if isPlayer(entry.rider) and math.abs(entry.toY - y) < 0.5 then
			table.remove(shaft.riders, index)
		end
	end
	setDoors(shaft, y, allowed)
	publish(shaft)
end

-- Is the player standing on this cab's floor, inside its walls?
local function inCab(shaft: Shaft, player: Player): boolean
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return false
	end
	local offset = shaft.floor.CFrame:PointToObjectSpace(root.Position)
	local half = shaft.floor.Size / 2
	local slack = rideConfig.CabSlackStuds
	return math.abs(offset.X) <= half.X + slack
		and math.abs(offset.Z) <= half.Z + slack
		and offset.Y >= -half.Y - slack
		and offset.Y <= rideConfig.CabHeightStuds
end

local function step(dt: number)
	local now = os.clock()
	for _, shaft in shafts do
		if shaft.locked then
			continue
		end
		-- A player who steps out of the cab (or leaves) is no longer a rider.
		for index = #shaft.riders, 1, -1 do
			local entry = shaft.riders[index]
			if isPlayer(entry.rider) and not inCab(shaft, entry.rider) then
				table.remove(shaft.riders, index)
			end
		end
		if shaft.state == "Moving" then
			local remaining = shaft.target - shaft.y
			local travel = config.SpeedStuds * dt
			if math.abs(remaining) <= travel then
				moveCab(shaft, shaft.target)
				arrive(shaft, now)
			else
				moveCab(shaft, shaft.y + math.sign(remaining) * travel)
			end
		elseif shaft.state == "Open" then
			if now >= shaft.openUntil then
				setDoors(shaft, shaft.y, false)
				shaft.state = "Idle"
				publish(shaft)
			end
		else
			local target = nextTarget(shaft)
			if target then
				shaft.target = target
				if math.abs(target - shaft.y) < 0.5 then
					arrive(shaft, now)
				else
					shaft.state = "Moving"
					publish(shaft)
				end
			end
		end
	end
end

function ElevatorService.Init()
	local byShaft: { [string]: { BasePart } } = {}
	for _, instance in CollectionService:GetTagged(Enums.Tag.ElevatorDoor) do
		if instance:IsA("BasePart") and instance:IsDescendantOf(workspace) then
			local id = instance:GetAttribute("ShaftId") :: string
			byShaft[id] = byShaft[id] or {}
			table.insert(byShaft[id], instance)
		end
	end
	for _, instance in CollectionService:GetTagged(Enums.Tag.ElevatorCab) do
		if
			instance:IsA("BasePart")
			and instance:IsDescendantOf(workspace)
			and instance.Parent
			and instance.Parent:IsA("Model")
		then
			local id = instance:GetAttribute("ShaftId") :: string
			local stops: { number } = {}
			local names: { [string]: number } = {}
			for _, text in string.split(instance:GetAttribute("Stops") :: string, ",") do
				local name, height = string.match(text, "^(%a+):(%-?[%d%.]+)$")
				table.insert(stops, tonumber(height) :: number)
				names[name :: string] = tonumber(height) :: number
			end
			table.sort(stops)
			local doors: { [number]: { BasePart } } = {}
			for _, door in byShaft[id] or {} do
				local level = door.Position.Y - (door.Size.Y / 2) -- the doorway's floor
				for _, stop in stops do
					if math.abs(level - stop) < 1 then
						doors[stop] = doors[stop] or {}
						table.insert(doors[stop], door)
					end
				end
			end
			shafts[id] = {
				id = id,
				model = instance.Parent,
				floor = instance,
				stops = stops,
				doors = doors,
				names = names,
				authorized = {},
				y = stops[1],
				state = "Idle",
				target = stops[1],
				openUntil = 0,
				calls = {},
				riders = {},
				locked = instance:GetAttribute("Locked") == true,
			}
			publish(shafts[id])
		end
	end
	-- Every stop door gets a DoorId so a hack can name it.
	local list: { { part: BasePart, shaftId: string, y: number } } = {}
	for id, shaft in shafts do
		for y, stopDoors in shaft.doors do
			for _, door in stopDoors do
				table.insert(list, { part = door, shaftId = id, y = y })
			end
		end
	end
	table.sort(list, function(a, b)
		local pa, pb = a.part.Position, b.part.Position
		if pa.Y ~= pb.Y then
			return pa.Y < pb.Y
		elseif pa.X ~= pb.X then
			return pa.X < pb.X
		end
		return pa.Z < pb.Z
	end)
	for index, entry in list do
		local id = `L{index}`
		entry.part:SetAttribute("DoorId", id)
		entry.part:SetAttribute("Open", false)
		doorsById[id] = entry
	end
end

function ElevatorService.Start()
	RunService.Heartbeat:Connect(step)
end

-- Ticket 12a: VaultService locks the Sanctum elevator at the start of a match and opens it when the terminals are hacked.
function ElevatorService.setLocked(shaftId: string, locked: boolean)
	local shaft = shafts[shaftId]
	if shaft then
		shaft.locked = locked
	end
end

-- True while a shaft is locked (the Sanctum elevator until its terminals are hacked): no cab comes.
function ElevatorService.isLocked(shaftId: string): boolean
	local shaft = shafts[shaftId]
	return shaft == nil or shaft.locked
end

function ElevatorService.call(shaftId: string, y: number)
	local shaft = shafts[shaftId]
	local stop = if shaft then stopAt(shaft, y) else nil
	if shaft and stop and not shaft.locked then
		shaft.calls[stop] = true
		shaft.authorized[stop] = os.clock() + rideConfig.NpcCallValidSeconds -- an NPC is Staff or above: the doors open
	end
end

function ElevatorService.ready(shaftId: string, y: number): boolean
	local shaft = shafts[shaftId]
	return shaft ~= nil
		and not shaft.locked
		and shaft.state == "Open"
		and math.abs(shaft.y - y) < 0.5
		and freeSlot(shaft) ~= nil
end

function ElevatorService.board(shaftId: string, rider: any, toY: number): boolean
	local shaft = shafts[shaftId]
	if not shaft or shaft.locked or shaft.state ~= "Open" then
		return false
	end
	local slot = freeSlot(shaft)
	if not slot then
		return false
	end
	table.insert(shaft.riders, { rider = rider, toY = toY, slot = slot })
	shaft.openUntil = math.max(shaft.openUntil, os.clock() + 1) -- a rider just stepped in: the doors wait a moment
	return true
end

function ElevatorService.position(shaftId: string, rider: any): Vector3?
	local shaft = shafts[shaftId]
	if shaft then
		for _, entry in shaft.riders do
			if entry.rider == rider then
				return seatOf(shaft, entry.slot)
			end
		end
	end
	return nil
end

-- Has the cab reached the rider's stop with its doors open? If so the rider is released (and told where the cab is).
function ElevatorService.arrived(shaftId: string, rider: any): boolean
	local shaft = shafts[shaftId]
	if not shaft or shaft.state ~= "Open" then
		return false
	end
	for index, entry in shaft.riders do
		if entry.rider == rider and math.abs(entry.toY - shaft.y) < 0.5 then
			table.remove(shaft.riders, index)
			return true
		end
	end
	return false
end

function ElevatorService.leave(shaftId: string, rider: any)
	local shaft = shafts[shaftId]
	if shaft then
		for index, entry in shaft.riders do
			if entry.rider == rider then
				table.remove(shaft.riders, index)
				return
			end
		end
	end
end

-- Opens the doors of the stop the cab is standing at, now, for this long.
local function openHere(shaft: Shaft, seconds: number)
	local now = os.clock()
	if shaft.state == "Idle" then
		arrive(shaft, now)
	elseif shaft.state == "Open" then
		setDoors(shaft, shaft.y, true)
	else
		return
	end
	shaft.openUntil = math.max(shaft.openUntil, now + seconds)
end

local function atStop(shaft: Shaft, y: number): boolean
	return shaft.state ~= "Moving" and math.abs(shaft.y - y) < 0.5
end

-- A player pressed the call panel at a level. The cab comes; its doors open for them only if their clearance reaches the
-- stop's Tier (otherwise they hack the door, or wait for someone to open it and walk in behind them).
function ElevatorService.callFor(shaftId: string, level: string, player: Player): boolean
	local shaft = shafts[shaftId]
	local y = if shaft then shaft.names[level] else nil
	if not (shaft and y) or shaft.locked then
		return false
	end
	if DisguiseService.getClearance(player) >= stopTier(shaft, y) then
		shaft.authorized[y] = os.clock() + rideConfig.HackValidSeconds
		if atStop(shaft, y) then
			openHere(shaft, config.DwellSeconds)
			return true
		end
	end
	if not atStop(shaft, y) then
		shaft.calls[y] = true
	end
	return true
end

-- A player in the cab asks for a level. They are carried there unless the cab is locked.
function ElevatorService.requestFloor(shaftId: string, level: string, player: Player): boolean
	local shaft = shafts[shaftId]
	local y = if shaft then shaft.names[level] else nil
	if not (shaft and y) or shaft.locked or not inCab(shaft, player) or atStop(shaft, y) then
		return false
	end
	for index = #shaft.riders, 1, -1 do
		if shaft.riders[index].rider == player then
			table.remove(shaft.riders, index)
		end
	end
	table.insert(shaft.riders, { rider = player, toY = y, slot = -1 })
	if shaft.state == "Open" then
		shaft.openUntil = math.min(shaft.openUntil, os.clock() + rideConfig.DepartSeconds)
	end
	return true
end

function ElevatorService.cabHolding(player: Player): string?
	for id, shaft in shafts do
		if inCab(shaft, player) then
			return id
		end
	end
	return nil
end

function ElevatorService.hackableDoor(doorId: string): (BasePart?, number?)
	local entry = doorsById[doorId]
	local shaft = if entry then shafts[entry.shaftId] else nil
	if entry and shaft and not shaft.locked and entry.part:GetAttribute("Open") ~= true then
		local cost = entry.part:GetAttribute("HackCost")
		return entry.part, if type(cost) == "number" then cost else nil
	end
	return nil, nil
end

function ElevatorService.takesTierCard(doorId: string): boolean
	local entry = doorsById[doorId]
	return entry ~= nil and entry.part:GetAttribute("Tier") == GameConfig.Doors.KeycardPrinter.Printer.DoorTier
end

function ElevatorService.hackOpen(doorId: string, seconds: number)
	local entry = doorsById[doorId]
	local shaft = if entry then shafts[entry.shaftId] else nil
	if not (entry and shaft) or shaft.locked then
		return
	end
	shaft.authorized[entry.y] = os.clock() + rideConfig.HackValidSeconds
	if atStop(shaft, entry.y) then
		openHere(shaft, seconds)
	else
		shaft.calls[entry.y] = true
	end
end

return ElevatorService
