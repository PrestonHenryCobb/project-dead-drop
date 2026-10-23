--!strict
-- The window-washer gondola (BUILD_ORDER Step 7B pass 2b): a railed platform that crosses between a dock on the Gala's
-- upper terrace and one on a wing balcony. Each dock has a call button: pressed where the gondola is, it sets off for
-- the other dock; pressed at the far dock, it comes over. A crossing takes GameConfig.Traversal.Gondola.CrossSeconds.
-- Riding breaks Cover (spec 7.2): anyone on board while it moves is exposed. Riders can fall or be shot off.
--
-- The server moves the whole model; each client carries its own character along with the floor (PlatformController).
-- The map tags the floor Gondola (with Start and End positions) and the buttons GondolaCall (End = "Start" or "End").
--
--   GondolaService.call(dock)   what a call button at that dock does

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local CoverService = require(script.Parent.CoverService)

type Dock = "Start" | "End"

local GondolaService = {}

local config = GameConfig.Traversal.Gondola
local floor: BasePart? = nil
local model: Model? = nil
local positions: { [Dock]: Vector3 } = {}
local at: Dock? = "Start" -- nil while moving
local buttons: { { part: BasePart, dock: Dock, prompt: ProximityPrompt } } = {}

local function other(dock: Dock): Dock
	return if dock == "Start" then "End" else "Start"
end

-- Is this player standing on (or just above) the gondola floor?
local function onBoard(player: Player, deck: BasePart): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return false
	end
	local localPoint = deck.CFrame:PointToObjectSpace(root.Position)
	return math.abs(localPoint.X) <= deck.Size.X / 2
		and math.abs(localPoint.Z) <= deck.Size.Z / 2
		and localPoint.Y >= 0
		and localPoint.Y <= config.RiderHeight
end

local function setPromptsEnabled(enabled: boolean)
	for _, button in buttons do
		button.prompt.Enabled = enabled
	end
end

local function travel(to: Dock)
	local deck, gondola = floor, model
	local from = at
	if not (deck and gondola and from) or from == to then
		return
	end
	at = nil
	setPromptsEnabled(false)
	local startPos, endPos = positions[from], positions[to]
	local rotation = gondola:GetPivot().Rotation
	local exposed: { [Player]: boolean } = {}
	local elapsed = 0
	local connection: RBXScriptConnection? = nil
	connection = RunService.Heartbeat:Connect(function(dt)
		elapsed = math.min(elapsed + dt, config.CrossSeconds)
		gondola:PivotTo(CFrame.new(startPos:Lerp(endPos, elapsed / config.CrossSeconds)) * rotation)
		for _, player in Players:GetPlayers() do
			if not exposed[player] and onBoard(player, deck) then
				exposed[player] = true
				CoverService.expose(player, "Gondola")
			end
		end
		if elapsed >= config.CrossSeconds then
			if connection then
				connection:Disconnect()
			end
			at = to
			setPromptsEnabled(true)
		end
	end)
end

function GondolaService.Init()
	for _, part in CollectionService:GetTagged(Enums.Tag.Gondola) do
		local startPos, endPos = part:GetAttribute("Start"), part:GetAttribute("End")
		if part:IsA("BasePart") and typeof(startPos) == "Vector3" and typeof(endPos) == "Vector3" then
			floor = part
			model = part:FindFirstAncestorOfClass("Model")
			positions.Start, positions.End = startPos, endPos
		end
	end
	for _, part in CollectionService:GetTagged(Enums.Tag.GondolaCall) do
		local dock = part:GetAttribute("End")
		if part:IsA("BasePart") and (dock == "Start" or dock == "End") then
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "Gondola"
			prompt.ObjectText = "Riding breaks Cover"
			prompt.MaxActivationDistance = config.PromptDistance
			prompt.HoldDuration = config.PromptHoldSeconds
			prompt.RequiresLineOfSight = false
			prompt.Parent = part
			table.insert(buttons, { part = part, dock = dock :: Dock, prompt = prompt })
		end
	end
end

-- What a call button does: at its dock, the gondola sets off for the other one; away, it comes over. Ignored while
-- the gondola is moving.
function GondolaService.call(dock: Dock)
	if not at then
		return
	end
	travel(if at == dock then other(dock) else dock)
end

function GondolaService.Start()
	for _, button in buttons do
		button.prompt.Triggered:Connect(function()
			GondolaService.call(button.dock)
		end)
	end
end

return GondolaService
