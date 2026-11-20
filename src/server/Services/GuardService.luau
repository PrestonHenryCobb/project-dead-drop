--!strict
-- Ticket 15: Security guards in combat (spec 18.5) and the guards' side of the alarm (spec 18.4).
--
--   * A guard engages an agent who is Exposed and either stands in a Tier 1+ zone and is seen (the witness range and field
--     of view, +20% from Alert), or fired within EngageFiringRadius of the guard, or hit the guard. At Lockdown any Exposed
--     agent it sees is engaged, in any tier. A disguised agent, however suspicious, is never engaged (Exposed only).
--   * It walks after the agent (Reactions.pursue), stopping HoldStuds from them once it has them in sight, and shoots every
--     FireIntervalSeconds while the agent is in sight within FarAccuracyStuds: a hit chance of NearAccuracy up to
--     NearAccuracyStuds, falling to FarAccuracy at FarAccuracyStuds, a flat Damage, never a headshot. It chases no further
--     than ChaseLimitStuds from where it set out, and goes back to its post (Reactions.recall) when the agent is no longer
--     Exposed, is down, or has been out of sight for LoseSeconds.
--   * A camera that locks on alerts the nearest guards to the agent's position (alertNearest).
--   * The alarm: from Alert the guards walk at AlertWalkSpeed; on reaching Heightened, extra guards appear at Tier 1
--     nodes and stay until the match ends. (Lockdown's widened engagement is above; its siren is Step 20.)
--
-- A guard downed by an agent stands up NPC.WakeUp.Seconds later and carries on, as any NPC does (NPCService, Death).
--
--   GuardService.setActive(active)             SecurityService: guards fight only while a match runs
--   GuardService.alertNearest(position, count) the `count` nearest free guards go to look at `position`

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Smoke = require(script.Parent.Parent.Combat.Smoke)
local Death = require(script.Parent.Parent.NPC.Death)
local NpcTypes = require(script.Parent.Parent.NPC.NpcTypes)
local AlarmService = require(script.Parent.AlarmService)
local CombatService = require(script.Parent.CombatService)
local CoverService = require(script.Parent.CoverService)
local DownedService = require(script.Parent.DownedService)
local NPCService = require(script.Parent.NPCService)
local ZoneService = require(script.Parent.ZoneService)

type Npc = NpcTypes.Npc

type Candidate = { player: Player, root: BasePart }

-- One guard's fight with one agent.
type Pursuit = {
	target: Player,
	origin: Vector3, -- where the guard set out from: the chase limit is measured from here
	lastSeenAt: number,
	lastKnown: Vector3,
	lastAimed: Vector3, -- where the guard's route was last aimed
	repathAt: number,
	nextShotAt: number,
}

type Provocation = { player: Player, expires: number }

local GuardService = {}

local guard = GameConfig.Security.Guard
local alarm = GameConfig.Security.Alarm
local cover = GameConfig.Cover
local EYE_LIFT = Vector3.new(0, guard.EyeStuds, 0)

local rng = Random.new()
local active = false
local pursuits: { [Npc]: Pursuit } = {}
local provoked: { [Npc]: Provocation } = {} -- guards that heard an agent fire or were hit by one
local extras: { Npc } = {}
local candidates: { Candidate } = {}

-- Characters do not collide with each other, so rays cast in their group meet only the map.
local sight = RaycastParams.new()
sight.CollisionGroup = GameConfig.Rig.CollisionGroup
sight.RespectCanCollide = true

local function isGuard(npc: Npc): boolean
	return npc.role == Enums.Role.Security and not npc.decoy -- Feint's Double in a guard's clothes is no guard
end

-- Standing, walking, or already on a call-out: not cowering, held, in a lift or down.
local function isFree(npc: Npc): boolean
	local state = npc.state
	return state == "Idle" or state == "Walk" or state == "Investigate" or state == "Return"
end

local function lineClear(eye: Vector3, position: Vector3): boolean
	return workspace:Raycast(eye, position - eye, sight) == nil and not Smoke.blocks(eye, position)
end

-- Is the point within the guard's field of view (the same one witnesses use)?
local function inFov(npc: Npc, offset: Vector3): boolean
	local flat = Vector3.new(offset.X, 0, offset.Z)
	if flat.Magnitude < 1e-3 then
		return true
	end
	local look = Vector3.new(-math.sin(npc.yaw), 0, -math.cos(npc.yaw))
	return look:Dot(flat.Unit) >= math.cos(math.rad(cover.WitnessFov / 2))
end

-- The chance a shot at this range hits: NearAccuracy out to NearAccuracyStuds, then falling in a line to FarAccuracy at
-- FarAccuracyStuds.
local function accuracyAt(distance: number): number
	if distance <= guard.NearAccuracyStuds then
		return guard.NearAccuracy
	end
	local along = (distance - guard.NearAccuracyStuds) / (guard.FarAccuracyStuds - guard.NearAccuracyStuds)
	return guard.NearAccuracy + (guard.FarAccuracy - guard.NearAccuracy) * math.clamp(along, 0, 1)
end

-- Exposed agents a guard could shoot: alive and not downed. Disguised agents are not in the list, so they are never shot.
local function refreshCandidates()
	table.clear(candidates)
	for _, player in Players:GetPlayers() do
		if CoverService.isExposed(player) and not DownedService.isOut(player) then
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
				table.insert(candidates, { player = player, root = root })
			end
		end
	end
end

local function candidateFor(player: Player): Candidate?
	for _, candidate in candidates do
		if candidate.player == player then
			return candidate
		end
	end
	return nil
end

local function isProvokedBy(npc: Npc, player: Player, now: number): boolean
	local provocation = provoked[npc]
	return provocation ~= nil and provocation.player == player and provocation.expires > now
end

-- Does this guard take up the fight with this agent? Provoked guards always do; otherwise the agent must be in Tier 1+
-- (any tier at Lockdown) and seen within the guard's witness range and field of view.
local function wantsToEngage(npc: Npc, candidate: Candidate, now: number, notice: number, lockdown: boolean): boolean
	if isProvokedBy(npc, candidate.player, now) then
		return true
	end
	local eye = npc.ground + EYE_LIFT
	local position = candidate.root.Position
	local offset = position - eye
	if offset.Magnitude > notice then
		return false
	end
	if not lockdown and ZoneService.tierAt(position) < 1 then
		return false
	end
	return inFov(npc, offset) and lineClear(eye, position)
end

local function standDown(npc: Npc)
	pursuits[npc] = nil
	NPCService.recall(npc)
end

local function fire(pursuit: Pursuit, eye: Vector3, root: BasePart, distance: number, now: number)
	pursuit.nextShotAt = now + guard.FireIntervalSeconds
	local hit = rng:NextNumber() < accuracyAt(distance)
	local aim = root.Position
	if not hit then
		aim += rng:NextUnitVector() * guard.MissStuds
	end
	CombatService.botFire(eye, aim, if hit then pursuit.target else nil, guard.Damage, guard.HearStuds, guard.WeaponId)
end

-- One tick of a guard that has an agent to deal with.
local function engage(npc: Npc, pursuit: Pursuit, candidate: Candidate, now: number, trackStuds: number)
	local eye = npc.ground + EYE_LIFT
	local position = candidate.root.Position
	local offset = position - eye
	local distance = offset.Magnitude
	local visible = distance <= trackStuds and lineClear(eye, position)
	local provokedNow = isProvokedBy(npc, pursuit.target, now)
	if visible or provokedNow then
		pursuit.lastKnown = position -- a provoked guard knows where the shot came from
	end
	if visible then
		pursuit.lastSeenAt = now
	elseif not provokedNow and now - pursuit.lastSeenAt > guard.LoseSeconds then
		standDown(npc)
		return
	end

	local chased = Vector3.new(npc.ground.X - pursuit.origin.X, 0, npc.ground.Z - pursuit.origin.Z).Magnitude
	if (visible and distance <= guard.HoldStuds) or chased >= guard.ChaseLimitStuds then
		NPCService.holdPosition(npc, true)
	else
		NPCService.holdPosition(npc, false)
		local moved = (pursuit.lastKnown - pursuit.lastAimed).Magnitude > guard.RepathStuds
		if (moved or npc.path == nil) and now >= pursuit.repathAt then
			pursuit.repathAt = now + guard.RepathSeconds
			if NPCService.pursue(npc, pursuit.lastKnown) then
				pursuit.lastAimed = pursuit.lastKnown
			end
		end
	end

	if visible and npc.path == nil then
		npc.yaw = math.atan2(-offset.X, -offset.Z) -- stands facing its target
	end
	if visible and distance <= guard.FarAccuracyStuds and now >= pursuit.nextShotAt then
		fire(pursuit, eye, candidate.root, distance, now)
	end
end

local function beginPursuit(npc: Npc, candidate: Candidate, now: number)
	local position = candidate.root.Position
	local pursuit: Pursuit = {
		target = candidate.player,
		origin = npc.ground,
		lastSeenAt = now,
		lastKnown = position,
		lastAimed = position,
		repathAt = now + guard.RepathSeconds,
		nextShotAt = now + guard.FireIntervalSeconds, -- a moment to draw before the first shot
	}
	pursuits[npc] = pursuit
	NPCService.pursue(npc, position)
end

local function think()
	local now = os.clock()
	for npc, provocation in provoked do
		if provocation.expires <= now then
			provoked[npc] = nil
		end
	end
	refreshCandidates()
	if #candidates == 0 and next(pursuits) == nil then
		return
	end
	local lockdown = AlarmService.level() >= Enums.AlarmLevel.Lockdown
	local notice = cover.WitnessRange * AlarmService.detectionMult()
	local trackStuds = math.max(notice, guard.FarAccuracyStuds)
	for _, npc in NPCService.getNpcs() do
		if not isGuard(npc) then
			continue
		end
		local pursuit = pursuits[npc]
		if not isFree(npc) then
			pursuits[npc] = nil -- down, cowering or in a lift: whatever it was doing is over
			continue
		end
		if pursuit then
			local candidate = candidateFor(pursuit.target)
			if candidate then
				engage(npc, pursuit, candidate, now, trackStuds)
			else
				standDown(npc) -- the agent is covered again, down or gone
			end
			continue
		end
		local best: Candidate? = nil
		local bestDistance = math.huge
		for _, candidate in candidates do
			local distance = (candidate.root.Position - npc.ground).Magnitude
			if distance < bestDistance and wantsToEngage(npc, candidate, now, notice, lockdown) then
				best, bestDistance = candidate, distance
			end
		end
		if best then
			beginPursuit(npc, best, now)
		end
	end
end

local function provoke(npc: Npc, player: Player)
	provoked[npc] = { player = player, expires = os.clock() + guard.ProvokeSeconds }
end

-- Guards within earshot of a shot (EngageFiringRadius, or less for a quiet weapon) take it up with the shooter.
local function onFired(shooter: Player, origin: Vector3, hearStuds: number)
	if not active then
		return
	end
	local radius = math.min(guard.EngageFiringRadius, hearStuds)
	for _, npc in NPCService.getNpcs() do
		if isGuard(npc) and not Death.isDown(npc) and (npc.ground - origin).Magnitude <= radius then
			provoke(npc, shooter)
		end
	end
end

local function onHitNpc(shooter: Player, npc: Npc)
	if active and isGuard(npc) then
		provoke(npc, shooter)
	end
end

function GuardService.alertNearest(position: Vector3, count: number)
	if not active then
		return
	end
	local free: { { npc: Npc, distance: number } } = {}
	for _, npc in NPCService.getNpcs() do
		if isGuard(npc) and isFree(npc) and pursuits[npc] == nil then
			table.insert(free, { npc = npc, distance = (npc.ground - position).Magnitude })
		end
	end
	table.sort(free, function(a, b)
		return a.distance < b.distance
	end)
	for index = 1, math.min(count, #free) do
		NPCService.pursue(free[index].npc, position)
	end
end

local function spawnExtras()
	for _ = 1, alarm.HeightenedExtraGuards do
		if #extras >= guard.MaxExtras then
			return
		end
		local npc = NPCService.spawnGuard(guard.ExtraTier, guard.SpawnAwayStuds)
		if npc then
			table.insert(extras, npc)
		end
	end
end

local function onAlarmChange(level: number, previous: number)
	local alert = level >= Enums.AlarmLevel.Alert
	NPCService.setGuardSpeed(if alert then alarm.AlertWalkSpeed else GameConfig.NPC.WalkSpeed.Security)
	if active and level >= Enums.AlarmLevel.Heightened and previous < Enums.AlarmLevel.Heightened then
		spawnExtras()
	end
end

function GuardService.setActive(value: boolean)
	if active == value then
		return
	end
	active = value
	if not value then
		for npc in pursuits do
			NPCService.recall(npc)
		end
		table.clear(pursuits)
		table.clear(provoked)
		for _, npc in extras do
			NPCService.removeNpc(npc)
		end
		table.clear(extras)
	end
end

function GuardService.Init() end

function GuardService.Start()
	CombatService.setProvokeHooks({ fired = onFired, hitNpc = onHitNpc })
	AlarmService.onChange(onAlarmChange)
	local interval = 1 / guard.ThinkHz
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= interval then
			elapsed = 0
			if active then
				think()
			end
		end
	end)
end

return GuardService
