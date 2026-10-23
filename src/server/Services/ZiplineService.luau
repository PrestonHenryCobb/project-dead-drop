--!strict
-- Ziplines (spec 4.3, BUILD_ORDER Step 7B pass 2b): ride from the mast at the top down the cable to the post at the
-- bottom. Riding breaks Cover (spec 7.2). The server moves the rider: it anchors their root, slides it down the cable
-- at GameConfig.Traversal.Zipline.Speed, and lets go at the bottom.
--
-- The map tags each end ZiplineAnchor with ZiplineId and End ("Top" or "Bottom"); the cable runs between their tops.
-- SPEC-QUESTION: the Package carrier may not use ziplines (spec 11.2); that check joins when the Package exists (Step 13).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local CoverService = require(script.Parent.CoverService)

type Line = { id: string, top: Vector3, bottom: Vector3, prompt: ProximityPrompt }

local ZiplineService = {}

local config = GameConfig.Traversal.Zipline
local lines: { [string]: Line } = {}
local riding: { [Player]: boolean } = {}

-- The cable is tied to the top of each anchor (a mast or post).
local function cableEnd(anchor: BasePart): Vector3
	return anchor.Position + Vector3.new(0, anchor.Size.Y / 2, 0)
end

local function ride(player: Player, line: Line)
	if riding[player] then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (humanoid and root and root:IsA("BasePart")) or humanoid.Health <= 0 then
		return
	end
	-- The prompt's distance is checked on the client; check it again here.
	local mountDistance = Vector3.new(root.Position.X - line.top.X, 0, root.Position.Z - line.top.Z).Magnitude
	if mountDistance > config.PromptDistance + 2 then
		return
	end
	riding[player] = true
	CoverService.expose(player, "Zipline")
	local hang = Vector3.new(0, -config.HangStuds, 0)
	local from, to = line.top + hang, line.bottom + hang
	local length = (to - from).Magnitude
	local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z).Unit
	root.Anchored = true
	local travelled = 0
	local connection: RBXScriptConnection? = nil
	local function finish()
		if connection then
			connection:Disconnect()
		end
		riding[player] = nil
		if root.Parent then
			root.Anchored = false
			root.AssemblyLinearVelocity = Vector3.zero
		end
	end
	connection = RunService.Heartbeat:Connect(function(dt)
		if not root.Parent or humanoid.Health <= 0 or player.Parent == nil then
			finish()
			return
		end
		travelled = math.min(travelled + config.Speed * dt, length)
		local position = from:Lerp(to, travelled / length)
		root.CFrame = CFrame.lookAt(position, position + flat)
		if travelled >= length then
			finish()
		end
	end)
end

function ZiplineService.Init()
	local ends: { [string]: { top: BasePart?, bottom: BasePart? } } = {}
	for _, anchor in CollectionService:GetTagged(Enums.Tag.ZiplineAnchor) do
		local id = anchor:GetAttribute("ZiplineId")
		local endName = anchor:GetAttribute("End")
		if anchor:IsA("BasePart") and type(id) == "string" then
			ends[id] = ends[id] or {}
			if endName == "Top" then
				ends[id].top = anchor
			elseif endName == "Bottom" then
				ends[id].bottom = anchor
			end
		end
	end
	for id, pair in ends do
		local top, bottom = pair.top, pair.bottom
		if top and bottom then
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "Ride zipline"
			prompt.ObjectText = "Breaks Cover"
			prompt.HoldDuration = config.PromptHoldSeconds
			prompt.MaxActivationDistance = config.PromptDistance
			prompt.RequiresLineOfSight = false
			-- At the foot of the mast, where a rider stands, not at its middle high above them.
			local mount = Instance.new("Attachment")
			mount.Name = "ZiplineMount"
			mount.Position = Vector3.new(0, -top.Size.Y / 2 + config.MountHeight, 0)
			mount.Parent = top
			prompt.Parent = mount
			lines[id] = { id = id, top = cableEnd(top), bottom = cableEnd(bottom), prompt = prompt }
		end
	end
end

function ZiplineService.Start()
	for _, line in lines do
		line.prompt.Triggered:Connect(function(player)
			ride(player, line)
		end)
	end
	Players.PlayerRemoving:Connect(function(player)
		riding[player] = nil
	end)
end

return ZiplineService
