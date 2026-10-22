--!strict
-- Cover, suspicion, trespass and exposure (spec 7, with the decisions in STEP7_QUESTIONS.md).
--
-- Every player is Covered, Suspicious or Exposed. The server owns all of it and tells only the player concerned; what
-- enemies learn is limited to the ExposedPing and what they can see (spec 25.7).
--
--   * Witnesses: every NPC (and, later, camera) that can see the player: within WitnessRange, inside the field of view,
--     and with nothing but characters between them. Their shares add up (Security 1, camera 0.6, other NPC 0.2) but
--     never count for more than WitnessCap.
--   * Suspicion: each suspicious action fills the meter by its rate times the witnesses' total share. Nothing fills it
--     if nobody sees. It starts to drain after SuspicionDecayDelay of nothing witnessed.
--   * Trespass: standing in a zone above the disguise's clearance is one more action, at TrespassGainPerSecond times a
--     multiplier by how many tiers over.
--   * Exposure: at 100 percent, or when another system calls expose(). The disguise is stripped (DisguiseService),
--     enemies within ExposedPingRadius get a ping, and the alarm level rises if it was the meter.
--   * Re-covering: allowed once the combat lockout and any minimum exposed time are over, no Security NPC has seen the
--     player for ReCoverTrackingSeconds, and the zone is at or below the disguise's tier.
--
--   CoverService.expose(player, reason, minExposedSeconds?)   cover-breaking actions (spec 7.2) call this
--   CoverService.startLockout(player)                         starts or refreshes the combat lockout (spec 7.6)
--   CoverService.onNpcKilled(player)                          a player killed an NPC (spec 5.5, 7.2 #11)
--   CoverService.isExposed(player)
--   CoverService.setSources(sources)                          NPCService tells us who can see, and where bodies are

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Types = require(Shared:WaitForChild("Types"))
local DisguiseService = require(script.Parent.DisguiseService)
local RemoteService = require(script.Parent.RemoteService)
local ZoneService = require(script.Parent.ZoneService)

-- Something that can see players: an NPC (and later a camera), reduced to where it looks from and what it counts as.
export type Witness = {
	position: Vector3, -- the eyes
	look: Vector3, -- unit vector the witness faces
	kind: "Security" | "Camera" | "Npc",
}

export type Sources = {
	witnesses: () -> { Witness },
	bodies: () -> { Vector3 },
}

type State = {
	cover: Types.CoverState,
	suspicion: number,
	lastSuspiciousAt: number,
	lockoutUntil: number,
	exposedMinUntil: number,
	lastSeenBySecurity: number,
	pendingJumps: number,
	-- what was last sent, so only changes go over the network
	sentCover: string,
	sentCanRecover: boolean,
	sentBlocker: string,
	sentLockoutActive: boolean,
	sentSuspicion: number,
	sentSecurity: number,
	sentNpc: number,
	sentCamera: number,
	sentRestricted: boolean,
	sentZoneTier: number,
	sentClearance: number,
}

local CoverService = {}

local config = GameConfig.Cover
local states: { [Player]: State } = {}
local sources: Sources? = nil
local alarmLevel = 0
local accumulator = 0
local lastTick = os.clock()

-- Rays in the character group skip characters, so only the map blocks sight (STEP7_QUESTIONS A3).
local sightParams = RaycastParams.new()
sightParams.CollisionGroup = GameConfig.Rig.CollisionGroup
sightParams.RespectCanCollide = true -- an open door does not block sight

function CoverService.setSources(newSources: Sources)
	sources = newSources
end

local function aliveRoot(player: Player): (Humanoid?, BasePart?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return humanoid, root
	end
	return nil, nil
end

local function newState(): State
	return {
		cover = "Covered",
		suspicion = 0,
		lastSuspiciousAt = 0,
		lockoutUntil = 0,
		exposedMinUntil = 0,
		lastSeenBySecurity = -math.huge,
		pendingJumps = 0,
		sentCover = "",
		sentCanRecover = false,
		sentBlocker = "",
		sentLockoutActive = false,
		sentSuspicion = -1,
		sentSecurity = -1,
		sentNpc = -1,
		sentCamera = -1,
		sentRestricted = false,
		sentZoneTier = -1,
		sentClearance = -1,
	}
end

function CoverService.isExposed(player: Player): boolean
	local state = states[player]
	return state ~= nil and state.cover == "Exposed"
end

local function isLockedOut(state: State, now: number): boolean
	return now < state.lockoutUntil
end

-- What stops an Exposed player re-covering right now (spec 7.5), or "" if nothing does. The client shows it so the
-- reason is never a guess.
local function recoverBlocker(player: Player, now: number): string
	local state = states[player]
	local _, root = aliveRoot(player)
	if not (state and root) or state.cover ~= "Exposed" then
		return ""
	end
	if isLockedOut(state, now) then
		return "Lockout"
	elseif now < state.exposedMinUntil then
		return "Minimum"
	elseif now - state.lastSeenBySecurity < config.ReCoverTrackingSeconds then
		return "Seen"
	elseif ZoneService.tierAt(root.Position) > DisguiseService.getDisguiseTier(player) then
		return "Zone"
	end
	return ""
end

local function canRecover(player: Player, now: number): boolean
	local state = states[player]
	return state ~= nil and state.cover == "Exposed" and recoverBlocker(player, now) == ""
end

local function sendCover(player: Player, state: State, now: number)
	local info: Types.CoverInfo = {
		State = state.cover,
		CanRecover = canRecover(player, now),
		Blocker = recoverBlocker(player, now),
		LockoutSeconds = math.max(0, state.lockoutUntil - now),
		ExposedMinSeconds = math.max(0, state.exposedMinUntil - now),
	}
	state.sentCover = state.cover
	state.sentCanRecover = info.CanRecover
	state.sentBlocker = info.Blocker
	state.sentLockoutActive = info.LockoutSeconds > 0
	RemoteService.fireClient("CoverStateChanged", player, info)
end

-- Enemies within ExposedPingRadius get a ping where the player was exposed (spec 7.2). Until teams exist (Step 10),
-- every other player is an enemy.
local function pingEnemies(exposed: Player, position: Vector3)
	for _, other in Players:GetPlayers() do
		if other ~= exposed then
			local _, root = aliveRoot(other)
			if root and (root.Position - position).Magnitude <= config.ExposedPingRadius then
				RemoteService.fireClient(
					"ExposedPing",
					other,
					{ Position = position, Seconds = config.ExposedPingSeconds }
				)
			end
		end
	end
end

function CoverService.expose(player: Player, reason: string, minExposedSeconds: number?)
	local state = states[player]
	local _, root = aliveRoot(player)
	if not state or not root then
		return
	end
	local now = os.clock()
	if minExposedSeconds then
		state.exposedMinUntil = math.max(state.exposedMinUntil, now + minExposedSeconds)
	end
	if state.cover == "Exposed" then
		return
	end
	state.cover = "Exposed"
	state.suspicion = 0
	if GameConfig.Debug.TestEvents then
		print(`[CoverService] {player.Name} exposed: {reason}`)
	end
	DisguiseService.expose(player)
	pingEnemies(player, root.Position)
	sendCover(player, state, now)
end

function CoverService.startLockout(player: Player)
	local state = states[player]
	if not state then
		return
	end
	local now = os.clock()
	state.lockoutUntil = now + config.CombatLockout
	sendCover(player, state, now)
end

-- Spec 5.5, 7.2 #11: killing a civilian exposes the killer for at least ExposedSeconds. The Funds penalty and the
-- alarm rise belong to the economy and alarm steps.
function CoverService.onNpcKilled(player: Player)
	CoverService.expose(player, "KilledNpc", GameConfig.NPC.CivilianKill.ExposedSeconds)
end

local function onRecovered(player: Player)
	local state = states[player]
	if not state then
		return
	end
	state.cover = "Covered"
	state.suspicion = 0 -- STEP7_QUESTIONS B4
	state.lastSuspiciousAt = os.clock()
	sendCover(player, state, os.clock())
end

-- Does a witness see this point? Range, field of view, then one ray.
local function sees(witness: Witness, target: Vector3): boolean
	local offset = target - witness.position
	local distance = offset.Magnitude
	if distance > config.WitnessRange then
		return false
	end
	if distance > 1e-3 then
		local halfFov = math.rad(config.WitnessFov / 2)
		if math.acos(math.clamp(witness.look:Dot(offset / distance), -1, 1)) > halfFov then
			return false
		end
	end
	return workspace:Raycast(witness.position, offset, sightParams) == nil
end

-- Spec 7.3: what each witness is worth, summed and capped, and how many of each kind see the player.
local function witnessShare(target: Vector3): (number, number, number, number)
	local share, security, npc, camera = 0, 0, 0, 0
	local list = if sources then sources.witnesses() else {}
	for _, witness in list do
		if sees(witness, target) then
			share += config.WitnessWeights[witness.kind]
			if witness.kind == "Security" then
				security += 1
			elseif witness.kind == "Camera" then
				camera += 1
			else
				npc += 1
			end
		end
	end
	return math.min(share, config.WitnessCap), security, npc, camera
end

local function nearBody(position: Vector3): boolean
	if not sources then
		return false
	end
	for _, body in sources.bodies() do
		if (body - position).Magnitude <= config.NearBodyRadius then
			return true
		end
	end
	return false
end

-- Percent per second from what the player is doing and where (spec 7.3 and 7.4), before it is scaled by witnesses.
local function suspiciousRate(player: Player, position: Vector3, zoneTier: number, clearance: number): number
	local gain = config.SuspicionGain
	local sprinting, crouching = DisguiseService.getMovement(player)
	local rate = 0
	if zoneTier >= 1 then
		if sprinting then
			rate += gain.Sprint
		end
		if crouching then
			rate += gain.Crouch
		end
	end
	if nearBody(position) then
		rate += gain.NearBody
	end
	if zoneTier > clearance then
		local multipliers = config.TrespassTierMultipliers
		rate += config.TrespassGainPerSecond * multipliers[math.min(zoneTier - clearance, #multipliers)]
	end
	return rate
end

local function step(player: Player, state: State, dt: number, now: number)
	local humanoid, root = aliveRoot(player)
	if not (humanoid and root) then
		return
	end
	local feetY = root.Position.Y - (humanoid.HipHeight + root.Size.Y / 2)
	local target = Vector3.new(root.Position.X, feetY + config.WitnessTargetHeight, root.Position.Z)
	local share, security, npc, camera = witnessShare(target)
	if security > 0 then
		state.lastSeenBySecurity = now
	end

	local zoneTier = ZoneService.tierAt(root.Position)
	local clearance = DisguiseService.getClearance(player)

	if state.cover ~= "Exposed" then
		local rate = suspiciousRate(player, root.Position, zoneTier, clearance)
		local jumps = state.pendingJumps
		state.pendingJumps = 0
		local jumpGain = if zoneTier >= 1 then jumps * config.SuspicionGain.Jump else 0
		local gain = (rate * dt + jumpGain) * share
		if gain > 0 then
			state.suspicion = math.min(state.suspicion + gain, config.SuspicionMax)
			state.lastSuspiciousAt = now
		elseif now - state.lastSuspiciousAt >= config.SuspicionDecayDelay then
			state.suspicion = math.max(state.suspicion - config.SuspicionDecayPerSecond * dt, 0)
		end
		state.cover = if state.suspicion > 0 then "Suspicious" else "Covered"
		if state.suspicion >= config.SuspicionMax then
			-- The witness raises the alarm (spec 7.3). Stored and shown now; it gets effects in Step 14.
			alarmLevel += 1
			RemoteService.fireAllClients("AlarmLevel", alarmLevel)
			CoverService.expose(player, "MeterFull")
		end
	else
		state.pendingJumps = 0
	end

	-- Tell the player what changed.
	local restricted = zoneTier > clearance
	if restricted ~= state.sentRestricted or zoneTier ~= state.sentZoneTier or clearance ~= state.sentClearance then
		state.sentRestricted, state.sentZoneTier, state.sentClearance = restricted, zoneTier, clearance
		local info: Types.TrespassInfo = { Restricted = restricted, ZoneTier = zoneTier, Clearance = clearance }
		RemoteService.fireClient("TrespassWarning", player, info)
	end
	local rounded = math.floor(state.suspicion + 0.5)
	if
		rounded ~= state.sentSuspicion
		or security ~= state.sentSecurity
		or npc ~= state.sentNpc
		or camera ~= state.sentCamera
	then
		state.sentSuspicion, state.sentSecurity, state.sentNpc, state.sentCamera = rounded, security, npc, camera
		local info: Types.SuspicionInfo = { Value = rounded, Security = security, Npc = npc, Camera = camera }
		RemoteService.fireClient("SuspicionUpdate", player, info)
	end
	local recoverable = canRecover(player, now)
	if
		state.cover ~= state.sentCover
		or recoverable ~= state.sentCanRecover
		or recoverBlocker(player, now) ~= state.sentBlocker
		or isLockedOut(state, now) ~= state.sentLockoutActive
	then
		sendCover(player, state, now)
	end
end

local function onCharacterAdded(player: Player, character: Model)
	local state = newState()
	states[player] = state
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.StateChanged:Connect(function(_, new)
		if new == Enum.HumanoidStateType.Jumping then
			state.pendingJumps += 1
		end
	end)
	sendCover(player, state, os.clock())
end

function CoverService.Init() end

function CoverService.Start()
	DisguiseService.setCoverHooks({
		canScan = function(player)
			local state = states[player]
			return state ~= nil and not isLockedOut(state, os.clock())
		end,
		canRecover = function(player)
			return canRecover(player, os.clock())
		end,
		onRecovered = onRecovered,
	})

	local function track(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
		if player.Character then
			task.spawn(onCharacterAdded, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(track)
	for _, player in Players:GetPlayers() do
		track(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)

	local interval = 1 / config.WitnessCheckHz
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		accumulator += now - lastTick
		lastTick = now
		if accumulator < interval then
			return
		end
		local dt = accumulator
		accumulator = 0
		for player, state in states do
			step(player, state, dt, now)
		end
	end)
end

return CoverService
