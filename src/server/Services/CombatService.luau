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
--   * Melee and takedowns (ticket 8.22): V press starts a valid rear hold or prepares a charge; release strikes only
--     for a charge. Cancel never strikes. The server times every action and validates geometry, state and cooldown.
--   * Falls: a fall of more than FallSafeStuds hurts (spec 13.1), measured by height: from the highest point since the
--     player last stood on the map to where they land. The server probes the ground itself, because its copy of a
--     player's Humanoid state is not reliable (it reports Landed while the character is still falling). Riding a
--     zipline (root anchored) and crawling in a vent never count as a fall.
--
--   * Weapon effects (tickets 8.5a/b/e/f, contracts in .ai-sync/WEAPON_SERVER_CONTRACTS.md): a weapon with Melee uses its
--     own V numbers (garrote, hammer shove); ReloadPerShell loads one round at a time and a shot interrupts it; a pull
--     with SurvivesFullHealth or Stagger is tallied per target; Smoke leaves a cloud from the last rounds of a magazine;
--     a Projectile weapon hands its throw to ProjectileService (flare, throwing knives).
--
-- DownedService handles 0 HP through hooks. Spec 13.6: the common damage path rejects teammates.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Types = require(Shared:WaitForChild("Types"))
local MeleeRules = require(Shared:WaitForChild("Util"):WaitForChild("MeleeRules"))
local WeaponDefs = require(Shared:WaitForChild("Defs"):WaitForChild("WeaponDefs"))
local TestLoadout = require(Shared.Util.TestLoadout)
local Ballistics = require(script.Parent.Parent.Combat.Ballistics)
local Death = require(script.Parent.Parent.NPC.Death)
local NpcTypes = require(script.Parent.Parent.NPC.NpcTypes)
local FireRate = require(script.Parent.Parent.Combat.FireRate)
local History = require(script.Parent.Parent.Combat.History)
local Shields = require(script.Parent.Parent.Combat.Shields)
local CoverService = require(script.Parent.CoverService)
local DisguiseService = require(script.Parent.DisguiseService)
local NPCService = require(script.Parent.NPCService)
local RemoteService = require(script.Parent.RemoteService)
local TeamService = require(script.Parent.TeamService)
local VentService = require(script.Parent.VentService)

type WeaponDef = Types.WeaponDef
type Target = History.Target

type Takedown = {
	seconds: number, -- how long the hold takes with the weapon held
	damage: number,
	target: Target,
	look: Vector3, -- camera heading validated at press; body locomotion-facing is not the first-person aim
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
	chargeStartedAt: number?, -- Ticket 8.22: server clock only; clients never submit charge duration/damage
	fallPeakY: number, -- the highest the root has been since the player last stood on the map
	lastY: number, -- the root height at the last check, to tell a teleport from a fall
	airborne: boolean,
	dead: boolean,
	violations: number,
	target: Target?, -- this player in History; untracked while downed so shots pass through (as for a downed NPC)
}

-- How ProjectileService takes a throw (set once at Start). canLaunch is asked before any round is spent.
export type ProjectileHooks = {
	canLaunch: (Player) -> boolean,
	launch: (shooter: Player, def: WeaponDef, origin: Vector3, direction: Vector3) -> (),
}

-- Ticket 15: GuardService hears about an agent firing and about an agent hitting an NPC (the Security guards it provokes).
export type ProvokeHooks = {
	fired: (shooter: Player, origin: Vector3, hearStuds: number) -> (),
	hitNpc: (shooter: Player, npc: NpcTypes.Npc) -> (),
}

-- One target's share of a pull that is tallied as a whole (pump shotgun).
type Tally = { amount: number, head: boolean, pellets: number }

-- How DownedService takes over at 0 HP (spec 14). Without them a player at 0 HP simply dies.
export type DownedHooks = {
	onZeroHealth: (Player, Vector3) -> (), -- the player reached 0 HP; `from` is where the damage came from
	isDowned: (Player) -> boolean,
}

local CombatService = {}

local config = GameConfig.Combat
local states: { [Player]: State } = {}
local frozen: { [Player]: boolean } = {} -- ticket 10a: no shots or melee during Insertion
-- Ticket studio-test-loadout: private server selections, retained through respawn, never character metadata.
local testWeapons: { [Player]: string } = {}
-- Ticket menu-services: the Hardware each player deployed with (LobbyService); used for every spawn after it.
local loadoutWeapons: { [Player]: string } = {}
local sampleAccumulator = 0
local takedownAccumulator = 0
local downedHooks: DownedHooks? = nil
local projectileHooks: ProjectileHooks? = nil
local worldHitListener: ((Vector3, Player) -> ())? = nil -- ticket 14: a shot ended on the map (cameras)
local provokeHooks: ProvokeHooks? = nil -- ticket 15: guards
local damageListener: ((Player) -> ())? = nil -- ticket 16c: a player took damage (a piloted drone lands)
local agentRules: ((Player) -> { [string]: any })? = nil -- ticket 16: GameConfig.Agents numbers of the player's agent
local glintAccumulator = 0
local rng = Random.new()
local sweep = 0

-- Rays in the character group skip characters and meet only the map (and what blocks shots: glass, shut doors).
local mapParams = RaycastParams.new()
mapParams.CollisionGroup = GameConfig.Rig.CollisionGroup
mapParams.RespectCanCollide = true

local NO_RULES: { [string]: any } = {}

local function rulesOf(player: Player): { [string]: any }
	local lookup = agentRules
	return if lookup then lookup(player) else NO_RULES
end

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
	local info: Types.AmmoInfo = {
		Mag = state.mag,
		Reserve = state.reserve,
		ReloadSeconds = reloadSeconds,
		WeaponId = state.weapon.Id,
	}
	RemoteService.fireClient("AmmoUpdate", player, info)
end

local function sendMelee(
	player: Player,
	active: boolean,
	kind: Types.MeleeKind?,
	startedAt: number?,
	result: Types.MeleeResult?
)
	local action = kind or "Takedown"
	local state = states[player]
	local melee = state and state.weapon.Melee
	local info: Types.MeleeState = {
		Kind = action,
		Seconds = if action == "Charge"
			then (melee and melee.ChargeSeconds) or config.Melee.FullChargeSeconds
			else (melee and melee.TakedownSeconds) or config.Takedown.HoldSeconds,
		Active = active,
		StartedAt = startedAt,
		Result = result,
	}
	RemoteService.fireClient("MeleeState", player, info)
end

-- R5-takedown: the target's side of a hold. An NPC is held still and struggles (every client sees it through
-- NPCAnimation); a player is told, so their own character plays the struggle, and may still break free by moving.
local function holdVictim(target: Target, active: boolean, startedAt: number?)
	local npc = target.npc
	if npc then
		NPCService.setHeld(npc :: any, active)
	elseif target.player then
		local info: Types.TakedownVictimInfo =
			{ Active = active, Seconds = config.Takedown.HoldSeconds, StartedAt = startedAt }
		RemoteService.fireClient("TakedownVictim", target.player :: Player, info)
	end
end

local function cancelMelee(player: Player, state: State)
	local takedown = state.takedown
	if takedown then
		state.takedown = nil
		holdVictim(takedown.target, false)
		sendMelee(player, false)
	end
	if state.chargeStartedAt then
		state.chargeStartedAt = nil
		sendMelee(player, false, "Charge")
	end
end

local function isDowned(player: Player): boolean
	return downedHooks ~= nil and downedHooks.isDowned(player)
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
	if not state or not humanoid or state.dead or isDowned(victim) then
		return -- a downed body takes no more damage: it is executed or bleeds out (spec 14.1)
	end
	local absorbed = math.min(state.armor, amount)
	state.armor -= absorbed
	state.hp = math.max(0, state.hp - (amount - absorbed))
	state.lastDamagedAt = os.clock()
	sendHealth(victim, state)
	if damageListener then
		damageListener(victim)
	end
	local info: Types.DamageInfo = { Position = from, Amount = amount }
	RemoteService.fireClient("DamageTaken", victim, info)
	if attacker then
		CoverService.startLockout(victim)
	end
	if state.hp <= 0 then
		cancelMelee(victim, state)
		local hooks = downedHooks
		if hooks then
			hooks.onZeroHealth(victim, from)
		else
			state.dead = true
			humanoid.Health = 0
		end
	end
end

-- A hit lands on `target`: the person is hurt, and the shooter sees a hitmarker that says what they hit (spec 8.4).
-- Returns what the hit did (R5-takedown): "Downed", "Eliminated" or "Hit" (nil when teammates were spared).
local function applyDamage(
	shooter: Player,
	target: Target,
	amount: number,
	head: boolean,
	from: Vector3
): Types.MeleeResult?
	-- Ticket 8.22: spec 13.6 also applies to melee/takedowns and all other damage routed here.
	if target.player and TeamService.areTeammates(shooter, target.player) then
		return nil
	end
	local confirm: Types.HitConfirm
	local result: Types.MeleeResult = "Hit"
	if target.kind == "Npc" and (target.npc :: any).decoy then
		-- Feint's Double (ticket 16f): the hitmarker of an agent, then it pops. Nobody is killed, so nobody is exposed for it.
		History.untrack(target.id)
		NPCService.removeNpc(target.npc :: any)
		confirm = { Kind = "Agent", Head = head }
	elseif target.kind == "Npc" then
		if provokeHooks then
			provokeHooks.hitNpc(shooter, target.npc :: any)
		end
		if NPCService.hitNpc(target.npc :: any, amount, from) then
			CoverService.onNpcKilled(shooter, (target.npc :: any).role) -- killing an NPC exposes the killer (spec 7.2 #11)
			result = "Downed"
		end
		confirm = { Kind = "Npc", Head = head }
	else
		local victim = target.player :: Player
		damagePlayer(victim, amount, from, shooter)
		local victimState = states[victim]
		if isDowned(victim) then
			result = "Downed"
		elseif victimState and victimState.dead then
			result = "Eliminated"
		end
		confirm = { Kind = "Agent", Head = head }
	end
	RemoteService.fireClient("HitConfirm", shooter, confirm)
	return result
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
	local def = state.weapon
	if def.ReloadPerShell then
		-- One round at a time (pump shotgun): ReloadSeconds is the time for each, and another follows until full.
		if state.reserve > 0 and state.mag < def.MagSize then
			state.mag += 1
			state.reserve -= 1
		end
		if state.reserve > 0 and state.mag < def.MagSize then
			state.reloadEndsAt = os.clock() + def.ReloadSeconds
			sendAmmo(player, state, def.ReloadSeconds)
			local id = state.reloadId
			task.delay(def.ReloadSeconds, function()
				if states[player] == state and state.reloadId == id and not state.dead then
					finishReload(player, state)
				end
			end)
			return
		end
		state.reloadEndsAt = 0
		sendAmmo(player, state, 0)
		return
	end
	state.reloadEndsAt = 0
	local take = math.min(def.MagSize - state.mag, state.reserve)
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
	if not (state and humanoid and root) or state.dead or isDowned(player) or frozen[player] then
		return
	end
	local def = state.weapon
	if weaponId ~= def.Id or def.Melee then
		return -- a melee weapon (garrote, hammer) has nothing to fire
	end
	if state.takedown or state.chargeStartedAt then
		sendAmmo(player, state, 0)
		return
	end
	local directions = directionsOf(def, direction)
	if not directions then
		return
	end
	local now = os.clock()
	if state.reloadEndsAt ~= 0 and def.ReloadPerShell then
		-- A shot interrupts a shell-by-shell reload and keeps the rounds already loaded; a shell that is due counts.
		if now >= state.reloadEndsAt - config.FireRateToleranceSeconds then
			finishReload(player, state)
		end
		if state.mag > 0 then
			state.reloadId += 1
			state.reloadEndsAt = 0
			sendAmmo(player, state, 0)
		else
			return
		end
	elseif state.reloadEndsAt ~= 0 then
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
	local hooks = projectileHooks
	if def.Projectile and not (hooks and hooks.canLaunch(player)) then
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
	local magBeforeShot = state.mag -- the server's own count decides which rounds are smoke (Feint's SMG)
	state.mag -= 1
	-- Guise's pistol: the first shot fired while Covered is an ambush shot (STEP8 answers: Covered, not Suspicious).
	local ambush = if def.AmbushMult and CoverService.isCovered(player) then def.AmbushMult else 1

	-- Firing breaks Cover and starts the lockout (spec 7.2 #1, 7.6); NPCs hear it (spec 5.4).
	CoverService.expose(player, "Fired")
	CoverService.startLockout(player)
	local hearStuds = def.HearStuds
		or (if def.Quiet then GameConfig.Audio.SuppressedWeaponRadius else GameConfig.Audio.DefaultWeaponRadius)
	local silent = hearStuds <= 0 -- throwing knives: no gunshot, so no NPC panic and nobody hears it
	local soundOrigin = soundOriginOf(def, origin)
	if not silent and provokeHooks then
		provokeHooks.fired(player, soundOrigin, hearStuds)
	end
	if def.Projectile and hooks then
		hooks.launch(player, def, origin, directions[1])
		if not silent and now - state.lastReactAt >= config.GunfireReactSeconds then
			state.lastReactAt = now
			NPCService.gunshot(soundOrigin, hearStuds)
		end
		return
	end
	if not silent and now - state.lastReactAt >= config.GunfireReactSeconds then
		state.lastReactAt = now
		NPCService.gunshot(soundOrigin, hearStuds)
	end

	local pierce = def.Pierce
	local maxHits = 1 + (if pierce then pierce.Count else 0)
	local struckAnyone = false
	local aggregate = def.SurvivesFullHealth or def.Stagger
	local tallies: { [Target]: Tally } = {}
	local tallyOrder: { Target } = {}
	local smoke = def.Smoke
	for _, ray in directions do
		local hits, endPoint, hitWall, shield = Ballistics.trace(player, origin, ray, timestamp, maxHits)
		if hitWall and worldHitListener then
			worldHitListener(endPoint, player)
		end
		if shield then
			Shields.damage(shield, def.Damage * falloffMult(def, (endPoint - origin).Magnitude)) -- ticket 16b
		end
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
			if aggregate then
				local tally = tallies[target]
				if not tally then
					tally = { amount = 0, head = false, pellets = 0 }
					tallies[target] = tally
					table.insert(tallyOrder, target)
				end
				tally.amount += amount
				tally.head = tally.head or head
				tally.pellets += 1
			else
				applyDamage(player, target, amount, head, origin)
			end
			struckAnyone = true
		end
		if smoke and magBeforeShot <= smoke.Rounds and (#hits > 0 or hitWall) then
			local cloud: Types.SmokeCloudInfo = {
				Position = endPoint,
				Radius = smoke.Radius,
				ExpiresAt = workspace:GetServerTimeNow() + smoke.Seconds,
			}
			RemoteService.fireAllClients("SmokeCloud", cloud)
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
	for _, target in tallyOrder do
		local tally = tallies[target]
		local victim = target.player
		local victimState = if victim then states[victim] else nil
		local amount = tally.amount
		-- Pump shotgun: an agent who starts the pull at full health keeps at least 1 HP, plates or none.
		if def.SurvivesFullHealth and victimState and victimState.hp >= config.MaxHP then
			amount = math.min(amount, victimState.armor + victimState.hp - 1)
		end
		local result = applyDamage(player, target, amount, tally.head, origin)
		local stagger = def.Stagger
		if
			stagger
			and result ~= nil
			and victim
			and victimState
			and not victimState.dead
			and not isDowned(victim)
			and tally.pellets >= stagger.MinPellets
			and (target.rootPart.Position - origin).Magnitude <= stagger.WithinStuds
		then
			DisguiseService.applySlow(victim, stagger.SlowMult, stagger.Seconds)
			local status: Types.CombatStatusInfo = {
				Kind = "Stagger",
				Seconds = stagger.Seconds,
				SlowMult = stagger.SlowMult,
				AimBumpDegrees = stagger.AimBumpDegrees,
				From = origin,
			}
			RemoteService.fireClient("CombatStatus", victim, status)
		end
	end
	if struckAnyone then
		CoverService.startLockout(player) -- dealing damage refreshes it (spec 7.6)
	end
end

local function onReload(player: Player)
	local state = states[player]
	local humanoid = aliveParts(player)
	if not (state and humanoid) or state.dead or isDowned(player) then
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
	cancelMelee(player, state)
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
	if not state then
		return
	end
	cancelMelee(player, state)
	if state.reloadEndsAt == 0 then
		return
	end
	state.reloadId += 1
	state.reloadEndsAt = 0
	sendAmmo(player, state, 0)
end

local function onDraw(player: Player, drawn: unknown)
	if type(drawn) ~= "boolean" or not states[player] or (drawn and isDowned(player)) then
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
local function findMeleeTarget(
	player: Player,
	root: BasePart,
	look: Vector3,
	takedownOnly: boolean,
	swingReach: number?
): Target?
	local melee = config.Melee
	local reach = (swingReach or melee.Range) + melee.ReachSlackStuds
	local best: Target? = nil
	local bestDistance = math.huge
	for _, target in History.targets do
		if
			target.player ~= player
			and not (target.player and TeamService.areTeammates(player, target.player))
			and not (target.player and isDowned(target.player))
			and not (target.npc and Death.isDown(target.npc))
		then
			local offset = target.rootPart.Position - root.Position
			local flat = Vector3.new(offset.X, 0, offset.Z)
			local distance = flat.Magnitude
			if
				distance < bestDistance
				and (if takedownOnly
					then MeleeRules.canTakedown(root.Position, look, target.rootPart.Position, facingOf(target))
					else MeleeRules.inReach(root.Position, look, target.rootPart.Position, reach))
				and workspace:Raycast(root.Position, offset, mapParams) == nil
			then
				best, bestDistance = target, distance
			end
		end
	end
	return best
end

-- The hammer's charged hit moves its target sideways, along the swinger's right (a flat horizontal swing). Walls stop
-- the push; an open edge does not, so a target near one falls. A player's body belongs to their own client, so they are
-- told and move themselves (CombatStatus "Shove"). SPEC-QUESTION: NPCs are not shoved yet (their position is driven by
-- the crowd's route); only damage reaches them.
local function shove(target: Target, look: Vector3, studs: number)
	local victim = target.player
	if not victim then
		return
	end
	local direction = Vector3.new(-look.Z, 0, look.X)
	local shoveConfig = config.Shove
	local from = target.rootPart.Position + Vector3.new(0, shoveConfig.ProbeUpStuds, 0)
	local wall = workspace:Raycast(from, direction * (studs + shoveConfig.WallClearanceStuds), mapParams)
	local allowed = if wall then math.max(0, wall.Distance - shoveConfig.WallClearanceStuds) else studs
	if allowed <= 0 then
		return
	end
	local status: Types.CombatStatusInfo =
		{ Kind = "Shove", Seconds = shoveConfig.Seconds, Direction = direction, Studs = allowed }
	RemoteService.fireClient("CombatStatus", victim, status)
end

local function onMelee(player: Player, kind: unknown, lookArg: unknown)
	local state = states[player]
	if not state or type(kind) ~= "string" then
		return
	end
	if kind == "Cancel" then
		cancelMelee(player, state)
		return
	end
	local humanoid, root = aliveParts(player)
	if not (humanoid and root) or state.dead or isDowned(player) or frozen[player] then
		cancelMelee(player, state)
		return
	end
	if kind == "Release" and state.takedown then
		cancelMelee(player, state)
		return
	end
	if
		(kind ~= "Press" and kind ~= "Release")
		or typeof(lookArg) ~= "Vector3"
		or lookArg ~= lookArg
		or lookArg.Magnitude == math.huge
	then
		return
	end
	local flatLook = Vector3.new(lookArg.X, 0, lookArg.Z)
	if flatLook.Magnitude < config.Melee.DirectionEpsilonStuds then
		cancelMelee(player, state)
		return
	end
	local look = flatLook.Unit
	local now = os.clock()
	if state.reloadEndsAt ~= 0 or DisguiseService.isChanging(player) then
		cancelMelee(player, state)
		sendMelee(player, false, "Charge")
		return
	end
	if kind == "Release" then
		local began = state.chargeStartedAt
		if not began then
			return
		end
		state.chargeStartedAt = nil
		local weaponMelee = state.weapon.Melee
		if
			now - state.lastMeleeAt < (if weaponMelee then weaponMelee.SwingSeconds else config.Melee.CooldownSeconds)
		then
			sendMelee(player, false, "Charge")
			return
		end
		state.lastMeleeAt = now
		CoverService.expose(player, "Melee")
		CoverService.startLockout(player)
		local charged = weaponMelee ~= nil
			and weaponMelee.ChargeSeconds ~= nil
			and now - began >= weaponMelee.ChargeSeconds
		local target = findMeleeTarget(player, root, look, false, if weaponMelee then weaponMelee.SwingReach else nil)
		if target then
			local damage = if weaponMelee
				then (if charged then weaponMelee.ChargeDamage or weaponMelee.SwingDamage else weaponMelee.SwingDamage)
				else MeleeRules.damage(now - began)
			local result = applyDamage(player, target, damage, false, root.Position)
			if result == "Hit" and charged and weaponMelee and weaponMelee.ShoveStuds then
				shove(target, look, weaponMelee.ShoveStuds)
			end
		end
		sendMelee(player, false, "Strike")
		return
	end
	if state.takedown or state.chargeStartedAt then
		return -- repeated presses never reset or accelerate a charge/hold
	end
	local weaponMelee = state.weapon.Melee
	if now - state.lastMeleeAt < (if weaponMelee then weaponMelee.SwingSeconds else config.Melee.CooldownSeconds) then
		sendMelee(player, false, "Charge")
		return
	end
	local target = findMeleeTarget(player, root, look, true)
	if target then
		CoverService.expose(player, "Takedown")
		CoverService.startLockout(player)
		state.takedown = {
			seconds = (weaponMelee and weaponMelee.TakedownSeconds) or config.Takedown.HoldSeconds,
			damage = (weaponMelee and weaponMelee.TakedownDamage) or config.Takedown.Damage,
			target = target,
			look = look,
			startedAt = now,
			startPosition = target.rootPart.Position,
		}
		local startedAt = workspace:GetServerTimeNow()
		holdVictim(target, true, startedAt)
		sendMelee(player, true, "Takedown", startedAt)
		return
	end
	state.chargeStartedAt = now
	sendMelee(player, true, "Charge", workspace:GetServerTimeNow())
end

-- Holds, completes or breaks every takedown in progress (spec 13.4). The server runs the timer.
local function checkTakedowns(now: number)
	for player, state in states do
		if state.chargeStartedAt then
			local humanoid = aliveParts(player)
			if
				not humanoid
				or state.dead
				or isDowned(player)
				or DisguiseService.isChanging(player)
				or state.reloadEndsAt ~= 0
			then
				cancelMelee(player, state)
			end
		end
		local takedown = state.takedown
		if takedown then
			local humanoid, root = aliveParts(player)
			local target = takedown.target
			if
				not (humanoid and root)
				or state.dead
				or isDowned(player)
				or DisguiseService.isChanging(player)
				or History.targets[target.id] ~= target
				or not MeleeRules.canTakedown(root.Position, takedown.look, target.rootPart.Position, facingOf(target))
				or workspace:Raycast(root.Position, target.rootPart.Position - root.Position, mapParams) ~= nil
				or (target.rootPart.Position - takedown.startPosition).Magnitude > config.Takedown.BreakDistance
				or state.lastDamagedAt > takedown.startedAt
			then
				cancelMelee(player, state)
			elseif now - takedown.startedAt >= takedown.seconds then
				state.takedown = nil
				state.lastMeleeAt = now
				holdVictim(target, false)
				-- R5-takedown: the server-confirmed result; only Downed or Eliminated may trigger a cosmetic finisher.
				local result = applyDamage(player, target, takedown.damage, false, (root :: BasePart).Position)
				sendMelee(player, false, "Strike", nil, result)
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
	local jumped = math.abs(y - state.lastY) > config.TeleportStuds
	state.lastY = y
	-- A zipline anchors the rider; a vent is crawled. Neither is a fall, and the height count starts again after.
	-- A teleport (spawning, being moved by the server) is not a fall, and the count starts again after it.
	if root.Anchored or VentService.isInside(player) or jumped then
		state.fallPeakY = y
		state.airborne = false
		return
	end
	local probe = humanoid.HipHeight + root.Size.Y / 2 + config.GroundProbeSlackStuds
	if workspace:Raycast(root.Position, Vector3.new(0, -probe, 0), mapParams) then
		if state.airborne then
			local fallen = state.fallPeakY - y
			if fallen > config.FallSafeStuds then
				local mult = rulesOf(player).FallDamageMult or 1
				damagePlayer(
					player,
					(fallen - config.FallSafeStuds) * config.FallDamagePerStud * mult,
					root.Position,
					nil
				)
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
	local deployed = loadoutWeapons[player] or config.DefaultWeapon
	local def = WeaponDefs.get(if RunService:IsStudio() then testWeapons[player] or deployed else deployed)
	assert(def, `Combat.DefaultWeapon {config.DefaultWeapon} is not a weapon`)
	local startPlates = (if TeamService.isSolos() then config.SoloStartPlates else config.StartPlates)
		+ (rulesOf(player).ExtraStartPlates or 0) -- Parapet's Plated
	local state: State = {
		weapon = def,
		hp = config.MaxHP,
		armor = startPlates * config.PlateHP,
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
		chargeStartedAt = nil,
		fallPeakY = root.Position.Y,
		lastY = root.Position.Y,
		airborne = false,
		dead = false,
		violations = 0,
		target = nil,
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
		state.target = target
		History.track(target)
	end

	humanoid.Died:Connect(function()
		state.dead = true
		cancelMelee(player, state)
		History.untrack(id)
	end)

	sendHealth(player, state)
	sendAmmo(player, state, 0)
	if RunService:IsStudio() then
		RemoteService.fireClient(
			"TestLoadoutChanged",
			player,
			{ WeaponId = def.Id, Mag = state.mag, Reserve = state.reserve, Reset = true }
		)
	end
end

-- Ticket studio-test-loadout: no IDs/stats accepted from a client. This method also supports explicit Studio probes.
function CombatService.testCycle(player: Player, action: unknown): boolean
	if not RunService:IsStudio() or type(action) ~= "string" then
		return false
	end
	local state = states[player]
	local humanoid = aliveParts(player)
	if not state or not humanoid or state.dead or isDowned(player) then
		return false
	end
	local nextDef = TestLoadout.nextWeapon(state.weapon.Id, action)
	if not nextDef then
		return false
	end
	if action ~= "Sync" then
		cancelReload(player)
		cancelMelee(player, state)
		state.reloadId += 1 -- invalidate delayed reload completion, even when the timer just elapsed
		state.reloadEndsAt = 0
		state.weapon = nextDef
		state.mag, state.reserve = nextDef.MagSize, nextDef.ReserveAmmo
		state.nextFireAt, state.lastMeleeAt = 0, -math.huge
		state.streak = FireRate.newStreak()
		state.aiming = false
		CoverService.setWeaponDrawn(player, false)
		testWeapons[player] = nextDef.Id
		RemoteService.fireClient("Notification", player, `STUDIO: {nextDef.Agent} / {nextDef.Name}`)
		print(`[StudioLoadout] {player.Name}: {nextDef.Id}`)
	end
	RemoteService.fireClient("TestLoadoutChanged", player, {
		WeaponId = state.weapon.Id,
		Mag = state.mag,
		Reserve = state.reserve,
		Reset = action ~= "Sync",
	})
	return true
end

-- Read-only server-side Studio diagnostics; never sent to another player or stored on a rig.
function CombatService.getTestWeaponId(player: Player): string?
	if not RunService:IsStudio() then
		return nil
	end
	local state = states[player]
	return if state and not state.dead then state.weapon.Id else nil
end

-- Ticket menu-services: the weapon this player carries from their next spawn on. The caller has validated it
-- (MetaProgressionService.validateLoadout). A Studio test selection made before deploying is dropped.
function CombatService.setLoadoutWeapon(player: Player, weaponId: string)
	assert(WeaponDefs.get(weaponId), `Loadout weapon {weaponId} is not a weapon`)
	loadoutWeapons[player] = weaponId
	testWeapons[player] = nil
end

function CombatService.setDownedHooks(hooks: DownedHooks)
	downedHooks = hooks
end

-- ProjectileService registers itself here at Start (flares and throwing knives are launched by it).
-- Ticket 14: told where each shot ends on the map and who fired it (CameraService: a shot that ends on a camera destroys it).
function CombatService.setWorldHitListener(listener: (Vector3, Player) -> ())
	worldHitListener = listener
end

-- Ticket 15: GuardService registers itself here at Start.
function CombatService.setProvokeHooks(hooks: ProvokeHooks)
	provokeHooks = hooks
end

-- Ticket 16e (Suture): gives back health, up to the maximum. Nothing else heals in the game (spec 13.1). A downed or dead
-- player is not healed (a revive is DownedService's).
function CombatService.heal(player: Player, amount: number)
	local state = states[player]
	if not state or state.dead or isDowned(player) or state.hp >= config.MaxHP then
		return
	end
	state.hp = math.min(config.MaxHP, state.hp + amount)
	sendHealth(player, state)
end

-- Ticket 17 (Med Injector): is the player hurt (alive, on their feet, below full health)?
function CombatService.isHurt(player: Player): boolean
	local state = states[player]
	return state ~= nil and not state.dead and not isDowned(player) and state.hp < config.MaxHP
end

-- Ticket 17 (Plate Pack): puts one armour plate on the player, if they have room for it (MaxPlates). A downed or dead player
-- takes none. Returns whether it went on.
function CombatService.addPlate(player: Player): boolean
	local state = states[player]
	if not state or not CombatService.canTakePlate(player) then
		return false
	end
	state.armor = math.min(config.MaxPlates * config.PlateHP, state.armor + config.PlateHP)
	sendHealth(player, state)
	return true
end

-- Ticket 17: can the player take a plate now (alive, on their feet, and short of MaxPlates)?
function CombatService.canTakePlate(player: Player): boolean
	local state = states[player]
	return state ~= nil
		and not state.dead
		and not isDowned(player)
		and state.armor <= (config.MaxPlates - 1) * config.PlateHP
end

-- Ticket 16e: how long since the player last took damage (a very long time if never).
function CombatService.secondsSinceDamaged(player: Player): number
	local state = states[player]
	return if state then os.clock() - state.lastDamagedAt else 0
end

-- Ticket 16d: is the player aiming (scoped) their weapon right now?
function CombatService.isAiming(player: Player): boolean
	local state = states[player]
	return state ~= nil and state.aiming and not state.dead
end

-- Ticket 16c: DroneService is told whenever a player takes damage.
function CombatService.setDamageListener(listener: (Player) -> ())
	damageListener = listener
end

-- Ticket 16: AbilityService gives the GameConfig.Agents numbers of a player's agent: ExtraStartPlates (Parapet's Plated),
-- FallDamageMult (Reticle's Still Water).
function CombatService.setAgentRules(lookup: (Player) -> { [string]: any })
	agentRules = lookup
end

function CombatService.setProjectileHooks(hooks: ProjectileHooks)
	projectileHooks = hooks
end

-- A projectile (or its splash) hit `target` for `amount`. The teammate guard, hitmarker and DamageTaken are the same as
-- for a bullet. Returns what the hit did, or nil when a teammate was spared.
function CombatService.damageTarget(
	shooter: Player,
	target: Target,
	amount: number,
	head: boolean,
	from: Vector3
): Types.MeleeResult?
	local result = applyDamage(shooter, target, amount, head, from)
	if result ~= nil then
		CoverService.startLockout(shooter) -- dealing damage refreshes it (spec 7.6)
	end
	return result
end

-- Ticket 13B-b: a bot fires. Everyone within earshot hears it and the crowd reacts as to any shot; a victim is hurt (no
-- attacker is credited: bots are not Players).
function CombatService.botFire(
	origin: Vector3,
	hit: Vector3,
	victim: Player?,
	amount: number,
	hearStuds: number,
	weaponId: string
)
	NPCService.gunshot(origin, hearStuds)
	local info: Types.ShotInfo = { Origin = origin, Hit = hit, WeaponId = weaponId, Struck = victim ~= nil }
	for _, other in Players:GetPlayers() do
		local _, otherRoot = aliveParts(other)
		if otherRoot and (otherRoot.Position - origin).Magnitude <= hearStuds then
			RemoteService.fireClient("ShotHeard", other, info)
		end
	end
	if victim then
		damagePlayer(victim, amount, origin, nil)
	end
end

-- Puts up to `count` rounds back into the magazine of a player who carries a Projectile weapon of this kind (picking up
-- a landed knife; no reserve exists to refill from). Returns how many fitted.
-- Ticket 18b (Ammo Cache): does the player's weapon have room for more rounds (magazine or reserve below full)?
function CombatService.canRefillAmmo(player: Player): boolean
	local state = states[player]
	return state ~= nil
		and not state.dead
		and not isDowned(player)
		and (state.mag < state.weapon.MagSize or state.reserve < state.weapon.ReserveAmmo)
end

-- Ticket 18b: a full magazine and a full reserve for the weapon in hand.
function CombatService.refillAmmo(player: Player)
	local state = states[player]
	if state and CombatService.canRefillAmmo(player) then
		state.mag, state.reserve = state.weapon.MagSize, state.weapon.ReserveAmmo
		sendAmmo(player, state, 0)
	end
end

function CombatService.refillThrowable(player: Player, kind: string, count: number): number
	local state = states[player]
	local def = state and state.weapon
	if not state or not def or state.dead or isDowned(player) or not def.Projectile or def.Projectile.Kind ~= kind then
		return 0
	end
	local fits = math.clamp(def.MagSize - state.mag, 0, count)
	if fits > 0 then
		state.mag += fits
		sendAmmo(player, state, 0)
	end
	return fits
end

-- Whether this player is holding a Projectile weapon of this kind and can use it now.
function CombatService.canUseThrowable(player: Player, kind: string): boolean
	local state = states[player]
	local def = state and state.weapon
	return state ~= nil
		and def ~= nil
		and not state.dead
		and not isDowned(player)
		and def.Projectile ~= nil
		and def.Projectile.Kind == kind
end

-- Studio only (tools/CheckWeaponServerRules): carry a weapon that is not registered in WeaponDefs yet, with full ammo,
-- so its server rules can be exercised before the client side exists. Not reachable from a client.
function CombatService.testEquip(player: Player, def: WeaponDef): boolean
	local state = states[player]
	if not RunService:IsStudio() or not state or state.dead then
		return false
	end
	cancelReload(player)
	cancelMelee(player, state)
	state.reloadId += 1
	state.reloadEndsAt = 0
	state.weapon = def
	state.mag, state.reserve = def.MagSize, def.ReserveAmmo
	state.nextFireAt, state.lastMeleeAt = 0, -math.huge
	state.streak = FireRate.newStreak()
	state.aiming = false
	sendAmmo(player, state, 0)
	return true
end

-- Whether shots and melee can find this player (false while downed, like a downed NPC).
function CombatService.setTargetable(player: Player, targetable: boolean)
	local state = states[player]
	local target = state and state.target
	if not target then
		return
	end
	if targetable then
		History.track(target)
	else
		History.untrack(target.id)
	end
end

-- Puts a player back on their feet with this health and armour (spec 14.1 revive).
function CombatService.restore(player: Player, hp: number, armor: number)
	local state = states[player]
	if not state then
		return
	end
	state.hp, state.armor = hp, armor
	state.dead = false
	cancelMelee(player, state)
	sendHealth(player, state)
end

-- Ticket 10a: a frozen player (the Insertion phase) cannot fire or melee; the server drops those requests.
function CombatService.setFrozen(player: Player, isFrozen: boolean)
	frozen[player] = if isFrozen then true else nil
	if isFrozen then
		CombatService.disarm(player)
	end
end

-- Ends what a player was doing with their weapon (going down: no aim, no reload, no takedown).
function CombatService.disarm(player: Player)
	local state = states[player]
	if not state then
		return
	end
	state.aiming = false
	cancelMelee(player, state)
	if state.reloadEndsAt ~= 0 then
		state.reloadId += 1
		state.reloadEndsAt = 0
		sendAmmo(player, state, 0)
	end
	CoverService.setWeaponDrawn(player, false)
end

function CombatService.Init()
	assert(WeaponDefs.get(config.DefaultWeapon), "Combat.DefaultWeapon must name a weapon in WeaponDefs")
end

function CombatService.Start()
	if RunService:IsStudio() then
		RemoteService.onRequest("RequestTestLoadout", function(player: Player, action: unknown)
			CombatService.testCycle(player, action)
		end)
	end
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
		frozen[player] = nil
		testWeapons[player] = nil
		loadoutWeapons[player] = nil
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
