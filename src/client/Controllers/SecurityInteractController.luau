--!strict
-- Ticket 14: hold Interact on the security objects (spec 18): hack a camera, cut a laser grid's power at its fuse box, use
-- the Camera Room terminal, pick a keycard door's lock. Close, near the crosshair and in sight, as for Intel stations
-- (IntelController); the target is outlined while Interact would work on it. The server times the hold and checks it all
-- again (CameraService, LaserService, SecurityService).

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Janitor = require(Shared:WaitForChild("Util"):WaitForChild("Janitor"))
local Types = require(Shared:WaitForChild("Types"))
local DroneController = require(script.Parent.DroneController)
local RemoteController = require(script.Parent.RemoteController)

type Kind = {
	tag: string,
	kind: string, -- the InteractService kind
	idAttribute: string?, -- the attribute naming the target to the server (SecurityId unless this says otherwise)
	usable: (BasePart, Vector3) -> boolean, -- close enough and worth using right now
}

local SecurityInteractController = {}

local security = GameConfig.Security
local controls = GameConfig.Controls
local localPlayer = Players.LocalPlayer
local INTERACT_ACTION = "CoverStoryInteractSecurity"
local CHECK_SECONDS = 0.1

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local KINDS: { Kind } = {
	{
		tag = Enums.Tag.SecurityCamera,
		kind = "Camera",
		usable = function(part, from)
			local state = part:GetAttribute("CameraState")
			local hackableAt = part:GetAttribute("HackableAt")
			return (state == "Sweep" or state == "Locked")
				and type(hackableAt) == "number"
				and workspace:GetServerTimeNow() >= hackableAt
				and flatDistance(part.Position, from) <= security.Camera.HackRange
		end,
	},
	{
		tag = Enums.Tag.FuseBox,
		kind = "FuseBox",
		usable = function(part, from)
			return (part.Position - from).Magnitude <= security.LaserGrid.FuseBox.InteractStuds
		end,
	},
	{
		tag = Enums.Tag.CameraTerminal,
		kind = "CameraTerminal",
		usable = function(part, from)
			local readyAt = part:GetAttribute("ReadyAt")
			return type(readyAt) == "number"
				and workspace:GetServerTimeNow() >= readyAt
				and (part.Position - from).Magnitude <= security.CameraRoom.InteractStuds
		end,
	},
	{
		tag = Enums.Tag.KeycardDoor,
		kind = "Lockpick",
		usable = function(part, from)
			return part:GetAttribute("Open") == false
				and (part.Position - from).Magnitude <= security.KeycardDoor.InteractStuds
		end,
	},
	{
		-- Ticket 18b: the wall stations. The server decides whether you need it and can pay; the outline shows what Interact uses.
		tag = Enums.Tag.HealthStation,
		kind = "HealthStation",
		idAttribute = "StationId",
		usable = function(part, from)
			return (part.Position - from).Magnitude <= GameConfig.Economy.Stations.InteractStuds
		end,
	},
	{
		tag = Enums.Tag.AmmoCache,
		kind = "AmmoCache",
		idAttribute = "StationId",
		usable = function(part, from)
			return (part.Position - from).Magnitude <= GameConfig.Economy.Stations.InteractStuds
		end,
	},
	{
		tag = Enums.Tag.FoodSpot,
		kind = "FoodSpot",
		idAttribute = "StationId",
		usable = function(part, from)
			return part:GetAttribute("Taken") ~= true
				and (part.Position - from).Magnitude <= GameConfig.Economy.Stations.InteractStuds
		end,
	},
	{
		-- Ticket 18a: a tier door shut in your face can be hacked open with the team's intel.
		tag = Enums.Tag.ClearanceDoor,
		kind = "DoorHack",
		usable = function(part, from)
			return part:GetAttribute("Open") == false
				and type(part:GetAttribute("HackCost")) == "number"
				and (part.Position - from).Magnitude <= GameConfig.Doors.HackStuds
		end,
	},
}

local objects: { [BasePart]: Kind } = {}
local target: BasePart? = nil
local targetKind: Kind? = nil
local holding = false
local bound = false
local elapsed = 0
local phase: Types.Phase = "Lobby"
local focused = true
local outline: Highlight? = nil

local sight = RaycastParams.new()
sight.CollisionGroup = GameConfig.Rig.CollisionGroup
sight.RespectCanCollide = true

local function visible(from: Vector3, part: BasePart): boolean
	local hit = workspace:Raycast(from, part.Position - from, sight)
	return hit == nil or hit.Instance == part or hit.Instance.Parent == part.Parent
end

local function eligibleRoot(): BasePart?
	if
		(phase ~= "Infiltration" and phase ~= "VaultBreach" and phase ~= "PackageHeist" and phase ~= "Overtime")
		or not focused
		or UserInputService:GetFocusedTextBox() ~= nil
	then
		return nil
	end
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return DroneController.part() or root -- ticket 16c: Lattice's drone hacks from where it hovers
	end
	return nil
end

local function cancelHold()
	if holding then
		holding = false
		RemoteController.fire("RequestInteractCancel")
	end
end

local function onInteract(_: string, state: Enum.UserInputState): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin then
		local part, kind = target, targetKind
		local id = part and kind and part:GetAttribute(kind.idAttribute or "SecurityId")
		if part and kind and type(id) == "string" then
			holding = true
			RemoteController.fire("RequestInteract", kind.kind, id)
			return Enum.ContextActionResult.Sink
		end
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		if holding then
			cancelHold()
			return Enum.ContextActionResult.Sink
		end
	end
	return Enum.ContextActionResult.Pass
end

-- Interact is bound only while there is something to use it on (spec 24 note: contextual).
local function bindFor(want: boolean)
	if want and not bound then
		bound = true
		ContextActionService:BindActionAtPriority(
			INTERACT_ACTION,
			onInteract,
			false,
			Enum.ContextActionPriority.High.Value,
			controls.Interact,
			controls.InteractPad
		)
	elseif not want and bound then
		bound = false
		ContextActionService:UnbindAction(INTERACT_ACTION)
	end
end

local function refresh()
	local root = eligibleRoot()
	local camera = workspace.CurrentCamera
	local best: BasePart? = nil
	local bestKind: Kind? = nil
	if root and camera then
		local bestDot = math.cos(math.rad(GameConfig.Intel.AimDegrees))
		for part, kind in objects do
			if part.Parent and kind.usable(part, root.Position) then
				local offset = part.Position - camera.CFrame.Position
				if offset.Magnitude > 0 then
					local dot = offset.Unit:Dot(camera.CFrame.LookVector)
					if dot >= bestDot and visible(camera.CFrame.Position, part) then
						best, bestKind, bestDot = part, kind, dot
					end
				end
			end
		end
	end
	if not best then
		cancelHold()
	end
	target, targetKind = best, bestKind
	if outline then
		outline.Adornee = best
	end
	bindFor(best ~= nil or holding)
end

function SecurityInteractController.Init() end

-- Ticket 14b: HUD reads the same contextual target; it never selects or requests a different action.
function SecurityInteractController.currentTarget(): (BasePart?, string?)
	if not eligibleRoot() then
		return nil, nil
	end
	return target, if targetKind then targetKind.kind else nil
end

function SecurityInteractController.Start()
	local janitor = Janitor.new()
	local highlight = Instance.new("Highlight")
	highlight.Name = "SecurityTarget" -- client only, on a map prop
	highlight.FillTransparency = 1
	highlight.OutlineColor = security.CameraLook.TargetColor
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = workspace
	outline = highlight
	janitor:Add(highlight)

	for _, kind in KINDS do
		local function add(instance: Instance)
			if instance:IsA("BasePart") then
				objects[instance] = kind
			end
		end
		janitor:Add(CollectionService:GetInstanceAddedSignal(kind.tag):Connect(add))
		janitor:Add(CollectionService:GetInstanceRemovedSignal(kind.tag):Connect(function(instance)
			objects[instance :: BasePart] = nil
		end))
		for _, instance in CollectionService:GetTagged(kind.tag) do
			add(instance)
		end
	end

	janitor:Add(RemoteController.connect("PhaseChanged", function(nextPhase: Types.Phase)
		phase = nextPhase
		refresh()
	end))
	janitor:Add(RemoteController.connect("InteractState", function(info: Types.InteractStateInfo)
		if not info.Active then
			holding = false
			refresh()
		end
	end))
	janitor:Add(localPlayer.CharacterAdded:Connect(function()
		cancelHold()
		refresh()
	end))
	janitor:Add(UserInputService.WindowFocusReleased:Connect(function()
		focused = false
		refresh()
	end))
	janitor:Add(UserInputService.WindowFocused:Connect(function()
		focused = true
		refresh()
	end))
	janitor:Add(RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= CHECK_SECONDS then
			elapsed = 0
			refresh()
		end
	end))
	janitor:Add(function()
		cancelHold()
		bindFor(false)
		target, targetKind, outline = nil, nil, nil
		table.clear(objects)
	end)
	janitor:Add(script.Destroying:Connect(function()
		janitor:Destroy()
	end))
end

return SecurityInteractController
