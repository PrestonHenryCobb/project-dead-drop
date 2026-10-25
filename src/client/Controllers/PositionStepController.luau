--!strict
-- Other players' positions, drawn in steps (step 8B.6, IDEAS_2026-10-24 Q1). Roblox replicates other characters
-- smoothly; this holds each one where it was at the start of the current step (PositionStep, on the server clock) and
-- moves it only when the next step begins, so other players jump between positions on the same beat as NPCs do. The
-- server rewinds shots to that same stepped moment, so a hit lands where the shooter saw the target.
--
-- Only how this client draws them changes. Your own character is never stepped, and nothing is written that other
-- clients or the server see.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PositionStep = require(Shared:WaitForChild("Util"):WaitForChild("PositionStep"))

type Entry = {
	root: BasePart,
	latest: CFrame, -- the newest position Roblox replicated
	written: CFrame?, -- what we drew last frame, to tell our own value from a new one
	held: CFrame,
	heldStep: number,
}

local PositionStepController = {}

local localPlayer = Players.LocalPlayer
local BIND_NAME = "CoverStoryPositionStep"
-- A CFrame read back after setting it is re-normalised, so a near match is still our own value.
local SAME_POSITION = 1e-3
local SAME_FACING = 0.99999

local entries: { [Model]: Entry } = {}

local function isOwnWrite(current: CFrame, written: CFrame?): boolean
	return written ~= nil
		and (current.Position - written.Position).Magnitude < SAME_POSITION
		and current.LookVector:Dot(written.LookVector) > SAME_FACING
end

local function track(character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not (root and root:IsA("BasePart")) or entries[character] then
		return
	end
	entries[character] = { root = root, latest = root.CFrame, written = nil, held = root.CFrame, heldStep = -1 }
	character.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			entries[character] = nil
		end
	end)
end

local function watch(player: Player)
	if player == localPlayer then
		return
	end
	player.CharacterAdded:Connect(track)
	if player.Character then
		task.spawn(track, player.Character)
	end
end

local function drawStepped()
	local stepStart = PositionStep.snap(workspace:GetServerTimeNow())
	for _, entry in entries do
		local replicated = entry.root.CFrame
		if not isOwnWrite(replicated, entry.written) then
			entry.latest = replicated
		end
		if stepStart ~= entry.heldStep then
			entry.heldStep = stepStart
			entry.held = entry.latest
		end
		entry.root.CFrame = entry.held
		entry.written = entry.held
	end
end

function PositionStepController.Init() end

function PositionStepController.Start()
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		if player.Character then
			entries[player.Character] = nil
		end
	end)
	RunService:BindToRenderStep(BIND_NAME, Enum.RenderPriority.Last.Value, drawStepped)
end

return PositionStepController
