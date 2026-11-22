--!strict
-- Ticket 11a: Intel stations on the client (spec 9.2).
--
--   * Hold Interact near a station (close, near the crosshair, in sight, not yet taken by your team) to hack it:
--     RequestInteract("Intel", id). The server times the hold and checks everything again.
--   * A station you could still take glints faintly gold when it is within Intel.GlintRange and in sight (spec 9.2).
--     A station your team has taken stops glinting. Only the stations (map props) are marked, never a character.
--   * The team's balance is kept for the HUD: IntelController.balance().
--
--   IntelController.balance() -> number

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

local IntelController = {}

local config = GameConfig.Intel
local controls = GameConfig.Controls
local localPlayer = Players.LocalPlayer
local INTERACT_ACTION = "CoverStoryInteractIntel"
local CHECK_SECONDS = 0.1

local stations: { [BasePart]: boolean } = {}
local used: { [string]: boolean } = {}
local balance = 0
local target: BasePart? = nil
local holding = false
local bound = false
local elapsed = 0
local glints: { Highlight } = {}
local glintFolder: Folder? = nil
local phase: Types.Phase = "Lobby"
local downed = false
local eliminated = false
local focused = true
local extractionFrozen = false
local heldStation: BasePart? = nil

local sight = RaycastParams.new()
sight.CollisionGroup = GameConfig.Rig.CollisionGroup
sight.RespectCanCollide = true

function IntelController.balance(): number
	return balance
end

local function idOf(part: BasePart): string?
	local id = part:GetAttribute("IntelId") or part:GetAttribute("VaultId") -- a vault terminal is held like a station
	return if type(id) == "string" then id else nil
end

-- Which interaction the server runs for this part: a station is "Intel", a vault terminal is "Vault".
local function kindOf(part: BasePart): string
	return if part:GetAttribute("VaultId") ~= nil then "Vault" else "Intel"
end

local function visible(from: Vector3, part: BasePart): boolean
	local hit = workspace:Raycast(from, part.Position - from, sight)
	return hit == nil or hit.Instance.Parent == part.Parent
end

local function eligibleRoot(): BasePart?
	if
		(phase ~= "Infiltration" and phase ~= "VaultBreach" and phase ~= "PackageHeist" and phase ~= "Overtime")
		or downed
		or eliminated
		or not focused
		or extractionFrozen
		or UserInputService:GetFocusedTextBox() ~= nil
		or DroneController.inputBlocked()
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
		heldStation = nil
		RemoteController.fire("RequestInteractCancel")
	end
end

local function onInteract(_: string, state: Enum.UserInputState): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin then
		local part = target
		local id = part and idOf(part)
		local root = eligibleRoot()
		local camera = workspace.CurrentCamera
		if
			part
			and id
			and root
			and camera
			and stations[part]
			and part.Parent
			and not used[id]
			and (part.Position - root.Position).Magnitude <= config.InteractStuds
			and (part.Position - camera.CFrame.Position).Magnitude > 0
			and (part.Position - camera.CFrame.Position).Unit:Dot(camera.CFrame.LookVector) >= math.cos(
				math.rad(config.AimDegrees)
			)
			and visible(camera.CFrame.Position, part)
		then
			holding = true
			heldStation = part
			RemoteController.fire("RequestInteract", kindOf(part), id)
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

-- Interact is bound only while there is a station to use it on (spec 24 note: contextual).
local function bindFor(want: boolean)
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

local function glintAt(index: number): Highlight
	local glint = glints[index]
	if not glint then
		glint = Instance.new("Highlight")
		glint.Name = "IntelGlint"
		glint.FillColor = config.GlintColor
		glint.OutlineColor = config.GlintColor
		glint.FillTransparency = config.GlintFillTransparency
		glint.OutlineTransparency = config.GlintOutlineTransparency
		glint.DepthMode = Enum.HighlightDepthMode.Occluded
		glint.Parent = glintFolder
		glints[index] = glint
	end
	return glint
end

local function refresh()
	local root = eligibleRoot()
	local camera = workspace.CurrentCamera
	if not (root and camera) then
		cancelHold()
		target = nil
		bindFor(false)
		for _, glint in glints do
			glint.Adornee = nil
		end
		return
	end
	local minDot = math.cos(math.rad(config.AimDegrees))
	local best: BasePart? = nil
	local bestDot = minDot
	local shown = 0
	for part in stations do
		local id = idOf(part)
		if id and not used[id] and part.Parent then
			local distance = (part.Position - root.Position).Magnitude
			if distance <= config.GlintRange and visible(camera.CFrame.Position, part) then
				if shown < config.GlintMax then
					shown += 1
					glintAt(shown).Adornee = part
				end
				if distance <= config.InteractStuds then
					local dot = (part.Position - camera.CFrame.Position).Unit:Dot(camera.CFrame.LookVector)
					if dot >= bestDot then
						best, bestDot = part, dot
					end
				end
			end
		end
	end
	for index = shown + 1, #glints do
		glints[index].Adornee = nil
	end
	target = best
	bindFor(best ~= nil or holding)
end

function IntelController.Init() end

function IntelController.Start()
	local janitor = Janitor.new()
	local folder = Instance.new("Folder")
	folder.Name = "CoverStoryIntelGlints" -- client only
	folder.Parent = workspace
	glintFolder = folder
	janitor:Add(folder)

	local function track(instance: Instance)
		if instance:IsA("BasePart") then
			stations[instance] = true
		end
	end
	local function untrack(instance: Instance)
		if instance:IsA("BasePart") then
			stations[instance] = nil
			if heldStation == instance then
				cancelHold()
			end
			refresh()
		end
	end
	janitor:Add(CollectionService:GetInstanceAddedSignal(Enums.Tag.IntelSpawn):Connect(track))
	janitor:Add(CollectionService:GetInstanceRemovedSignal(Enums.Tag.IntelSpawn):Connect(untrack))
	for _, instance in CollectionService:GetTagged(Enums.Tag.IntelSpawn) do
		track(instance)
	end
	-- Vault terminals (owner decision 2026-11-21: hold Interact at one to hack it) are tracked the same way.
	janitor:Add(CollectionService:GetInstanceAddedSignal(Enums.Tag.VaultTerminal):Connect(track))
	janitor:Add(CollectionService:GetInstanceRemovedSignal(Enums.Tag.VaultTerminal):Connect(untrack))
	for _, instance in CollectionService:GetTagged(Enums.Tag.VaultTerminal) do
		track(instance)
	end

	janitor:Add(RemoteController.connect("IntelUpdate", function(info: Types.IntelUpdateInfo)
		balance = info.Balance
		table.clear(used)
		for _, id in info.Used do
			used[id] = true
		end
		refresh()
	end))
	-- A new match starts with nothing taken; the server sends the empty state, so this only guards a missed message.
	janitor:Add(RemoteController.connect("PhaseChanged", function(nextPhase: Types.Phase)
		phase = nextPhase
		if nextPhase == "Lobby" then
			balance = 0
			table.clear(used)
		end
		if nextPhase == "Lobby" or nextPhase == "Insertion" then
			extractionFrozen = false
		end
		refresh()
	end))
	janitor:Add(RemoteController.connect("ExtractionState", function(info: Types.ExtractionStateInfo)
		extractionFrozen = info.State == "Extracted"
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
	janitor:Add(RemoteController.connect("InteractState", function(info: Types.InteractStateInfo)
		if (info.Kind == "Hack" or info.Kind == GameConfig.Vault.HoldLabel) and not info.Active then
			holding = false
			heldStation = nil
			refresh()
		end
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
		bindFor(false)
		target, glintFolder = nil, nil
		balance = 0
		table.clear(stations)
		table.clear(used)
		table.clear(glints)
	end)
	janitor:Add(script.Destroying:Connect(function()
		janitor:Destroy()
	end))
end

return IntelController
