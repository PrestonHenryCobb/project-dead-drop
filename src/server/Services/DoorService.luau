--!strict
-- Doors that open for NPCs (spec 5.2) and for clearance (STEP 7B). A door closes DoorCloseDelay seconds after the last
-- body was near it, so someone slipping through behind an opener is the tailgating the game allows.
--
-- The tagged part is the doorway's invisible blocker: solid while the door is shut (it stops bodies and sight), and not
-- while it is open. Its Open attribute tells clients to swing the visible leaves (DoorController); the server never
-- moves them (map re-plan stage 3).
--
--   * Keycard doors (spec 18.3) open for any NPC. A player picks the lock (SecurityService: hold Interact, which breaks
--     Cover); the door then stays open for KeycardDoor.OpenSeconds and closes. Keycards, the
--     Keycard Clone and Ferro's passive arrive with the economy, gadgets and agents (Steps 16 to 18). In Lockdown every
--     keycard door seals (DoorService.seal): shut for everyone, nothing opens it.
--   * Clearance doors open only for a body whose clearance tier is at least the door's Tier attribute: an NPC of that
--     role, or a player wearing a disguise of that tier, from either side. An Exposed player has no clearance.
--   * Free exit (R3-doors, owner decision 2026-10-25): a player on the inside of an ordinary clearance door may always
--     leave, clearance or not, so nobody is trapped after losing it. Entry from outside still needs clearance. Doors
--     into a vault wing are exempt. The inside is the side with the higher zone tier, read once from the zone volumes
--     on each side of the doorway (server map data, never a client claim); a doorway with the same tier on both sides
--     has no inside and no free exit.
--
--   DoorService.seal(seconds)      Lockdown: keycard doors shut and refuse to open for this long
--   DoorService.keycardDoor(id) -> BasePart?   the keycard door with that SecurityId, if it is shut and not sealed
--   DoorService.clearanceDoor(id) -> (BasePart?, number?)   a shut clearance door (SecurityId "D1", ...) and its intel HackCost
--   DoorService.shutDoor(id) -> BasePart?   any shut keycard or clearance door (a keycard door is not shut while sealed)
--   DoorService.openDoor(id, seconds)   opens a keycard or clearance door by its SecurityId and keeps it open that long
--   DoorService.holdNear(position, clearance, opensKeycardDoors)
--     keeps open the doors close to the position that this clearance opens (NPCs open keycard doors too, players do not)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local DisguiseService = require(script.Parent.DisguiseService)
local ZoneService = require(script.Parent.ZoneService)

type Door = {
	part: BasePart,
	tier: number?, -- the clearance needed, for a clearance door
	open: boolean,
	lastHeld: number,
	inside: Vector3?, -- flat unit direction from the doorway into the higher-tier side, if the zones say which
	freeExit: boolean, -- an ordinary clearance door: anyone on its inside may leave
	keycard: boolean, -- a keycard door (lockpicks, Lockdown seals)
	openUntil: number, -- os.clock(): a lockpicked door stays open until then
}

local DoorService = {}

local config = GameConfig.NPC
local doors: { Door } = {}
local byId: { [string]: Door } = {}
local sealedUntil = 0
local nextKeycardId = 0
local nextTierId = 0

local function setOpen(door: Door, open: boolean)
	door.open = open
	door.part.CanCollide = not open
	door.part:SetAttribute("Open", open)
end

local function addDoor(instance: Instance, tagName: string)
	if not instance:IsA("BasePart") then
		return
	end
	local keycard = tagName == Enums.Tag.KeycardDoor
	local door: Door = {
		part = instance,
		tier = if tagName == Enums.Tag.ClearanceDoor then instance:GetAttribute("Tier") else nil,
		open = false,
		lastHeld = 0,
		inside = nil,
		freeExit = false,
		keycard = keycard,
		openUntil = 0,
	}
	table.insert(doors, door)
	if keycard then
		nextKeycardId += 1
		local id = `K{nextKeycardId}`
		instance:SetAttribute("SecurityId", id)
		byId[id] = door
	elseif door.tier then
		nextTierId += 1
		local id = `D{nextTierId}` -- ticket 18a: a clearance door can be hacked open with intel
		instance:SetAttribute("SecurityId", id)
		byId[id] = door
	end
	instance:SetAttribute("Open", false)
	if config.Door.OpenForNpcs then
		-- Pathfinding treats the door as open ground, so NPC routes can go through it.
		local modifier = Instance.new("PathfindingModifier")
		modifier.PassThrough = true
		modifier.Parent = instance
	end
end

function DoorService.Init()
	for _, tagName in { Enums.Tag.KeycardDoor, Enums.Tag.ClearanceDoor } do
		for _, instance in CollectionService:GetTagged(tagName) do
			addDoor(instance, tagName)
		end
	end
end

local function hold(door: Door, position: Vector3, now: number)
	if door.keycard and now < sealedUntil then
		return
	end
	door.lastHeld = now
	if not door.open then
		setOpen(door, true)
		if GameConfig.Debug.PrintEvents then
			print(`[DoorService] opened {door.part.Name} for a body at {position}`)
		end
	end
end

local function near(door: Door, position: Vector3): boolean
	local offset = door.part.Position - position
	return Vector3.new(offset.X, 0, offset.Z).Magnitude <= config.Door.OpenStuds
		and math.abs(offset.Y) <= config.Door.OpenStuds
end

-- On the inside of the doorway: past the middle of the wall on the higher-tier side.
local function isInside(door: Door, position: Vector3): boolean
	local inside = door.inside
	if not inside then
		return false
	end
	local offset = position - door.part.Position
	return Vector3.new(offset.X, 0, offset.Z):Dot(inside) > 0
end

function DoorService.holdNear(position: Vector3, clearance: number, opensKeycardDoors: boolean)
	local now = os.clock()
	for _, door in doors do
		if near(door, position) and (if door.tier then clearance >= door.tier else opensKeycardDoors) then
			hold(door, position, now)
		end
	end
end

-- A player near doors: their clearance opens them from either side, and anyone may leave by an ordinary clearance door
-- from its inside (free exit).
local function holdForPlayer(position: Vector3, clearance: number)
	local now = os.clock()
	for _, door in doors do
		if near(door, position) then
			local authorized = door.tier ~= nil and clearance >= (door.tier :: number)
			if authorized or (door.freeExit and isInside(door, position)) then
				hold(door, position, now)
			end
		end
	end
end

-- Which side of each doorway is inside, from the zone volumes a little way out on each side at body height, and
-- whether either side is a vault wing (its zone volume is a vault room's: Zone_<level>_T<tier>_<room id with "vault">).
local function readSides()
	local probe = config.Door.SideProbeStuds
	local volumes = CollectionService:GetTagged(Enums.Tag.ZoneVolume)
	local function roomNameAt(position: Vector3): string
		local names = {}
		for _, volume in volumes do
			if volume:IsA("BasePart") then
				local localPoint = volume.CFrame:PointToObjectSpace(position)
				local half = volume.Size / 2
				if
					math.abs(localPoint.X) <= half.X
					and math.abs(localPoint.Y) <= half.Y
					and math.abs(localPoint.Z) <= half.Z
				then
					table.insert(names, volume.Name)
				end
			end
		end
		return table.concat(names, " ")
	end
	local unsided = {}
	for _, door in doors do
		local part = door.part
		local normal = if part.Size.X < part.Size.Z then part.CFrame.RightVector else part.CFrame.LookVector
		normal = Vector3.new(normal.X, 0, normal.Z).Unit
		local floor = part.Position - Vector3.new(0, part.Size.Y / 2, 0)
		local body = floor + Vector3.new(0, config.Door.SideProbeHeight, 0)
		local a, b = body + normal * probe, body - normal * probe
		local tierA, tierB = ZoneService.tierAt(a), ZoneService.tierAt(b)
		if tierA ~= tierB then
			door.inside = if tierA > tierB then normal else -normal
		elseif door.tier then
			table.insert(unsided, tostring(part.Position))
		end
		local vaultWing = string.find(string.lower(roomNameAt(a) .. " " .. roomNameAt(b)), "vault") ~= nil
		door.freeExit = door.tier ~= nil and door.inside ~= nil and not vaultWing
	end
	if #unsided > 0 then
		warn(
			`[DoorService] {#unsided} clearance door(s) have the same zone tier on both sides, so no free exit: `
				.. table.concat(unsided, "; ")
		)
	end
end

function DoorService.seal(seconds: number)
	sealedUntil = os.clock() + seconds
	for _, door in doors do
		if door.keycard then
			door.openUntil = 0
			if door.open then
				setOpen(door, false)
			end
		end
	end
end

function DoorService.keycardDoor(id: string): BasePart?
	local door = byId[id]
	if door and door.keycard and not door.open and os.clock() >= sealedUntil then
		return door.part
	end
	return nil
end

-- Ticket 18a: any shut door with that SecurityId, keycard or clearance (the Keycard Clone opens either free).
function DoorService.shutDoor(id: string): BasePart?
	local door = byId[id]
	if door and not door.open and not (door.keycard and os.clock() < sealedUntil) then
		return door.part
	end
	return nil
end

-- Ticket 18a: the clearance door with that SecurityId if it is shut, and what hacking it costs in intel (its HackCost attribute).
function DoorService.clearanceDoor(id: string): (BasePart?, number?)
	local door = byId[id]
	if door and door.tier and not door.open then
		local cost = door.part:GetAttribute("HackCost")
		return door.part, if type(cost) == "number" then cost else nil
	end
	return nil, nil
end

-- Opens a keycard or clearance door by its SecurityId and keeps it open that long.
function DoorService.openDoor(id: string, seconds: number)
	local door = byId[id]
	if door then
		local now = os.clock()
		door.openUntil = now + seconds
		hold(door, door.part.Position, now)
	end
end

function DoorService.Start()
	readSides()
	CollectionService:GetInstanceAddedSignal(Enums.Tag.KeycardDoor):Connect(function(instance)
		addDoor(instance, Enums.Tag.KeycardDoor)
	end)
	local playerCheck = 0
	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		-- A player with enough clearance opens a clearance door by walking up to it.
		playerCheck += dt
		if playerCheck >= config.Door.PlayerCheckSeconds then
			playerCheck = 0
			for _, player in Players:GetPlayers() do
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if root and root:IsA("BasePart") then
					holdForPlayer(root.Position, DisguiseService.getClearance(player))
				end
			end
		end
		for _, door in doors do
			if door.open and now - door.lastHeld >= config.DoorCloseDelay and now >= door.openUntil then
				setOpen(door, false)
			end
		end
	end)
end

return DoorService
