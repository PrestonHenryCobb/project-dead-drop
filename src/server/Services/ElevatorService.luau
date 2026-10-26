--!strict
-- The glass elevators (relayout-1 built the shafts, cabs and doors; docs/MAP_PLAN_RELAYOUT.md).
--
-- A shaft has a cab (an ElevatorCab part, tagged with ShaftId and "Stops": "G:0,M:24,T:48") that waits at its lowest stop,
-- and a door (an ElevatorDoor blocker) at every stop. The server moves the cab, opens a stop's door while the cab is
-- there, and carries its riders. A cab is called to a level, loads for DwellSeconds, then takes its riders where they asked
-- to go, stopping at each of their stops in turn.
--
-- Riders so far are NPCs (Staff and above, by the clearance of the doors and the stops: NPCService); a locked shaft (the
-- Sanctum elevator, locked until all three terminals are hacked) never moves. Players cannot call a cab yet: that is the
-- 7B-glass-elevators ticket (call prompt, hack-or-tailgate rule, the cab carrying a player's character).
--
--   ElevatorService.call(shaft, y)              ask for the cab at the stop at height y
--   ElevatorService.ready(shaft, y): boolean    the cab is at y with its doors open and room for another rider
--   ElevatorService.board(shaft, rider, toY): boolean
--   ElevatorService.position(shaft, rider): Vector3?   where a rider stands, nil once it has left the cab
--   ElevatorService.arrived(shaft, rider): boolean     the cab is at the rider's stop with its doors open (the rider is released)
--   ElevatorService.leave(shaft, rider)         a rider that cannot ride on (downed) leaves the list

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))

type Rider = { rider: any, toY: number, slot: number }

type Shaft = {
	id: string,
	model: Model,
	floor: BasePart,
	stops: { number }, -- stop heights, lowest first
	doors: { [number]: { BasePart } }, -- by stop height
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

local function arrive(shaft: Shaft, now: number)
	shaft.state = "Open"
	shaft.openUntil = now + config.DwellSeconds
	shaft.calls[shaft.y] = nil
	setDoors(shaft, shaft.y, true)
end

local function step(dt: number)
	local now = os.clock()
	for _, shaft in shafts do
		if shaft.locked then
			continue
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
			end
		else
			local target = nextTarget(shaft)
			if target then
				shaft.target = target
				if math.abs(target - shaft.y) < 0.5 then
					arrive(shaft, now)
				else
					shaft.state = "Moving"
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
			for _, text in string.split(instance:GetAttribute("Stops") :: string, ",") do
				local _, height = string.match(text, "^(%a+):(%-?[%d%.]+)$")
				table.insert(stops, tonumber(height) :: number)
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
				y = stops[1],
				state = "Idle",
				target = stops[1],
				openUntil = 0,
				calls = {},
				riders = {},
				locked = instance:GetAttribute("Locked") == true,
			}
		end
	end
end

function ElevatorService.Start()
	RunService.Heartbeat:Connect(step)
end

function ElevatorService.call(shaftId: string, y: number)
	local shaft = shafts[shaftId]
	local stop = if shaft then stopAt(shaft, y) else nil
	if shaft and stop and not shaft.locked then
		shaft.calls[stop] = true
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

return ElevatorService
