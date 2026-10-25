--!strict
-- The client side of being downed and of reviving or executing (spec 14.1, step 9).
--
--   * Downed: the server lies the body down and moves it; this sends the way the player asks to crawl
--     (MovementController.wantedDirection) Downed.CrawlRequestHz times a second, and plays the same walk and idle
--     animations a downed NPC shows (NPCController), so a crawling player looks like a crawling NPC.
--   * Interact on bodies: while a body lying on the floor is within Downed.InteractStuds and near the crosshair,
--     Interact (held) asks the server to revive or execute it. Every body that lies down is a candidate, player or
--     NPC: the client cannot tell them apart, and the server decides what the hold does.
--   * Roblox's character sound script gives player characters a death sound; NPCs have none, so it is silenced.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local MovementController = require(script.Parent.MovementController)
local RemoteController = require(script.Parent.RemoteController)

local DownedController = {}

local config = GameConfig.Downed
local npcConfig = GameConfig.NPC
local controls = GameConfig.Controls
local localPlayer = Players.LocalPlayer
local INTERACT_ACTION = "CoverStoryInteractBody"
local LYING_UP_Y = 0.5 -- a root whose up vector is flatter than this is lying down
local DEATH_SOUND = "Died" -- the sound Roblox's RbxCharacterSounds adds to a player character

local isDowned = false
local walkTrack: AnimationTrack? = nil
local idleTrack: AnimationTrack? = nil
local lastPosition: Vector3? = nil
local lastSent = Vector3.zero
local sendElapsed = 0
local target: Model? = nil
local holding = false
local bound = false
local bodySight = RaycastParams.new()
bodySight.CollisionGroup = GameConfig.Rig.CollisionGroup
bodySight.RespectCanCollide = true

local function loadTracks(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	local animate = character:FindFirstChild("Animate")
	local walk = animate and animate:FindFirstChild("walk")
	local idle = animate and animate:FindFirstChild("idle")
	local walkAnimation = walk and walk:FindFirstChild("WalkAnim")
	local idleAnimation = idle and idle:FindFirstChild("Animation1")
	if
		animator
		and walkAnimation
		and walkAnimation:IsA("Animation")
		and idleAnimation
		and idleAnimation:IsA("Animation")
	then
		walkTrack = animator:LoadAnimation(walkAnimation)
		idleTrack = animator:LoadAnimation(idleAnimation)
	end
end

local function stopTracks()
	for _, track in { walkTrack, idleTrack } do
		if track then
			track:Stop(npcConfig.AnimationFadeSeconds)
		end
	end
end

local function setDowned(on: boolean)
	isDowned = on
	lastPosition = nil
	lastSent = Vector3.zero
	if on then
		local character = localPlayer.Character
		if character then
			loadTracks(character)
		end
		if idleTrack then
			idleTrack:Play(npcConfig.AnimationFadeSeconds)
		end
	else
		stopTracks()
	end
end

-- While downed: send the crawl direction, and walk-animate at crawl speed like a downed NPC.
local function stepDowned(dt: number)
	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return
	end
	sendElapsed += dt
	if sendElapsed >= 1 / config.CrawlRequestHz then
		sendElapsed = 0
		local want = MovementController.wantedDirection()
		if (want - lastSent).Magnitude > 1e-3 then
			lastSent = want
			RemoteController.fire("RequestCrawl", want)
		end
	end
	local position = root.Position
	local previous = lastPosition
	lastPosition = position
	local walk, idle = walkTrack, idleTrack
	if not (previous and walk and idle and dt > 0) then
		return
	end
	local delta = position - previous
	local speed = Vector3.new(delta.X, 0, delta.Z).Magnitude / dt
	if speed > npcConfig.WalkAnimationMinSpeed then
		if not walk.IsPlaying then
			idle:Stop(npcConfig.AnimationFadeSeconds)
			walk:Play(npcConfig.AnimationFadeSeconds)
		end
		walk:AdjustSpeed(speed / npcConfig.AnimationSpeedReference)
	elseif walk.IsPlaying then
		walk:Stop(npcConfig.AnimationFadeSeconds)
		idle:Play(npcConfig.AnimationFadeSeconds)
	end
end

-- The body lying down nearest the crosshair within reach, if any.
local function findBody(): Model?
	local camera = workspace.CurrentCamera
	local character = localPlayer.Character
	local myRoot = character and character:FindFirstChild("HumanoidRootPart")
	if not (camera and myRoot and myRoot:IsA("BasePart")) then
		return nil
	end
	local look = camera.CFrame.LookVector
	local minDot = math.cos(math.rad(config.BodyAimDegrees))
	local best: Model? = nil
	local bestDot = minDot
	for _, model in workspace:GetChildren() do
		if model:IsA("Model") and model ~= character then
			local root = model:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") and math.abs(root.CFrame.UpVector.Y) < LYING_UP_Y then
				local offset = root.Position - myRoot.Position
				if offset.Magnitude <= config.InteractStuds then
					local dot = (root.Position - camera.CFrame.Position).Unit:Dot(look)
					if dot >= bestDot and workspace:Raycast(myRoot.Position, offset, bodySight) == nil then
						best, bestDot = model, dot
					end
				end
			end
		end
	end
	return best
end

local function onInteract(_: string, state: Enum.UserInputState): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin then
		local body = target
		if body and not isDowned then
			holding = true
			RemoteController.fire("RequestInteract", "Body", body.Name)
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

-- Interact is bound only while there is a body to use it on (spec 24 note: contextual).
local function stepTargeting()
	target = if isDowned then nil else findBody()
	local want = target ~= nil or holding
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

local function silenceDeathSound(instance: Instance)
	if instance.Name == DEATH_SOUND and instance:IsA("Sound") then
		instance.Volume = 0
	end
end

function DownedController.Init() end

-- Ticket 9b-hud: a generic interaction opportunity; only the server tells whether the hold revives or executes.
function DownedController.hasBodyTarget(): boolean
	return not isDowned and target ~= nil
end

function DownedController.Start()
	RemoteController.connect("Downed", function()
		setDowned(true)
	end)
	RemoteController.connect("Revived", function()
		setDowned(false)
	end)
	RemoteController.connect("Eliminated", function()
		setDowned(false)
	end)
	localPlayer.CharacterAdded:Connect(function()
		setDowned(false)
		holding = false
	end)

	for _, descendant in workspace:GetDescendants() do
		silenceDeathSound(descendant)
	end
	workspace.DescendantAdded:Connect(silenceDeathSound)

	local targetElapsed = 0
	RunService.RenderStepped:Connect(function(dt)
		if isDowned then
			stepDowned(dt)
		end
		targetElapsed += dt
		if targetElapsed >= 1 / config.CrawlRequestHz then
			targetElapsed = 0
			stepTargeting()
		end
	end)
end

return DownedController
