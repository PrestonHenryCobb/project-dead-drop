--!strict
-- Ticket crowd-readability: the same proximity head animation on every visible upright rig.
-- No player/team/agent attributes, replicated effects or client changes to authoritative movement.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)
local Janitor = require(Shared.Util.Janitor)
local PoseAnimation = require(Shared.Util.PoseAnimation)
local config = GameConfig.NPC.SocialGlance
local SocialGlanceController = {}
local janitor = Janitor.new()
local rng = Random.new()

type Entry = {
	root: BasePart,
	head: BasePart,
	animator: Animator,
	humanoid: Humanoid?,
	left: AnimationTrack,
	right: AnimationTrack,
	nextAt: number,
	nextAmbient: number,
	janitor: Janitor.Janitor,
}
local entries: { [Model]: Entry } = {}
local animations: { [string]: Animation } = {}
local rayParams = RaycastParams.new()
rayParams.CollisionGroup = GameConfig.Rig.CollisionGroup
rayParams.RespectCanCollide = true

local function track(model: Model)
	if entries[model] then
		return
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	local head = model:FindFirstChild("Head")
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local controller = humanoid or model:FindFirstChildOfClass("AnimationController")
	local animator = controller and controller:FindFirstChildOfClass("Animator")
	if not (root and root:IsA("BasePart") and head and head:IsA("BasePart") and animator) then
		return
	end
	local cleanup = Janitor.new()
	local left = animator:LoadAnimation(animations.GlanceLeft)
	local right = animator:LoadAnimation(animations.GlanceRight)
	cleanup:Add(left)
	cleanup:Add(right)
	entries[model] = {
		root = root,
		head = head,
		animator = animator,
		humanoid = humanoid,
		left = left,
		right = right,
		nextAt = os.clock() + rng:NextNumber(0, config.ScanSeconds),
		nextAmbient = os.clock() + rng:NextNumber(GameConfig.NPC.GlanceInterval.Min, GameConfig.NPC.GlanceInterval.Max),
		janitor = cleanup,
	}
	cleanup:Add(model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(workspace) then
			entries[model] = nil
			cleanup:Destroy()
		end
	end))
end

local function consider(instance: Instance)
	local model = if instance:IsA("Model") then instance else instance:FindFirstAncestorOfClass("Model")
	if model then
		track(model)
	end
end

local function available(entry: Entry): boolean
	if entry.root.CFrame.UpVector.Y < config.UprightDot or (entry.humanoid and entry.humanoid.Health <= 0) then
		return false
	end
	-- Activity, panic, knockdown and takedown animations take precedence over social gestures.
	for _, active in entry.animator:GetPlayingAnimationTracks() do
		if
			active ~= entry.left
			and active ~= entry.right
			and active.Priority ~= Enum.AnimationPriority.Core
			and active.Priority.Value >= Enum.AnimationPriority.Action.Value
		then
			return false
		end
	end
	return true
end

local function scan()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local now = os.clock()
	for model, entry in entries do
		local position = entry.root.Position
		local visible = (position - camera.CFrame.Position).Magnitude <= config.RenderStuds
		-- Own head remains camera-controlled; all other rigs follow exactly the same presentation rules.
		if not visible or model == Players.LocalPlayer.Character or not available(entry) then
			entry.left:Stop(GameConfig.NPC.AnimationFadeSeconds)
			entry.right:Stop(GameConfig.NPC.AnimationFadeSeconds)
		elseif now >= entry.nextAt then
			local nearest: Entry? = nil
			local distance = config.NearStuds
			for otherModel, other in entries do
				if otherModel ~= model and other.root.CFrame.UpVector.Y >= config.UprightDot then
					local delta = other.root.Position - position
					local length = delta.Magnitude
					if
						length > 0
						and length < distance
						and math.abs(delta.Y) <= config.HeightStuds
						and entry.root.CFrame.LookVector:Dot(delta.Unit) >= config.FrontDot
						and not workspace:Raycast(
							entry.head.Position,
							other.head.Position - entry.head.Position,
							rayParams
						)
					then
						nearest, distance = other, length
					end
				end
			end
			if nearest or now >= entry.nextAmbient then
				local side = if nearest
					then entry.root.CFrame.RightVector:Dot(nearest.root.Position - position)
					else rng:NextNumber(-1, 1)
				local glance = if side >= 0 then entry.right else entry.left
				glance:Play(GameConfig.NPC.AnimationFadeSeconds)
				entry.nextAt = now + rng:NextNumber(config.Cooldown.Min, config.Cooldown.Max)
				entry.nextAmbient = now
					+ rng:NextNumber(GameConfig.NPC.GlanceInterval.Min, GameConfig.NPC.GlanceInterval.Max)
			end
		end
	end
end

function SocialGlanceController.Init() end

function SocialGlanceController.Start()
	animations = PoseAnimation.registerAll()
	for _, instance in workspace:GetDescendants() do
		if instance:IsA("Animator") then
			consider(instance)
		end
	end
	janitor:Add(workspace.DescendantAdded:Connect(function(instance)
		if instance:IsA("Animator") or instance.Name == "Head" or instance.Name == "HumanoidRootPart" then
			task.defer(consider, instance)
		end
	end))
	local elapsed = 0
	janitor:Add(RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= config.ScanSeconds then
			elapsed %= config.ScanSeconds
			scan()
		end
	end))
	janitor:Add(script.Destroying:Connect(function()
		for model, entry in entries do
			entries[model] = nil
			entry.janitor:Destroy()
		end
		janitor:Destroy()
	end))
end

return SocialGlanceController
