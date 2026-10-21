--!strict
-- Doors that open for NPCs (spec 5.2): an NPC walking up to a door opens it, and it closes DoorCloseDelay seconds
-- after the last body was near it. Keycard doors are the only door objects the map has; players opening them with
-- keycards, gadgets and lockpicks is built in Step 14 on top of this.
--
--   DoorService.holdNear(position)   keeps open any door close to the position (opening it if shut)

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))

type Door = {
	part: BasePart,
	open: boolean,
	lastHeld: number,
	closedTransparency: number,
}

local DoorService = {}

local config = GameConfig.NPC
local doors: { Door } = {}

local function setOpen(door: Door, open: boolean)
	door.open = open
	door.part.CanCollide = not open
	door.part.Transparency = if open then config.Door.OpenTransparency else door.closedTransparency
end

function DoorService.Init()
	for _, instance in CollectionService:GetTagged(Enums.Tag.KeycardDoor) do
		if instance:IsA("BasePart") then
			table.insert(
				doors,
				{ part = instance, open = false, lastHeld = 0, closedTransparency = instance.Transparency }
			)
			if config.Door.OpenForNpcs then
				-- Pathfinding treats the door as open ground, so NPC routes can go through it.
				local modifier = Instance.new("PathfindingModifier")
				modifier.PassThrough = true
				modifier.Parent = instance
			end
		end
	end
end

function DoorService.holdNear(position: Vector3)
	local now = os.clock()
	for _, door in doors do
		local offset = door.part.Position - position
		if
			Vector3.new(offset.X, 0, offset.Z).Magnitude <= config.Door.OpenStuds
			and math.abs(offset.Y) <= config.Door.OpenStuds
		then
			door.lastHeld = now
			if not door.open then
				setOpen(door, true)
				if GameConfig.Debug.TestEvents then
					print(`[DoorService] opened {door.part.Name} for a body at {position}`)
				end
			end
		end
	end
end

function DoorService.Start()
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for _, door in doors do
			if door.open and now - door.lastHeld >= config.DoorCloseDelay then
				setOpen(door, false)
			end
		end
	end)
end

return DoorService
