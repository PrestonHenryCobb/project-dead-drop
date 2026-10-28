--!strict
-- Ticket 11a: Intel stations on the client (spec 9.2).
--
--   * Hold Interact near a station (close, near the crosshair, in sight, not yet taken by your team) to hack it:
--     RequestInteract("Intel", id). The server times the hold and checks everything again.
--   * A station you could still take glints faintly gold when it is within Intel.GlintRange and in sight (spec 9.2).
--     A station your team has taken stops glinting. Only the stations (map props) are marked, never a character.
--   * The balance and the match-wide total are kept for the HUD: IntelController.balance() and .global().
--
--   IntelController.balance() -> number
--   IntelController.global() -> Types.GlobalIntelInfo?

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Janitor = require(Shared:WaitForChild("Util"):WaitForChild("Janitor"))
local Types = require(Shared:WaitForChild("Types"))
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
local globalInfo: Types.GlobalIntelInfo? = nil
local target: BasePart? = nil
local holding = false
local bound = false
local elapsed = 0
local glints: { Highlight } = {}
local glintFolder: Folder? = nil

local sight = RaycastParams.new()
sight.CollisionGroup = GameConfig.Rig.CollisionGroup
sight.RespectCanCollide = true

function IntelController.balance(): number
	return balance
end

function IntelController.global(): Types.GlobalIntelInfo?
	return globalInfo
end

local function idOf(part: BasePart): string?
	local id = part:GetAttribute("IntelId")
	return if type(id) == "string" then id else nil
end

local function visible(from: Vector3, part: BasePart): boolean
	local hit = workspace:Raycast(from, part.Position - from, sight)
	return hit == nil or hit.Instance.Parent == part.Parent
end

local function onInteract(_: string, state: Enum.UserInputState): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin then
		local part = target
		local id = part and idOf(part)
		if id then
			holding = true
			RemoteController.fire("RequestInteract", "Intel", id)
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

-- Interact is bound only while there is a station to use it on (spec 24 note: contextual).
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
	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local camera = workspace.CurrentCamera
	if not (root and root:IsA("BasePart") and camera) then
		target = nil
		bindFor(holding)
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
		end
	end
	for _, instance in CollectionService:GetTagged(Enums.Tag.IntelSpawn) do
		track(instance)
	end
	CollectionService:GetInstanceAddedSignal(Enums.Tag.IntelSpawn):Connect(track)
	CollectionService:GetInstanceRemovedSignal(Enums.Tag.IntelSpawn):Connect(untrack)

	RemoteController.connect("IntelUpdate", function(info: Types.IntelUpdateInfo)
		balance = info.Balance
		table.clear(used)
		for _, id in info.Used do
			used[id] = true
		end
	end)
	RemoteController.connect("GlobalIntelUpdate", function(info: Types.GlobalIntelInfo)
		globalInfo = info
	end)
	-- A new match starts with nothing taken; the server sends the empty state, so this only guards a missed message.
	RemoteController.connect("PhaseChanged", function(phase: Types.Phase)
		if phase == "Lobby" then
			balance, globalInfo = 0, nil
			table.clear(used)
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

return IntelController
