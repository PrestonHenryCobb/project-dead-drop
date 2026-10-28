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

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Types = require(Shared:WaitForChild("Types"))
local RemoteController = require(script.Parent.RemoteController)

local PackageController = {}

local controls = GameConfig.Controls
local packageConfig = GameConfig.Package
local extractionConfig = GameConfig.Extraction
local localPlayer = Players.LocalPlayer
local INTERACT_ACTION = "CoverStoryInteractObjective"
local DROP_ACTION = "CoverStoryDropPackage"
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
	then
		return { kind = "ExtractionChannel", target = extraction.SiteId }
	end
	for _, terminal in CollectionService:GetTagged(Enums.Tag.ExtractionTerminal) do
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
		local picked = choice
		if picked then
			holding = true
			RemoteController.fire("RequestInteract", picked.kind, picked.target)
		end
		return Enum.ContextActionResult.Sink
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		if holding then
			holding = false
			RemoteController.fire("RequestInteractCancel")
		end
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end

local function onDrop(_: string, state: Enum.UserInputState): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin then
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
			Enum.ContextActionPriority.High.Value,
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
	elseif not want and dropBound then
		dropBound = false
		ContextActionService:UnbindAction(DROP_ACTION)
	end
end

local function refresh()
	local root = rootOf(localPlayer)
	choice = if root then choose(root) else nil
	bindInteract(choice ~= nil or holding)
	bindDrop(packageState ~= nil and packageState.YouCarry)
end

function PackageController.Init() end

function PackageController.Start()
	RemoteController.connect("PackageState", function(info: Types.PackageStateInfo)
		packageState = info
	end)
	RemoteController.connect("ExtractionState", function(info: Types.ExtractionStateInfo)
		extractionState = info
	end)
	RemoteController.connect("TeamRoster", function(info: Types.TeamRosterInfo)
		teammates = info.Members
	end)
	RemoteController.connect("PhaseChanged", function(phase: Types.Phase)
		if phase == "Lobby" or phase == "Insertion" then
			packageState, extractionState = nil, nil
		end
	end)
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= CHECK_SECONDS then
			elapsed = 0
			refresh()
		end
	end)
end

return PackageController
