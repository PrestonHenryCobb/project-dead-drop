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
--     role, or a player wearing a disguise of that tier. An Exposed player has no clearance, so these stay shut for them.
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

type Door = {
	part: BasePart,
	tier: number?, -- the clearance needed, for a clearance door
	open: boolean,
	lastHeld: number,
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

function DoorService.holdNear(position: Vector3, clearance: number, opensKeycardDoors: boolean)
	local now = os.clock()
	for _, door in doors do
		local offset = door.part.Position - position
		if
			Vector3.new(offset.X, 0, offset.Z).Magnitude <= config.Door.OpenStuds
			and math.abs(offset.Y) <= config.Door.OpenStuds
			and (if door.tier then clearance >= door.tier else opensKeycardDoors)
		then
			door.lastHeld = now
			if not door.open then
				setOpen(door, true)
				if GameConfig.Debug.PrintEvents then
					print(`[DoorService] opened {door.part.Name} for a body at {position}`)
				end
			end
		end
	end
end

function DoorService.Start()
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
					DoorService.holdNear(root.Position, DisguiseService.getClearance(player), false)
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
