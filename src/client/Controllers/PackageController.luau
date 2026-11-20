--!strict
-- Ticket 13a: the Package and extraction on the client (spec 11, spec 12).
--
-- One contextual Interact binding picks what the held key does, most urgent first:
--   1. Extract: you carry the Package and stand in the green zone  -> RequestInteract("ExtractionChannel", site)
--   2. Call extraction: a terminal within reach                    -> RequestInteract("ExtractionCall", site)
--   3. Pass: you carry the Package and a teammate is within range  -> RequestInteract("PackagePass", "")
--   4. Take the Package: it lies within reach                      -> RequestInteract("Package", "")
-- The server checks everything again (who may call, which team carries it). X drops the Package (RequestDropPackage).
--
--   PackageController.state() -> Types.PackageStateInfo?
--   PackageController.extraction() -> Types.ExtractionStateInfo?

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Types = require(Shared:WaitForChild("Types"))
local Janitor = require(Shared:WaitForChild("Util"):WaitForChild("Janitor"))
local RemoteController = require(script.Parent.RemoteController)
local HeldItemController = require(script.Parent.HeldItemController)

local PackageController = {}

local controls = GameConfig.Controls
local packageConfig = GameConfig.Package
local extractionConfig = GameConfig.Extraction
local localPlayer = Players.LocalPlayer
local INTERACT_ACTION = "CoverStoryInteractObjective"
local DROP_ACTION = "CoverStoryDropPackage"
local DROP_PAD_ACTION = "CoverStoryDropPackagePad"
local CHECK_SECONDS = 0.1

type Choice = { kind: string, target: string }

local packageState: Types.PackageStateInfo? = nil
local extractionState: Types.ExtractionStateInfo? = nil
local teammates: { Player } = {}
local choice: Choice? = nil
local holding = false
local bound = false
local dropBound = false
local elapsed = 0
local phase: Types.Phase = "Lobby"
local downed = false
local eliminated = false
local focused = true

function PackageController.state(): Types.PackageStateInfo?
	return packageState
end

function PackageController.extraction(): Types.ExtractionStateInfo?
	return extractionState
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function flatDistance(a: Vector3, b: Vector3): number
	local offset = a - b
	return Vector3.new(offset.X, 0, offset.Z).Magnitude
end

local function usable(): boolean
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return (phase == "PackageHeist" or phase == "Overtime")
		and not downed
		and not eliminated
		and focused
		and UserInputService:GetFocusedTextBox() == nil
		and not HeldItemController.isInputBlocked()
		and humanoid ~= nil
		and humanoid.Health > 0
		and not (extractionState ~= nil and extractionState.State == "Extracted")
end

local function cancelHold()
	if holding then
		holding = false
		RemoteController.fire("RequestInteractCancel")
	end
end

local function choose(root: BasePart): Choice?
	local carrying = packageState ~= nil and packageState.YouCarry
	local extraction = extractionState
	if
		carrying
		and extraction
		and extraction.State == "Open"
		and extraction.Position
		and extraction.SiteId
		and flatDistance(root.Position, extraction.Position) <= extractionConfig.ZoneSize / 2
		and math.abs(root.Position.Y - extraction.Position.Y) <= extractionConfig.ZoneHeightStuds
	then
		return { kind = "ExtractionChannel", target = extraction.SiteId }
	end
	local teamCarries = packageState ~= nil and (packageState.YouCarry or packageState.TeamCarries)
	local canCall = teamCarries and (not extraction or extraction.State == "Idle" or not extraction.ByYourTeam)
	for _, terminal in if canCall then CollectionService:GetTagged(Enums.Tag.ExtractionTerminal) else {} do
		local siteId = terminal:GetAttribute("SiteId")
		if
			terminal:IsA("BasePart")
			and type(siteId) == "string"
			and (terminal.Position - root.Position).Magnitude <= extractionConfig.CallReachStuds
		then
			return { kind = "ExtractionCall", target = siteId }
		end
	end
	if carrying then
		for _, mate in teammates do
			local mateRoot = if mate ~= localPlayer then rootOf(mate) else nil
			if mateRoot and (mateRoot.Position - root.Position).Magnitude <= packageConfig.PassRange then
				return { kind = "PackagePass", target = "-" }
			end
		end
	elseif packageState and (packageState.State == "Pedestal" or packageState.State == "Dropped") then
		for _, item in CollectionService:GetTagged(Enums.Tag.PackageItem) do
			if item:IsA("BasePart") and (item.Position - root.Position).Magnitude <= packageConfig.PickupRange then
				return { kind = "Package", target = "-" }
			end
		end
	end
	return nil
end

local function onInteract(_: string, state: Enum.UserInputState): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin then
		local root = if usable() then rootOf(localPlayer) else nil
		local picked = if root then choose(root) else nil
		if picked then
			holding = true
			RemoteController.fire("RequestInteract", picked.kind, picked.target)
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

local function onDrop(_: string, state: Enum.UserInputState): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin and usable() and packageState and packageState.YouCarry then
		RemoteController.fire("RequestDropPackage")
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end

local function bindInteract(want: boolean)
	if want and not bound then
		bound = true
		ContextActionService:BindActionAtPriority(
			INTERACT_ACTION,
			onInteract,
			false,
			GameConfig.Combat.InputPriority + 1, -- a valid contextual hold takes precedence over gamepad reload
			controls.Interact,
			controls.InteractPad
		)
	elseif not want and bound then
		bound = false
		ContextActionService:UnbindAction(INTERACT_ACTION)
	end
end

local function bindDrop(want: boolean)
	if want and not dropBound then
		dropBound = true
		ContextActionService:BindActionAtPriority(
			DROP_ACTION,
			onDrop,
			false,
			Enum.ContextActionPriority.High.Value,
			controls.DropPackage
		)
		-- The pad button is B, which also closes the elevator, settings and shop screens: bound below them, so B closes one first.
		ContextActionService:BindActionAtPriority(
			DROP_PAD_ACTION,
			onDrop,
			false,
			GameConfig.Combat.InputPriority,
			controls.DropPackagePad
		)
	elseif not want and dropBound then
		dropBound = false
		ContextActionService:UnbindAction(DROP_ACTION)
		ContextActionService:UnbindAction(DROP_PAD_ACTION)
	end
end

local function refresh()
	local root = if usable() then rootOf(localPlayer) else nil
	if not root then
		cancelHold()
	end
	choice = if root then choose(root) else nil
	bindInteract(choice ~= nil or holding)
	bindDrop(root ~= nil and packageState ~= nil and packageState.YouCarry)
end

function PackageController.Init() end

function PackageController.Start()
	local janitor = Janitor.new()
	janitor:Add(RemoteController.connect("PackageState", function(info: Types.PackageStateInfo)
		packageState = info
		refresh()
	end))
	janitor:Add(RemoteController.connect("ExtractionState", function(info: Types.ExtractionStateInfo)
		extractionState = info
		refresh()
	end))
	janitor:Add(RemoteController.connect("TeamRoster", function(info: Types.TeamRosterInfo)
		teammates = info.Members
	end))
	janitor:Add(RemoteController.connect("PhaseChanged", function(nextPhase: Types.Phase)
		phase = nextPhase
		if nextPhase == "Lobby" or nextPhase == "Insertion" then
			packageState, extractionState = nil, nil
		end
		refresh()
	end))
	janitor:Add(RemoteController.connect("Downed", function()
		downed = true
		refresh()
	end))
	janitor:Add(RemoteController.connect("Eliminated", function()
		eliminated = true
		refresh()
	end))
	janitor:Add(RemoteController.connect("Revived", function()
		downed = false
		refresh()
	end))
	janitor:Add(localPlayer.CharacterAdded:Connect(function()
		cancelHold()
		downed, eliminated = false, false
		refresh()
	end))
	janitor:Add(UserInputService.TextBoxFocused:Connect(refresh))
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
		bindInteract(false)
		bindDrop(false)
		packageState, extractionState, choice = nil, nil, nil
		table.clear(teammates)
	end)
	janitor:Add(script.Destroying:Connect(function()
		janitor:Destroy()
	end))
end

return PackageController
