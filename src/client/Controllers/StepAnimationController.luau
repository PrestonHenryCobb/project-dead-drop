--!strict
-- The low-frame-rate look (STYLE_QUESTIONS D1, set to about 8 steps a second on request: a chunky, snapping gait where
-- limbs jump between poses instead of gliding). Every character gets it, players and NPCs alike, so nobody stands out.
--
-- How: every frame, after the Animator has posed a rig and before physics uses the pose, each joint's Transform is
-- replaced by a copy taken a moment ago. A fresh copy is taken StepHz times a second. Only the pose is held; where a
-- character is, how fast it moves and which way it faces stay smooth, and nothing about gameplay changes.
--
-- Characters further than StepCullStuds from the camera are left alone, since the steps cannot be seen there and holding
-- 15 joints per character every frame is the cost. Each character's steps start at a random moment so a crowd does not
-- all jump at once.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

type Entry = {
	root: BasePart,
	joints: { Motor6D | AnimationConstraint },
	held: { CFrame },
	hasHeld: boolean,
	nextStep: number,
	skip: { [number]: boolean }, -- joints this client poses itself (its own neck)
}

local StepAnimationController = {}

local config = GameConfig.Animation
local localPlayer = Players.LocalPlayer
local rng = Random.new()
local interval = 1 / config.StepHz

local entries: { [Model]: Entry } = {}

local function build(model: Model)
	if entries[model] then
		return
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return
	end
	local joints: { Motor6D | AnimationConstraint } = {}
	for _, descendant in model:GetDescendants() do
		-- Ticket 8.12: RigService uses classic joints for both NPCs and players.
		if descendant:IsA("Motor6D") or descendant:IsA("AnimationConstraint") then
			table.insert(joints, descendant)
		end
	end
	if #joints < config.MinJoints then
		return -- the rig has not fully arrived yet; the next sweep tries again
	end
	local skip: { [number]: boolean } = {}
	if model == localPlayer.Character then
		for index, joint in joints do
			local part = if joint:IsA("Motor6D") then joint.Part1 else nil
			if joint.Name == "Neck" or (part and (string.find(part.Name, "Arm") or string.find(part.Name, "Hand"))) then
				skip[index] = true -- FacingController owns the neck; FirstPersonBodyController steps real arm poses.
			end
		end
	end
	entries[model] = {
		root = root,
		joints = joints,
		held = table.create(#joints, CFrame.identity),
		hasHeld = false,
		nextStep = os.clock() + rng:NextNumber(0, interval),
		skip = skip,
	}
	model.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			entries[model] = nil
		end
	end)
end

local function isCharacter(instance: Instance): boolean
	return instance:IsA("Model")
		and (
			instance:FindFirstChildOfClass("Humanoid") ~= nil
			or instance:FindFirstChildOfClass("AnimationController") ~= nil
		)
end

local function sweep()
	for _, child in workspace:GetChildren() do
		if isCharacter(child) then
			build(child :: Model)
		end
	end
end

function StepAnimationController.Init() end

function StepAnimationController.Start()
	sweep()
	workspace.ChildAdded:Connect(function(child)
		task.defer(function()
			if isCharacter(child) then
				build(child :: Model)
			end
		end)
	end)
	-- Catches rigs whose parts arrive after the model does.
	task.spawn(function()
		while true do
			task.wait(2)
			sweep()
		end
	end)

	local cullSquared = config.StepCullStuds * config.StepCullStuds
	RunService.PreSimulation:Connect(function()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local cameraPosition = camera.CFrame.Position
		local now = os.clock()
		for _, entry in entries do
			local offset = entry.root.Position - cameraPosition
			if offset:Dot(offset) > cullSquared then
				entry.hasHeld = false
			elseif not entry.hasHeld or now >= entry.nextStep then
				-- Take a new pose now.
				for index, joint in entry.joints do
					entry.held[index] = joint.Transform
				end
				entry.hasHeld = true
				entry.nextStep += interval
				if entry.nextStep < now then
					entry.nextStep = now + interval
				end
			else
				-- Hold the last one.
				for index, joint in entry.joints do
					if not entry.skip[index] then
						joint.Transform = entry.held[index]
					end
				end
			end
		end
	end)
end

return StepAnimationController
