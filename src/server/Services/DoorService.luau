--!strict
-- Doors that open for NPCs (spec 5.2) and for clearance (STEP 7B). A door closes DoorCloseDelay seconds after the last
-- body was near it, so someone slipping through behind an opener is the tailgating the game allows.
--
-- The tagged part is the doorway's invisible blocker: solid while the door is shut (it stops bodies and sight), and not
-- while it is open. Its Open attribute tells clients to swing the visible leaves (DoorController); the server never
-- moves them (map re-plan stage 3).
--
--   * Keycard doors (spec 4.3) open for any NPC. Players opening them with keycards, gadgets and lockpicks is Step 14.
--   * Clearance doors open only for a body whose clearance tier is at least the door's Tier attribute: an NPC of that
--     role, or a player wearing a disguise of that tier, from either side. An Exposed player has no clearance.
--   * Free exit (R3-doors, owner decision 2026-10-25): a player on the inside of an ordinary clearance door may always
--     leave, clearance or not, so nobody is trapped after losing it. Entry from outside still needs clearance. Doors
--     into a vault wing are exempt. The inside is the side with the higher zone tier, read once from the zone volumes
--     on each side of the doorway (server map data, never a client claim); a doorway with the same tier on both sides
--     has no inside and no free exit.
--
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
}

local DoorService = {}

local config = GameConfig.NPC
local doors: { Door } = {}

local function setOpen(door: Door, open: boolean)
	door.open = open
	door.part.CanCollide = not open
	door.part:SetAttribute("Open", open)
end

function DoorService.Init()
	for _, tagName in { Enums.Tag.KeycardDoor, Enums.Tag.ClearanceDoor } do
		for _, instance in CollectionService:GetTagged(tagName) do
			if instance:IsA("BasePart") then
				table.insert(doors, {
					part = instance,
					tier = if tagName == Enums.Tag.ClearanceDoor then instance:GetAttribute("Tier") else nil,
					open = false,
					lastHeld = 0,
					inside = nil,
					freeExit = false,
				})
				instance:SetAttribute("Open", false)
				if config.Door.OpenForNpcs then
					-- Pathfinding treats the door as open ground, so NPC routes can go through it.
					local modifier = Instance.new("PathfindingModifier")
					modifier.PassThrough = true
					modifier.Parent = instance
				end
			end
		end
	end
end

local function hold(door: Door, position: Vector3, now: number)
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

function DoorService.Start()
	readSides()
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
			if door.open and now - door.lastHeld >= config.DoorCloseDelay then
				setOpen(door, false)
			end
		end
	end)
end

return DoorService
