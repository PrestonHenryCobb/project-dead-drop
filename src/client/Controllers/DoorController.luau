--!strict
-- Swings the leaves of clearance and keycard doors (MAP_BRIEF_REPLAN stage 3). The server owns every door: DoorService
-- makes a door's invisible blocker solid or not and sets its Open attribute. This client only animates the look, so
-- the leaves (Models under the blocker's Leaves folder, each pivoting on its hinge) turn by their Swing direction
-- times GameConfig.Map.Doors.SwingDegrees over SwingSeconds. Nothing here decides who may pass.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local DoorController = {}

local config = GameConfig.Map.Doors

type Door = { blocker: BasePart, progress: number, target: number }
local doors: { [BasePart]: Door } = {}
local moving: { [Door]: boolean } = {}

-- Ease in and out, so a door starts and stops softly.
local function ease(t: number): number
	return t * t * (3 - 2 * t)
end

local function pose(door: Door)
	local leaves = door.blocker:FindFirstChild("Leaves")
	if not leaves then
		return
	end
	local angle = math.rad(config.SwingDegrees) * ease(door.progress)
	for _, leaf in leaves:GetChildren() do
		local closed = leaf:GetAttribute("Closed")
		local swing = leaf:GetAttribute("Swing")
		if leaf:IsA("Model") and typeof(closed) == "CFrame" and type(swing) == "number" then
			leaf:PivotTo(closed * CFrame.Angles(0, swing * angle, 0))
		end
	end
end

local function sync(door: Door)
	door.target = if door.blocker:GetAttribute("Open") == true then 1 else 0
	if door.progress ~= door.target then
		moving[door] = true
	end
end

local function add(instance: Instance)
	if not instance:IsA("BasePart") or doors[instance] then
		return
	end
	-- A door that streams in already open is shown open straight away.
	local open = instance:GetAttribute("Open") == true
	local door: Door = { blocker = instance, progress = if open then 1 else 0, target = if open then 1 else 0 }
	doors[instance] = door
	pose(door)
	instance:GetAttributeChangedSignal("Open"):Connect(function()
		sync(door)
	end)
	-- Leaves may arrive a moment after their blocker under StreamingEnabled.
	instance.ChildAdded:Connect(function()
		pose(door)
	end)
end

local function remove(instance: Instance)
	if instance:IsA("BasePart") then
		local door = doors[instance]
		if door then
			moving[door] = nil
			doors[instance] = nil
		end
	end
end

function DoorController.Init() end

function DoorController.Start()
	for _, tagName in { Enums.Tag.ClearanceDoor, Enums.Tag.KeycardDoor } do
		for _, instance in CollectionService:GetTagged(tagName) do
			add(instance)
		end
		CollectionService:GetInstanceAddedSignal(tagName):Connect(add)
		CollectionService:GetInstanceRemovedSignal(tagName):Connect(remove)
	end

	RunService.RenderStepped:Connect(function(dt)
		local step = dt / config.SwingSeconds
		for door in moving do
			if door.progress < door.target then
				door.progress = math.min(door.target, door.progress + step)
			else
				door.progress = math.max(door.target, door.progress - step)
			end
			pose(door)
			if door.progress == door.target then
				moving[door] = nil
			end
		end
	end)
end

return DoorController
