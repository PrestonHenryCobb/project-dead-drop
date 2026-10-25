--!strict
-- Combat (spec 13, with the decisions in docs/STEP8_QUESTIONS.md). The server owns everything: health, armour, ammo, the
-- cooldowns, and every hit. Clients only ask.
--
--   * Health and armour: 100 HP and plates of 25 (spec 13.1). Damage hits armour first. No passive healing.
--   * Firing (FireRequest): the shot is validated (alive, weapon, fire rate, ammo, origin near the shooter's head), then
--     tested against every person's rewound pose (Ballistics), up to LagCompSeconds back, after a ray against the map.
--     The nearest person hit takes the weapon's damage with headshot and falloff (a disguised agent's head counts as
--     body). The shooter gets a HitConfirm (grey for
--     an NPC, red for an agent, spec 8.4); a wounded agent gets a DamageTaken marker; everyone within earshot gets a
--     ShotHeard. Firing breaks Cover and starts the combat lockout (spec 7.2, 7.6); NPCs react to the noise (spec 5.4).
--   * Reloading and aiming: ReloadRequest runs a timer here; RequestDraw tells CoverService the weapon is up (spec 7.3).
--     A disguise swap cancels a reload, and no reload starts during one (spec 27 #22).
--   * Melee and takedowns (RequestMelee, spec 13.4): V strikes; from behind it begins a held takedown instead, which the
--     server times, and breaks if the target moves off, the attacker is hurt or either leaves reach.
--   * Falls: a fall of more than FallSafeStuds hurts (spec 13.1), measured by height: from the highest point since the
--     player last stood on the map to where they land. The server probes the ground itself, because its copy of a
--     player's Humanoid state is not reliable (it reports Landed while the character is still falling). Riding a
--     zipline (root anchored) and crawling in a vent never count as a fall.
--
-- At 0 HP a player's character dies; the downed state replaces that in Step 9. Until teams exist (Step 10), every other
-- player is an enemy, so friendly fire is not checked yet.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Types = require(Shared:WaitForChild("Types"))
local WeaponDefs = require(Shared:WaitForChild("Defs"):WaitForChild("WeaponDefs"))
local Ballistics = require(script.Parent.Parent.Combat.Ballistics)
local Death = require(script.Parent.Parent.NPC.Death)
local FireRate = require(script.Parent.Parent.Combat.FireRate)
local History = require(script.Parent.Parent.Combat.History)
local CoverService = require(script.Parent.CoverService)
local DisguiseService = require(script.Parent.DisguiseService)
local NPCService = require(script.Parent.NPCService)
local RemoteService = require(script.Parent.RemoteService)
local TeamService = require(script.Parent.TeamService)
local VentService = require(script.Parent.VentService)

type WeaponDef = Types.WeaponDef
type Target = History.Target

type Takedown = {
	target: Target,
	startedAt: number,
	startPosition: Vector3, -- where the target stood when it began
}

type State = {
	weapon: WeaponDef,
	hp: number,
	armor: number,
	mag: number,
	reserve: number,
	reloadEndsAt: number,
	reloadId: number,
	nextFireAt: number,
	streak: FireRate.Streak, -- bursts and spin-up (ticket 8.5)
	aiming: boolean, -- the weapon is drawn (RequestDraw); some weapons fire slower aimed, the DMR glints
	lastMeleeAt: number,
	lastDamagedAt: number,
	lastReactAt: number,
	takedown: Takedown?,
	fallPeakY: number, -- the highest the root has been since the player last stood on the map
	airborne: boolean,
	dead: boolean,
	violations: number,
}

local CombatService = {}

local config = GameConfig.Combat
local states: { [Player]: State } = {}
local sampleAccumulator = 0
local takedownAccumulator = 0
local glintAccumulator = 0
local rng = Random.new()
local sweep = 0

-- Rays in the character group skip characters and meet only the map (and what blocks shots: glass, shut doors).
local mapParams = RaycastParams.new()
mapParams.CollisionGroup = GameConfig.Rig.CollisionGroup
mapParams.RespectCanCollide = true

local function aliveParts(player: Player): (Humanoid?, BasePart?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return humanoid, root
	end
	return nil, nil
end

local function targetIdOf(player: Player): string
	return `P{player.UserId}`
end

local function sendHealth(player: Player, state: State)
	local info: Types.HealthInfo = { HP = state.hp, Armor = state.armor }
	RemoteService.fireClient("HealthUpdate", player, info)
end

local function sendAmmo(player: Player, state: State, reloadSeconds: number)
	local info: Types.AmmoInfo = { Mag = state.mag, Reserve = state.reserve, ReloadSeconds = reloadSeconds }
	RemoteService.fireClient("AmmoUpdate", player, info)
end

local function sendMelee(player: Player, active: boolean)
	local info: Types.MeleeState = { Kind = "Takedown", Seconds = config.Takedown.HoldSeconds, Active = active }
	RemoteService.fireClient("MeleeState", player, info)
end

-- Counts a request that no honest client sends (spec 26: log it, never act on it alone).
local function suspect(player: Player, state: State, what: string)
	state.violations += 1
	if state.violations % config.ViolationLogEvery == 1 then
		warn(`[CombatService] {player.Name}: {what} (violation {state.violations})`)
	end
end

-- Damage to a player: armour first, then health (spec 13.1). `attacker` is nil for falls. Being hurt by another agent
-- starts the combat lockout (spec 7.6).
local function damagePlayer(victim: Player, amount: number, from: Vector3, attacker: Player?)
	local state = states[victim]
	local humanoid = aliveParts(victim)
	if not state or not humanoid or state.dead then
		return
	end
	local absorbed = math.min(state.armor, amount)
	state.armor -= absorbed
	state.hp = math.max(0, state.hp - (amount - absorbed))
	state.lastDamagedAt = os.clock()
	sendHealth(victim, state)
	local info: Types.DamageInfo = { Position = from, Amount = amount }
	RemoteService.fireClient("DamageTaken", victim, info)
	if attacker then
		CoverService.startLockout(victim)
	end
	if state.hp <= 0 then
		state.dead = true
		state.takedown = nil
		humanoid.Health = 0
	end
end

-- A hit lands on `target`: the person is hurt, and the shooter sees a hitmarker that says what they hit (spec 8.4).
local function applyDamage(shooter: Player, target: Target, amount: number, head: boolean, from: Vector3)
	local confirm: Types.HitConfirm
	if target.kind == "Npc" then
		if NPCService.hitNpc(target.npc :: any, amount, from) then
			CoverService.onNpcKilled(shooter) -- killing an NPC exposes the killer (spec 7.2 #11)
		end
		confirm = { Kind = "Npc", Head = head }
	else
		damagePlayer(target.player :: Player, amount, from, shooter)
		confirm = { Kind = "Agent", Head = head }
	end
	RemoteService.fireClient("HitConfirm", shooter, confirm)
end

local function falloffMult(def: WeaponDef, distance: number): number
	local falloff = def.Falloff
	if not falloff or distance <= falloff.StartStuds then
		return 1
	elseif distance >= falloff.EndStuds then
		return falloff.MinMult
	end
	local along = (distance - falloff.StartStuds) / (falloff.EndStuds - falloff.StartStuds)
	return 1 - (1 - falloff.MinMult) * along
end

-- History: who can be hit ------------------------------------------------------------------------------------------

-- Tracks the NPCs that are on their feet and forgets the rest (downed NPCs are bodies, not targets).
local function syncNpcTargets()
	sweep += 1
	for _, npc in NPCService.getNpcs() do
		if not Death.isDown(npc) then
			local target = History.targets[npc.id]
			if not target then
				target = History.make(
					npc.id,
					"Npc",
					npc.model,
					npc.rootHeight,
					GameConfig.NPC.InterpolationDelay,
					{ npc = npc }
				)
				if target then
					History.track(target)
				end
			end
			if target then
				target.seen = sweep
			end
		end
	end
	for id, target in History.targets do
		if target.kind == "Npc" and target.seen ~= sweep then
			History.untrack(id)
		end
	end
end

-- Firing ----------------------------------------------------------------------------------------------------------

-- Puts the rounds of a reload in progress into the magazine. reloadEndsAt is 0 when no reload is running.
local function finishReload(player: Player, state: State)
	if state.reloadEndsAt == 0 then
		return
	end
	state.reloadEndsAt = 0
	local take = math.min(state.weapon.MagSize - state.mag, state.reserve)
	state.mag += take
	state.reserve -= take
	sendAmmo(player, state, 0)
end

-- The rays a FireRequest carries: one direction, or for a weapon with Pellets, a list of exactly that many. Each must
-- be a unit vector. Anything else is refused.
local function directionsOf(def: WeaponDef, direction: unknown): { Vector3 }?
	local function unit(value: unknown): Vector3?
		if typeof(value) ~= "Vector3" or value ~= value then
			return nil
		end
		return if math.abs(value.Magnitude - 1) <= config.FireDirectionTolerance then value else nil
	end
	local pellets = def.Pellets
	if not pellets then
		local single = unit(direction)
		return if single then { single } else nil
	end
	if type(direction) ~= "table" or #(direction :: { any }) ~= pellets then
		return nil
	end
	local list: { Vector3 } = {}
	for index = 1, pellets do
		local ray = unit((direction :: { any })[index])
		if not ray then
			return nil
		end
		list[index] = ray
	end
	return list
end

-- Where listeners hear a shot: at the shooter, or for a weapon with SoundOffset, some studs away in a random direction
-- (Feint's silent pistol: the sound seems to come from elsewhere).
local function soundOriginOf(def: WeaponDef, origin: Vector3): Vector3
	local offset = def.SoundOffset
	if not offset then
		return origin
	end
	local angle = rng:NextNumber(0, 2 * math.pi)
	local distance = rng:NextNumber(offset.Min, offset.Max)
	return origin + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
end

local function onFire(player: Player, origin: unknown, direction: unknown, timestamp: unknown, weaponId: unknown)
	if
		typeof(origin) ~= "Vector3"
		or type(timestamp) ~= "number"
		or type(weaponId) ~= "string"
		or origin ~= origin
		or timestamp ~= timestamp
		or math.abs(timestamp) == math.huge
	then
		return
	end
	local state = states[player]
	local humanoid, root = aliveParts(player)
	if not (state and humanoid and root) or state.dead then
		return
	end
	local def = state.weapon
	if weaponId ~= def.Id then
		return
	end
	local directions = directionsOf(def, direction)
	if not directions then
		return
	end
	local now = os.clock()
	if state.reloadEndsAt ~= 0 then
		-- The client finishes its reload on its own clock and fires at once, which can arrive a moment before the
		-- server's timer runs; within the fire-rate tolerance the reload is done, so that first shot is not lost.
		if now < state.reloadEndsAt - config.FireRateToleranceSeconds then
			return
		end
		finishReload(player, state)
	end
	if now < state.nextFireAt - config.FireRateToleranceSeconds then
		suspect(player, state, "fired faster than the weapon's rate")
		sendAmmo(player, state, 0)
		return
	end
	if state.mag <= 0 then
		sendAmmo(player, state, 0)
		return
	end
	-- A strong weapon cannot fire straight after a melee strike (brief Q14, ticket 8.9).
	if now < state.lastMeleeAt + (def.PostMeleeFireDelay or 0) then
		sendAmmo(player, state, 0)
		return
	end

	-- The shot must start where the shooter's head was when they fired (spec 13.3).
	local serverNow = workspace:GetServerTimeNow()
	local shooter = History.targets[targetIdOf(player)]
	if not shooter then
		return
	end
	local _, shooterHead = History.poseAt(shooter, math.clamp(timestamp, serverNow - config.LagCompSeconds, serverNow))
	if not shooterHead or (origin - shooterHead).Magnitude > config.FireOriginToleranceStuds then
		suspect(player, state, "fired from away from their own head")
		if GameConfig.Debug.PrintShots then
			print(`[Shot] rejected: origin {origin} but head was {shooterHead}`)
		end
		return
	end

	state.nextFireAt = math.max(state.nextFireAt, now - config.FireRateToleranceSeconds)
		+ FireRate.gapAfterShot(def, state.streak, now, state.aiming)
	state.mag -= 1
	state.takedown = nil

	-- Guise's pistol: a shot fired while still disguised is an ambush shot (STEP8 unique effects).
	local ambush = if def.AmbushMult and not CoverService.isExposed(player) then def.AmbushMult else 1

	-- Firing breaks Cover and starts the lockout (spec 7.2 #1, 7.6); NPCs hear it (spec 5.4).
	CoverService.expose(player, "Fired")
	CoverService.startLockout(player)
	local hearStuds = def.HearStuds
		or (if def.Quiet then GameConfig.Audio.SuppressedWeaponRadius else GameConfig.Audio.DefaultWeaponRadius)
	local soundOrigin = soundOriginOf(def, origin)
	if now - state.lastReactAt >= config.GunfireReactSeconds then
		state.lastReactAt = now
		NPCService.gunshot(soundOrigin, hearStuds)
	end

	local pierce = def.Pierce
	local maxHits = 1 + (if pierce then pierce.Count else 0)
	local struckAnyone = false
	for _, ray in directions do
		local hits, endPoint, hitWall = Ballistics.trace(player, origin, ray, timestamp, maxHits)
		for index, hit in hits do
			-- A disguised agent (Covered or Suspicious) always takes body damage, even on the head; headshots count once
			-- they are Exposed (SPEC_CHANGES 2026-10-24, brief Q2). The hitmarker shows a body hit to match.
			local target = hit.target
			local head = hit.head
				and not (target.kind == "Agent" and not CoverService.isExposed(target.player :: Player))
			local pierced = if pierce then pierce.DamageMult ^ (index - 1) else 1
			local amount = def.Damage
				* (if head then def.HeadshotMult else 1)
				* falloffMult(def, hit.distance)
				* ambush
				* pierced
			applyDamage(player, target, amount, head, origin)
			struckAnyone = true
		end
		if GameConfig.Debug.PrintShots then
			local first = hits[1]
			print(
				`[Shot] from {origin} dir {ray} t-lag {string.format("%.3f", serverNow - timestamp)}: `
					.. (
						if first
							then `{#hits} hit(s), first {first.target.id}{if first.head then " HEAD" else ""}`
							else `nothing ({if hitWall then "wall" else "open"})`
					)
			)
		end

		local info: Types.ShotInfo = { Origin = soundOrigin, Hit = endPoint, WeaponId = def.Id, Struck = #hits > 0 }
		for _, other in Players:GetPlayers() do
			if other ~= player then
				local _, otherRoot = aliveParts(other)
				if otherRoot and (otherRoot.Position - soundOrigin).Magnitude <= hearStuds then
					RemoteService.fireClient("ShotHeard", other, info)
				end
			end
		end
	end
	if struckAnyone then
		CoverService.startLockout(player) -- dealing damage refreshes it (spec 7.6)
	end
end

local function onReload(player: Player)
	local state = states[player]
	local humanoid = aliveParts(player)
	if not (state and humanoid) or state.dead then
		return
	end
	local def = state.weapon
	local now = os.clock()
	if
		state.reloadEndsAt ~= 0
		or state.mag >= def.MagSize
		or state.reserve <= 0
		or DisguiseService.isChanging(player) -- spec 27 #22
	then
		return
	end
	state.reloadId += 1
	local id = state.reloadId
	state.reloadEndsAt = now + def.ReloadSeconds
	sendAmmo(player, state, def.ReloadSeconds)
	task.delay(def.ReloadSeconds, function()
		if states[player] == state and state.reloadId == id and not state.dead then
			finishReload(player, state)
		end
	end)
end

-- A disguise swap cancels a reload in progress (spec 27 #22); the rounds stay out and the client is told.
local function cancelReload(player: Player)
	local state = states[player]
	if not state or state.reloadEndsAt == 0 then
		return
	end
	state.reloadId += 1
	state.reloadEndsAt = 0
	sendAmmo(player, state, 0)
end

local function onDraw(player: Player, drawn: unknown)
	if type(drawn) ~= "boolean" or not states[player] then
		return
	end
	states[player].aiming = drawn
	CoverService.setWeaponDrawn(player, drawn)
end

-- Reticle's DMR (STEP8 unique effects): while she aims, every rival agent with a clear line to her scope within
-- ScopeGlint.RangeStuds is sent a glint at her head, refreshed CheckHz times a second.
local function sendGlints()
	local glint = config.ScopeGlint
	for player, state in states do
		if state.aiming and state.weapon.ScopeGlint and not state.dead then
			local character = player.Character
			local head = character and character:FindFirstChild("Head")
			if head and head:IsA("BasePart") then
				for _, other in Players:GetPlayers() do
					local _, otherRoot = aliveParts(other)
					local otherHead = other.Character and other.Character:FindFirstChild("Head")
					if other ~= player and otherRoot and otherHead and otherHead:IsA("BasePart") then
						local toOther = otherHead.Position - head.Position
						if
							toOther.Magnitude <= glint.RangeStuds
							and workspace:Raycast(head.Position, toOther, mapParams) == nil
						then
							local info: Types.ScopeGlintInfo = { Position = head.Position, Seconds = glint.Seconds }
							RemoteService.fireClient("ScopeGlint", other, info)
						end
					end
				end
			end
		end
	end
end

-- Melee and takedowns --------------------------------------------------------------------------------------------

-- Which way a target faces, flat: an NPC by its yaw, a player by their body.
local function facingOf(target: Target): Vector3
	local npc = target.npc
	if npc then
		return Vector3.new(-math.sin(npc.yaw), 0, -math.cos(npc.yaw))
	end
	local look = target.rootPart.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	return if flat.Magnitude > 1e-3 then flat.Unit else Vector3.zAxis
end

-- The nearest person within melee reach and inside the swing's arc, with nothing of the map between.
local function findMeleeTarget(player: Player, root: BasePart, look: Vector3): Target?
	local melee = config.Melee
	local reach = melee.Range + melee.ReachSlackStuds
	local minDot = math.cos(math.rad(melee.SwingConeDegrees / 2))
	local best: Target? = nil
	local bestDistance = math.huge
	for _, target in History.targets do
		if target.player ~= player then
			local offset = target.rootPart.Position - root.Position
			local flat = Vector3.new(offset.X, 0, offset.Z)
			local distance = flat.Magnitude
			if
				distance <= reach
				and distance < bestDistance
				and math.abs(offset.Y) <= melee.HeightStuds
				and (distance < 1e-3 or flat.Unit:Dot(look) >= minDot)
				and workspace:Raycast(root.Position, offset, mapParams) == nil
			then
				best, bestDistance = target, distance
			end
		end
	end
	return best
end

-- Is `attacker` inside the cone behind the target (spec 13.4: the target's back within 60 degrees)?
local function isBehind(target: Target, attackerPosition: Vector3): boolean
	local offset = attackerPosition - target.rootPart.Position
	local flat = Vector3.new(offset.X, 0, offset.Z)
	if flat.Magnitude < 1e-3 then
		return true
	end
	return (-facingOf(target)):Dot(flat.Unit) >= math.cos(math.rad(config.Takedown.ConeDegrees / 2))
end

local function endTakedown(player: Player, state: State)
	if state.takedown then
		state.takedown = nil
		sendMelee(player, false)
	end
end

local function onMelee(player: Player, kind: unknown, lookArg: unknown)
	local state = states[player]
	local humanoid, root = aliveParts(player)
	if not (state and humanoid and root) or state.dead or type(kind) ~= "string" then
		return
	end
	if kind == "Release" then
		endTakedown(player, state)
		return
	end
	if kind ~= "Press" or typeof(lookArg) ~= "Vector3" or lookArg ~= lookArg then
		return
	end
	local flatLook = Vector3.new(lookArg.X, 0, lookArg.Z)
	if flatLook.Magnitude < 1e-3 or state.takedown then
		return
	end
	local look = flatLook.Unit
	local now = os.clock()
	local target = findMeleeTarget(player, root, look)

	-- From behind, V begins a takedown that has to be held (spec 13.4).
	if target and isBehind(target, root.Position) then
		CoverService.expose(player, "Takedown")
		CoverService.startLockout(player)
		state.takedown = { target = target, startedAt = now, startPosition = target.rootPart.Position }
		sendMelee(player, true)
		return
	end

	if now - state.lastMeleeAt < config.Melee.CooldownSeconds then
		return
	end
	state.lastMeleeAt = now
	CoverService.expose(player, "Melee")
	CoverService.startLockout(player)
	if target then
		applyDamage(player, target, config.Melee.Damage, false, root.Position)
	end
end

-- Holds, completes or breaks every takedown in progress (spec 13.4). The server runs the timer.
local function checkTakedowns(now: number)
	for player, state in states do
		local takedown = state.takedown
		if takedown then
			local humanoid, root = aliveParts(player)
			local target = takedown.target
			local reach = config.Melee.Range + config.Melee.ReachSlackStuds
			if
				not (humanoid and root)
				or History.targets[target.id] ~= target
				or (target.rootPart.Position - root.Position).Magnitude > reach
				or (target.rootPart.Position - takedown.startPosition).Magnitude > config.Takedown.BreakDistance
				or state.lastDamagedAt > takedown.startedAt
			then
				endTakedown(player, state)
			elseif now - takedown.startedAt >= config.Takedown.HoldSeconds then
				state.takedown = nil
				sendMelee(player, false)
				applyDamage(player, target, config.Takedown.Damage, false, (root :: BasePart).Position)
			end
		end
	end
end

-- Spawning and falling --------------------------------------------------------------------------------------------

-- Falls (spec 13.1), by height: the highest point since the player last stood on the map, down to where they land.
local function trackFall(player: Player, state: State)
	local humanoid, root = aliveParts(player)
	if not (humanoid and root) or state.dead then
		return
	end
	local y = root.Position.Y
	-- A zipline anchors the rider; a vent is crawled. Neither is a fall, and the height count starts again after.
	if root.Anchored or VentService.isInside(player) then
		state.fallPeakY = y
		state.airborne = false
		return
	end
	local probe = humanoid.HipHeight + root.Size.Y / 2 + config.GroundProbeSlackStuds
	if workspace:Raycast(root.Position, Vector3.new(0, -probe, 0), mapParams) then
		if state.airborne then
			local fallen = state.fallPeakY - y
			if fallen > config.FallSafeStuds then
				damagePlayer(player, (fallen - config.FallSafeStuds) * config.FallDamagePerStud, root.Position, nil)
			end
		end
		state.airborne = false
		state.fallPeakY = y
	else
		state.airborne = true
		state.fallPeakY = math.max(state.fallPeakY, y)
	end
end

local function onCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local root = character:WaitForChild("HumanoidRootPart") :: BasePart
	character:WaitForChild("Head")
	local def = WeaponDefs.get(config.DefaultWeapon)
	assert(def, `Combat.DefaultWeapon {config.DefaultWeapon} is not a weapon`)
	local state: State = {
		weapon = def,
		hp = config.MaxHP,
		armor = (if TeamService.isSolos() then config.SoloStartPlates else config.StartPlates) * config.PlateHP,
		mag = def.MagSize,
		reserve = def.ReserveAmmo,
		reloadEndsAt = 0,
		reloadId = 0,
		nextFireAt = 0,
		streak = FireRate.newStreak(),
		aiming = false,
		lastMeleeAt = -math.huge,
		lastDamagedAt = -math.huge,
		lastReactAt = -math.huge,
		takedown = nil,
		fallPeakY = root.Position.Y,
		airborne = false,
		dead = false,
		violations = 0,
	}
	states[player] = state

	local id = targetIdOf(player)
	local target = History.make(
		id,
		"Agent",
		character,
		humanoid.HipHeight + root.Size.Y / 2,
		config.PlayerRenderDelay,
		{ player = player }
	)
	if target then
		History.track(target)
	end

	humanoid.Died:Connect(function()
		state.dead = true
		state.takedown = nil
		History.untrack(id)
	end)

	sendHealth(player, state)
	sendAmmo(player, state, 0)
end

function CombatService.Init()
	assert(WeaponDefs.get(config.DefaultWeapon), "Combat.DefaultWeapon must name a weapon in WeaponDefs")
end

function CombatService.Start()
	RemoteService.onRequest("FireRequest", onFire)
	RemoteService.onRequest("ReloadRequest", onReload)
	RemoteService.onRequest("RequestDraw", onDraw)
	RemoteService.onRequest("RequestMelee", onMelee)
	DisguiseService.onSwapStarted(cancelReload)

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
		History.untrack(targetIdOf(player))
		states[player] = nil
	end)

	local sampleInterval = 1 / config.LagCompHistoryHz
	RunService.Heartbeat:Connect(function(dt)
		sampleAccumulator += dt
		if sampleAccumulator >= sampleInterval then
			sampleAccumulator = 0
			syncNpcTargets()
			History.sample(workspace:GetServerTimeNow())
		end
		for player, state in states do
			trackFall(player, state)
		end
		glintAccumulator += dt
		if glintAccumulator >= 1 / config.ScopeGlint.CheckHz then
			glintAccumulator = 0
			sendGlints()
		end
		takedownAccumulator += dt
		if takedownAccumulator >= config.Takedown.CheckSeconds then
			takedownAccumulator = 0
			checkTakedowns(os.clock())
		end
	end)
end

return CombatService
