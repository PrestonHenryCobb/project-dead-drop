--!strict
-- Draws the crowd (spec 25.4). The server moves each NPC's anchored root at GameConfig.NPC.ServerTickHz; this
-- controller renders every NPC slightly in the past (InterpolationDelay), blending between the two server updates
-- around that moment, and plays the same walk and idle animations a player's Animate script uses, at the same speed
-- scaling, so a walking NPC and a walking player look the same. The moment drawn moves in steps on the server clock
-- (step 8B.6, PositionStep), exactly as other players are drawn, and the server rewinds shots to the same moment.
--
-- It also plays the animation the server says each NPC is doing (NPCAnimation: a node activity, cowering, gasping) and
-- gives every idle NPC a quick random glance to one side now and then (spec 8.1).
--
-- An NPC rig is a Model whose animation runs through an AnimationController (players have a Humanoid instead).

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Enums = require(Shared:WaitForChild("Enums"))
local Janitor = require(Shared:WaitForChild("Util"):WaitForChild("Janitor"))
local PoseAnimation = require(Shared:WaitForChild("Util"):WaitForChild("PoseAnimation"))
local PositionStep = require(Shared:WaitForChild("Util"):WaitForChild("PositionStep"))
local RemoteController = require(script.Parent.RemoteController)

type Sample = { time: number, cframe: CFrame } -- time: server clock, when the update arrived

type Entry = {
	root: BasePart,
	animator: Animator,
	walk: AnimationTrack,
	idle: AnimationTrack,
	poses: { [string]: AnimationTrack }, -- pose animations loaded so far
	pose: string, -- the pose the server asked for ("" for none)
	nextGlance: number,
	samples: { Sample },
	written: CFrame?,
	speed: number,
	walking: boolean,
	culled: boolean, -- too far away to be worth animating; its tracks are stopped until it comes back
	janitor: Janitor.Janitor,
}

local NPCController = {}

local config = GameConfig.NPC
local MAX_SAMPLES = 4
local STALE_SECONDS = 0.5 -- no update for this long means the NPC is standing still

local entries: { [Model]: Entry } = {}
local byId: { [string]: Entry } = {} -- the server names each NPC's model; that name is how it addresses it
local wanted: { [string]: string } = {} -- poses that arrived before the NPC's rig was ready
local poseAnimations: { [string]: Animation } = {}
local rng = Random.new()

local function glanceDelay(): number
	return rng:NextNumber(config.GlanceInterval.Min, config.GlanceInterval.Max)
end

local function poseTrack(entry: Entry, name: string): AnimationTrack?
	local loaded = entry.poses[name]
	if loaded then
		return loaded
	end
	local animation = poseAnimations[name]
	if not animation then
		return nil
	end
	local track = entry.animator:LoadAnimation(animation)
	entry.poses[name] = track
	entry.janitor:Add(track)
	return track
end

local function setPose(entry: Entry, name: string)
	if entry.pose == name then
		return
	end
	local fade = config.AnimationFadeSeconds
	local previous = entry.poses[entry.pose]
	if previous then
		previous:Stop(fade)
	end
	entry.pose = name
	local track = if name == "" then nil else poseTrack(entry, name)
	if track then
		track:Play(fade)
	end
end

local function animation(model: Model, folderName: string, animationName: string): Animation?
	local animate = model:FindFirstChild("Animate")
	local folder = animate and animate:FindFirstChild(folderName)
	local found = folder and folder:FindFirstChild(animationName)
	return if found and found:IsA("Animation") then found else nil
end

local function track(model: Model)
	if entries[model] then
		return
	end
	local controller = model:FindFirstChildOfClass("AnimationController")
	local animator = controller and controller:FindFirstChildOfClass("Animator")
	local root = model:FindFirstChild("HumanoidRootPart")
	local walkAnimation = animation(model, "walk", "WalkAnim")
	local idleAnimation = animation(model, "idle", "Animation1")
	if not (animator and root and root:IsA("BasePart") and walkAnimation and idleAnimation) then
		return
	end

	local janitor = Janitor.new()
	local walk = animator:LoadAnimation(walkAnimation)
	local idle = animator:LoadAnimation(idleAnimation)
	janitor:Add(walk)
	janitor:Add(idle)
	idle:Play()

	local entry: Entry = {
		root = root,
		animator = animator,
		walk = walk,
		idle = idle,
		poses = {},
		pose = "",
		nextGlance = workspace:GetServerTimeNow() + glanceDelay(),
		samples = { { time = workspace:GetServerTimeNow(), cframe = root.CFrame } },
		written = nil,
		speed = 0,
		walking = false,
		culled = false,
		janitor = janitor,
	}
	entries[model] = entry
	byId[model.Name] = entry
	local pending = wanted[model.Name]
	if pending then
		wanted[model.Name] = nil
		setPose(entry, pending)
	end
	janitor:Add(model.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			entries[model] = nil
			byId[model.Name] = nil
			janitor:Destroy()
		end
	end))
end

local function consider(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	if instance:FindFirstChildOfClass("AnimationController") then
		track(instance)
	end
end

-- A CFrame read back after setting it is re-normalised, so exact comparison would treat every frame as a new
-- server update. Anything within this tolerance of what we drew is still our own value.
local SAME_POSITION = 1e-3
local SAME_FACING = 0.99999

local function isOwnWrite(current: CFrame, written: CFrame?): boolean
	return written ~= nil
		and (current.Position - written.Position).Magnitude < SAME_POSITION
		and current.LookVector:Dot(written.LookVector) > SAME_FACING
end

local function update(entry: Entry, now: number)
	local samples = entry.samples
	local current = entry.root.CFrame
	local moved = not isOwnWrite(current, entry.written)
	if moved then
		-- The server moved it since we last drew it.
		table.insert(samples, { time = now, cframe = current })
		if #samples > MAX_SAMPLES then
			table.remove(samples, 1)
		end
	end

	local renderTime = PositionStep.snap(now) - config.InterpolationDelay
	if not moved and not entry.walking and entry.written and renderTime >= samples[#samples].time then
		-- Standing still and already drawn at the server's latest position: nothing to do this frame.
		return
	end
	local drawn = samples[#samples].cframe
	for index = #samples - 1, 1, -1 do
		local older, newer = samples[index], samples[index + 1]
		if renderTime >= older.time then
			local alpha = math.clamp((renderTime - older.time) / (newer.time - older.time), 0, 1)
			drawn = older.cframe:Lerp(newer.cframe, alpha)
			break
		end
		drawn = older.cframe
	end
	entry.root.CFrame = drawn
	entry.written = drawn

	local speed = 0
	local count = #samples
	if count >= 2 and now - samples[count].time < STALE_SECONDS then
		local a, b = samples[count - 1], samples[count]
		local delta = b.cframe.Position - a.cframe.Position
		speed = Vector3.new(delta.X, 0, delta.Z).Magnitude / math.max(b.time - a.time, 1e-3)
	end
	entry.speed = speed

	if now >= entry.nextGlance then
		entry.nextGlance = now + glanceDelay()
		if entry.pose == "" then
			local name = if rng:NextInteger(0, 1) == 0
				then Enums.NpcAnimation.GlanceLeft
				else Enums.NpcAnimation.GlanceRight
			local glance = poseTrack(entry, name)
			if glance then
				glance:Play(config.AnimationFadeSeconds)
			end
		end
	end

	local fade = config.AnimationFadeSeconds
	if speed > config.WalkAnimationMinSpeed then
		if not entry.walking then
			entry.walking = true
			entry.idle:Stop(fade)
			entry.walk:Play(fade)
		end
		entry.walk:AdjustSpeed(speed / config.AnimationSpeedReference)
	elseif entry.walking then
		entry.walking = false
		entry.walk:Stop(fade)
		entry.idle:Play(fade)
	end
end

local frameTotal, frameCount, reportAt = 0, 0, 0

function NPCController.Init() end

function NPCController.Start()
	poseAnimations = PoseAnimation.registerAll()
	RemoteController.connect("NPCAnimation", function(changes: { { id: string, animation: string } })
		for _, change in changes do
			local entry = byId[change.id]
			if entry then
				setPose(entry, change.animation)
			else
				wanted[change.id] = change.animation
			end
		end
	end)

	for _, child in workspace:GetChildren() do
		consider(child)
	end
	workspace.ChildAdded:Connect(function(child)
		-- The rig replicates as a whole, but give its children a frame to arrive.
		task.defer(consider, child)
	end)

	RunService.RenderStepped:Connect(function()
		local started = os.clock()
		-- Samples and the drawn moment are on the server clock, so every client steps on the same beat (step 8B.6).
		local serverNow = workspace:GetServerTimeNow()
		local camera = workspace.CurrentCamera
		local cameraPosition = if camera then camera.CFrame.Position else nil
		local cullSquared = config.AnimationCullStuds * config.AnimationCullStuds
		for _, entry in entries do
			-- Far NPCs are not animated at all: the animator is the biggest cost of a crowd, and at this distance nobody
			-- can see it.
			local far = false
			if cameraPosition then
				local offset = entry.root.Position - cameraPosition
				far = offset:Dot(offset) > cullSquared
			end
			if far then
				if not entry.culled then
					entry.culled = true
					entry.walking = false
					entry.walk:Stop(0)
					entry.idle:Stop(0)
					for _, loaded in entry.poses do
						loaded:Stop(0)
					end
				end
			else
				if entry.culled then
					entry.culled = false
					entry.idle:Play(0)
					local resumed = entry.poses[entry.pose]
					if resumed then
						resumed:Play(0)
					end
				end
				update(entry, serverNow)
			end
		end

		if GameConfig.Debug.PrintNpcCost then
			frameTotal += (os.clock() - started) * 1000
			frameCount += 1
			if started >= reportAt then
				if reportAt > 0 and frameCount > 0 then
					local count = 0
					for _ in entries do
						count += 1
					end
					print(
						string.format(
							"[NPCController] %d NPCs: frame avg %.3f ms (%d frames)",
							count,
							frameTotal / frameCount,
							frameCount
						)
					)
				end
				frameTotal, frameCount = 0, 0
				reportAt = started + GameConfig.Debug.CostReportSeconds
			end
		end
	end)
end

return NPCController
