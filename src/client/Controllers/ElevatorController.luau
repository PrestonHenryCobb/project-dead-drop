--!strict
-- Ticket 7B-glass-elevators: asking a cab for a level. Standing inside a cab, Interact (E) goes to the next level up, wrapping
-- to the lowest after the highest (a real level selector is a UI ticket for Codex). The server checks that the player really
-- stands in the cab; PlatformController carries the character with the cab floor.

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Janitor = require(Shared:WaitForChild("Util"):WaitForChild("Janitor"))
local RemoteController = require(script.Parent.RemoteController)

local ElevatorController = {}

local ACTION = "CoverStoryElevatorFloor"
local CHECK_SECONDS = 0.2
local controls = GameConfig.Controls
local rideConfig = GameConfig.Doors.Elevators
local localPlayer = Players.LocalPlayer

local janitor = Janitor.new()
local bound = false
local current: BasePart? = nil

local function insideCab(): BasePart?
	local root = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return nil
	end
	for _, instance in CollectionService:GetTagged(Enums.Tag.ElevatorCab) do
		if instance:IsA("BasePart") then
			local offset = instance.CFrame:PointToObjectSpace(root.Position)
			local half = instance.Size / 2
			if
				math.abs(offset.X) <= half.X + rideConfig.CabSlackStuds
				and math.abs(offset.Z) <= half.Z + rideConfig.CabSlackStuds
				and offset.Y >= -half.Y - rideConfig.CabSlackStuds
				and offset.Y <= rideConfig.CabHeightStuds
			then
				return instance
			end
		end
	end
	return nil
end

-- The level names of a cab, lowest first, from its Stops attribute ("G:0,M:24,T:48").
local function levelsOf(cab: BasePart): { string }
	local stops: { { name: string, height: number } } = {}
	local text = cab:GetAttribute("Stops")
	for entry in string.gmatch(if type(text) == "string" then text else "", "[^,]+") do
		local name, height = string.match(entry, "^(%a+):(%-?[%d%.]+)$")
		if name and height then
			table.insert(stops, { name = name, height = tonumber(height) :: number })
		end
	end
	table.sort(stops, function(a, b)
		return a.height < b.height
	end)
	local names: { string } = {}
	for _, stop in stops do
		table.insert(names, stop.name)
	end
	return names
end

local function onInteract(_: string, state: Enum.UserInputState): Enum.ContextActionResult
	local cab = current
	if state ~= Enum.UserInputState.Begin or not cab then
		return Enum.ContextActionResult.Pass
	end
	local level = cab:GetAttribute("Level")
	if cab:GetAttribute("State") == "Moving" or type(level) ~= "string" then
		return Enum.ContextActionResult.Sink
	end
	local names = levelsOf(cab)
	local index = table.find(names, level) or 0
	local nextName = names[index % #names + 1]
	if nextName then
		RemoteController.fire("RequestElevatorFloor", nextName)
	end
	return Enum.ContextActionResult.Sink
end

local function bindFor(want: boolean)
	if want and not bound then
		bound = true
		-- Below the security Interact (High): a prompt aimed at something wins, since in a cab there is usually none.
		ContextActionService:BindActionAtPriority(
			ACTION,
			onInteract,
			false,
			Enum.ContextActionPriority.Medium.Value,
			controls.Interact,
			controls.InteractPad
		)
	elseif not want and bound then
		bound = false
		ContextActionService:UnbindAction(ACTION)
	end
end

function ElevatorController.Init() end

function ElevatorController.Start()
	local elapsed = 0
	janitor:Add(game:GetService("RunService").Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < CHECK_SECONDS then
			return
		end
		elapsed = 0
		current = insideCab()
		bindFor(current ~= nil)
	end))
	janitor:Add(function()
		bindFor(false)
	end)
end

return ElevatorController
