--!strict
-- Draws the crowd smoothly (spec 25.4). The server moves each NPC's anchored root at GameConfig.NPC.ServerTickHz;
-- this controller renders every NPC slightly in the past (InterpolationDelay), blending between the two server
-- updates around that moment, and plays the same walk and idle animations a player's Animate script uses, at the
-- same speed scaling, so a walking NPC and a walking player look the same.
--
-- An NPC rig is a Model whose animation runs through an AnimationController (players have a Humanoid instead).

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Janitor = require(Shared:WaitForChild("Util"):WaitForChild("Janitor"))

type Sample = { time: number, cframe: CFrame }

type Entry = {
	root: BasePart,
	walk: AnimationTrack,
	idle: AnimationTrack,
	samples: { Sample },
	written: CFrame?,
	speed: number,
	walking: boolean,
	janitor: Janitor.Janitor,
}

local NPCController = {}

local config = GameConfig.NPC
local MAX_SAMPLES = 4
local STALE_SECONDS = 0.5 -- no update for this long means the NPC is standing still

local entries: { [Model]: Entry } = {}

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

	entries[model] = {
		root = root,
		walk = walk,
		idle = idle,
		samples = { { time = os.clock(), cframe = root.CFrame } },
		written = nil,
		speed = 0,
		walking = false,
		janitor = janitor,
	}
	janitor:Add(model.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			entries[model] = nil
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

	local renderTime = now - config.InterpolationDelay
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
	for _, child in workspace:GetChildren() do
		consider(child)
	end
	workspace.ChildAdded:Connect(function(child)
		-- The rig replicates as a whole, but give its children a frame to arrive.
		task.defer(consider, child)
	end)

	RunService.RenderStepped:Connect(function()
		local started = os.clock()
		for _, entry in entries do
			update(entry, started)
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
