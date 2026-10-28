--!strict
-- The client side of being downed and of reviving or executing (spec 14.1, step 9).
--
--   * Downed: the server lies the body down and moves it; this sends the way the player asks to crawl
--     (MovementController.wantedDirection) Downed.CrawlRequestHz times a second, and plays the same down poses a
--     downed NPC shows (R4-body-animation, Util/Knockdown and Defs/PoseDefs): the fall the server chose, then lying or
--     crawling on the front or back, then the settle into death. They play on this player's own Animator, so every
--     other client sees them, exactly as it sees an NPC's.
--   * Interact on bodies: while a body lying on the floor is within Downed.InteractStuds and near the crosshair,
--     Interact (held) asks the server to revive or execute it. Every body that lies down is a candidate, player or
--     NPC: the client cannot tell them apart, and the server decides what the hold does.
--   * Roblox's character sound script gives player characters a death sound; NPCs have none, so it is silenced.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Knockdown = require(Shared:WaitForChild("Util"):WaitForChild("Knockdown"))
local PoseAnimation = require(Shared:WaitForChild("Util"):WaitForChild("PoseAnimation"))
local Types = require(Shared:WaitForChild("Types"))
local Janitor = require(Shared:WaitForChild("Util"):WaitForChild("Janitor"))
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
local eliminated = false
local phase: Types.Phase = "Lobby"
local focused = true
local extractionFrozen = false
local animationGeneration = 0
local deathThread: thread? = nil
local fall: Knockdown.Fall = "Forward"
local posture: Knockdown.Posture = "Prone"
local fallEndsAt = 0 -- os.clock(): the fall pose plays until then, then lying or crawling
local tracks: { [string]: AnimationTrack } = {}
local playing: AnimationTrack? = nil
local playingName = ""
local lastPosition: Vector3? = nil
local lastSent = Vector3.zero
local sendElapsed = 0
local target: Model? = nil
local holding = false
local bound = false
local bodySight = RaycastParams.new()
bodySight.CollisionGroup = GameConfig.Rig.CollisionGroup
bodySight.RespectCanCollide = true

-- Plays one down pose on this player's character, fading out the last.
local function play(name: string)
	if name == playingName then
		return
	end
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	local animation = PoseAnimation.registerAll()[name]
	if not (animator and animation) then
		return
	end
	local track = tracks[name]
	if not track then
		track = animator:LoadAnimation(animation)
		tracks[name] = track
	end
	if playing then
		playing:Stop(npcConfig.AnimationFadeSeconds)
	end
	track:Play(npcConfig.AnimationFadeSeconds)
	playing, playingName = track, name
end

local function stopAll()
	if deathThread then
		task.cancel(deathThread)
		deathThread = nil
	end
	for _, track in tracks do
		track:Stop(npcConfig.AnimationFadeSeconds)
		track:Destroy()
	end
	animationGeneration += 1
	table.clear(tracks)
	playing, playingName = nil, ""
end

local function onDowned(info: Types.DownedInfo)
	isDowned = true
	lastPosition = nil
	lastSent = Vector3.zero
	fall = info.Fall :: Knockdown.Fall
	posture = info.Posture :: Knockdown.Posture
	fallEndsAt = os.clock() + config.Knockdown.Seconds
	play(Knockdown.animation("Knockdown", fall, posture))
end

local function onEliminated(info: Types.EliminatedInfo?)
	isDowned = false
	eliminated = true
	if deathThread then
		task.cancel(deathThread)
		deathThread = nil
	end
	if not info then
		return
	end
	fall = info.Fall :: Knockdown.Fall
	posture = info.Posture :: Knockdown.Posture
	local dead = Knockdown.animation("Dead", fall, posture)
	local falling = Knockdown.animation("Knockdown", fall, posture)
	if info.FromStanding then
		-- Solos: no downed state, so the fall plays first.
		fallEndsAt = os.clock() + config.Knockdown.Seconds
		play(falling)
	end
	local fallLeft = fallEndsAt - os.clock()
	if fallLeft > 0 then
		local generation = animationGeneration
		-- Still falling (Solos, or a team wipe straight after going down): settle at the end of the fall.
		deathThread = task.delay(fallLeft, function()
			deathThread = nil
			if generation == animationGeneration and eliminated and playingName == falling then
				play(dead)
			end
		end)
	else
		play(dead)
	end
end

local function onUp()
	isDowned = false
	stopAll()
end

local function activePhase(): boolean
	return phase == "Infiltration" or phase == "VaultBreach" or phase == "PackageHeist" or phase == "Overtime"
end

local function usable(): boolean
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return activePhase()
		and not isDowned
		and not eliminated
		and not extractionFrozen
		and focused
		and UserInputService:GetFocusedTextBox() == nil
		and humanoid ~= nil
		and humanoid.Health > 0
		and root ~= nil
		and root:IsA("BasePart")
end

local function cancelHold()
	if holding then
		holding = false
		RemoteController.fire("RequestInteractCancel")
	end
end

-- While downed: send the crawl direction, and lie or crawl like a downed NPC once the fall has played.
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
	if os.clock() < fallEndsAt or not previous or dt <= 0 then
		return
	end
	local delta = position - previous
	local moving = Vector3.new(delta.X, 0, delta.Z).Magnitude / dt > npcConfig.WalkAnimationMinSpeed
	play(Knockdown.animation("Down", fall, posture, moving))
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
		local body = if usable() then findBody() else nil
		if body then
			holding = true
			RemoteController.fire("RequestInteract", "Body", body.Name)
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

-- Interact is bound only while there is a body to use it on (spec 24 note: contextual).
local function stepTargeting()
	local allowed = usable() and workspace.CurrentCamera ~= nil
	if not allowed then
		cancelHold()
	end
	target = if allowed then findBody() else nil
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
	return usable() and target ~= nil
end

function DownedController.Start()
	local janitor = Janitor.new()
	janitor:Add(RemoteController.connect("Downed", function(info: Types.DownedInfo)
		onDowned(info)
		stepTargeting()
	end))
	janitor:Add(RemoteController.connect("Revived", function()
		onUp()
		stepTargeting()
	end))
	janitor:Add(RemoteController.connect("Eliminated", function(info: Types.EliminatedInfo?)
		onEliminated(info)
		stepTargeting()
	end))
	janitor:Add(RemoteController.connect("PhaseChanged", function(nextPhase: Types.Phase)
		phase = nextPhase
		if nextPhase == "Lobby" or nextPhase == "Insertion" then
			extractionFrozen = false
		end
		if not activePhase() then
			stopAll()
		end
		stepTargeting()
	end))
	janitor:Add(RemoteController.connect("ExtractionState", function(info: Types.ExtractionStateInfo)
		extractionFrozen = info.State == "Extracted"
		stepTargeting()
	end))
	janitor:Add(RemoteController.connect("InteractState", function(info: Types.InteractStateInfo)
		if not info.Active and (info.Kind == "Revive" or info.Kind == "Execute") then
			holding = false
			stepTargeting()
		end
	end))
	janitor:Add(localPlayer.CharacterAdded:Connect(function()
		cancelHold()
		eliminated = false
		onUp()
		stepTargeting()
	end))
	janitor:Add(UserInputService.TextBoxFocused:Connect(stepTargeting))
	janitor:Add(UserInputService.WindowFocusReleased:Connect(function()
		focused = false
		stepTargeting()
	end))
	janitor:Add(UserInputService.WindowFocused:Connect(function()
		focused = true
		stepTargeting()
	end))

	for _, descendant in workspace:GetDescendants() do
		silenceDeathSound(descendant)
	end
	janitor:Add(workspace.DescendantAdded:Connect(silenceDeathSound))

	local targetElapsed = 0
	janitor:Add(RunService.RenderStepped:Connect(function(dt)
		if isDowned and activePhase() and not extractionFrozen then
			stepDowned(dt)
		end
		targetElapsed += dt
		if targetElapsed >= 1 / config.CrawlRequestHz then
			targetElapsed = 0
			stepTargeting()
		end
	end))
	janitor:Add(function()
		cancelHold()
		ContextActionService:UnbindAction(INTERACT_ACTION)
		bound, target = false, nil
		isDowned, eliminated = false, true
		stopAll()
	end)
	janitor:Add(script.Destroying:Connect(function()
		janitor:Destroy()
	end))
end

return DownedController
