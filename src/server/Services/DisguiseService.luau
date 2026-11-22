--!strict
-- Disguises (spec 6): scanning an NPC or another agent to copy how they look, keeping it in a slot, and putting it on.
-- Also what a player looks like and how fast they move once exposed (spec 6.1, 7.2).
--
--   * Scan: aim at a character within ScanRange and hold for ScanSeconds. The server checks range and line of sight
--     the whole time and cancels the scan if either fails. Scanning is silent: the target gets no sign of it.
--     Scanning an Exposed agent takes ExposedScanSeconds and copies the disguise they last wore.
--   * Disguise: puts on the slot's outfit, or the insertion outfit if the slot is empty or already worn. Takes
--     DisguiseSeconds, and is refused where the new disguise's tier is below the zone the player is standing in. No
--     puff: rivals nearby see a swap marker instead (SwapMarkerService, brief Q6), and no reload runs during it.
--   * Exposed: CoverService calls expose(). The disguise is stripped (puff, then True Form) and the player moves at
--     the exposed speed. Pressing Disguise again re-covers, if CoverService allows it, in a NEW random outfit of the
--     same tier as the last disguise (STEP7_QUESTIONS E2). The stored slot is kept.
--   * Speed: a disguised player walks at their disguise role's speed. Sprint and crouch are requests from the client.
--
-- A player is dressed through OutfitApplier, the same code NPCs go through, so a disguise is identical to the NPC it
-- copied (outfit, scale, face). Nothing is stored on the character: the state lives only here.
--
--   DisguiseService.spawn(player, character)   dresses a freshly spawned character in a random Guest insertion outfit
--   DisguiseService.applySlow(player, mult, seconds)   walking speed times mult for a while (stagger)
--   DisguiseService.setCarrier(player, carrying)       the Package carrier: 90 percent speed, no disguise actions (13a)
--   DisguiseService.setFrozen(player, frozen)          walking speed 0 while true (Insertion, ticket 10a)
--   DisguiseService.setNpcLookup(function(id) -> NpcInfo?)   how scans find NPCs; NPCService provides it
--   DisguiseService.setCoverHooks(hooks)       how CoverService limits scanning and re-covering

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Effects = require(script.Parent.Parent.Combat.Effects)
local KitRules = require(script.Parent.Parent.Combat.KitRules)
local Smoke = require(script.Parent.Parent.Combat.Smoke)
local OutfitDefs = require(Shared:WaitForChild("Defs"):WaitForChild("OutfitDefs"))
local Types = require(Shared:WaitForChild("Types"))
local OutfitApplier = require(Shared:WaitForChild("Util"):WaitForChild("OutfitApplier"))
local RemoteService = require(script.Parent.RemoteService)
local SwapMarkerService = require(script.Parent.SwapMarkerService)
local ZoneService = require(script.Parent.ZoneService)

type OutfitDef = Types.OutfitDef

-- What a scan needs to know about an NPC.
export type NpcInfo = {
	outfit: OutfitDef,
	position: Vector3,
	scannable: boolean, -- false while it is downed or down for good
	scanSeconds: number?, -- how long this target takes to scan, if not the usual
}

-- What CoverService lends us so cover rules limit scanning and re-covering.
export type CoverHooks = {
	canScan: (Player) -> boolean, -- not in combat lockout (spec 6.3)
	canRecover: (Player) -> boolean, -- an Exposed player may put a disguise back on (spec 7.5)
	onRecovered: (Player) -> (), -- the disguise is back on
	canQuickChange: (Player) -> boolean, -- ticket 16a: Quick Change is allowed (not tracked, not carrying the Package)
	canKit: (Player) -> boolean, -- ticket 17b: the Disguise Kit is allowed (not tracked, no lockout, not carrying the Package)
}

type Scan = {
	targetId: string,
	startedAt: number,
	seconds: number,
}

type State = {
	player: Player,
	insertion: OutfitDef,
	worn: OutfitDef, -- the look on the character now (TrueForm while Exposed)
	lastDisguise: OutfitDef, -- the last NPC disguise worn; what an Exposed player is scanned as, and the re-cover tier
	exposed: boolean,
	slots: { OutfitDef }, -- stored disguises, filled in order, up to slotLimit (Cover.DisguiseSlots; Guise has two)
	scan: Scan?,
	applyId: number, -- bumped whenever a disguise change starts or is cancelled
	swapEndsAt: number, -- when the disguise change in progress finishes; 0 when none is
	sprinting: boolean,
	crouching: boolean,
	slowUntil: number, -- os.clock() until which walking is slowed (a pump shotgun stagger)
	slowMult: number,
	slowId: number, -- bumped by each slow, so an older one's expiry never ends a newer one
	autoSince: number?, -- ticket auto-recover: when the re-cover ring began, if one is running
}

local DisguiseService = {}

local config = GameConfig.Cover
local rng = Random.new()
local states: { [Player]: State } = {}
local carriers: { [Player]: boolean } = {} -- ticket 13a: holds the Package: slower, and cannot disguise
local frozen: { [Player]: boolean } = {} -- ticket 10a: Insertion; set before the character (and its State) exists
local noSprint: { [Player]: boolean } = {} -- ticket 17e: holding the Briefcase Shield
local npcLookup: ((string) -> NpcInfo?)? = nil
local coverHooks: CoverHooks? = nil
local swapListeners: { (Player) -> () } = {}
local recoverListeners: { (Player, number) -> () } = {}
local recoverEndedListeners: { (Player) -> () } = {}

local function endRecover(player: Player)
	for _, listener in recoverEndedListeners do
		task.spawn(listener, player)
	end
end
local actionBlocker: ((Player) -> boolean)? = nil
local swapBlocker: ((Player) -> boolean)? = nil
local autoRecover: { [Player]: boolean } = {} -- ticket auto-recover: the option where the player has changed it
local autoElapsed = 0
local validateAccumulator = 0

-- Rays in the character group skip characters and only meet the map.
local sightParams = RaycastParams.new()
sightParams.CollisionGroup = GameConfig.Rig.CollisionGroup
sightParams.RespectCanCollide = true -- an open door does not block sight

function DisguiseService.setNpcLookup(lookup: (string) -> NpcInfo?)
	npcLookup = lookup
end

function DisguiseService.setCoverHooks(hooks: CoverHooks)
	coverHooks = hooks
end

-- Called when a player starts changing disguise (spec 27 #22: Combat cancels a reload).
function DisguiseService.onSwapStarted(listener: (Player) -> ())
	table.insert(swapListeners, listener)
end

-- Called when an Exposed player starts putting a disguise back on, with how long it takes (WristWatchService shows a watch for it).
function DisguiseService.onRecoverBegan(listener: (Player, number) -> ())
	table.insert(recoverListeners, listener)
end

-- Called when that re-cover is over, however it ended (done, refused at the last moment, or the auto ring was cancelled).
function DisguiseService.onRecoverEnded(listener: (Player) -> ())
	table.insert(recoverEndedListeners, listener)
end

-- Something that stops all disguise actions for a player (DownedService: a downed agent cannot scan, change or
-- re-cover).
function DisguiseService.setActionBlocker(blocker: (Player) -> boolean)
	actionBlocker = blocker
end

-- Something that stops only a disguise swap (LaserService: no changing inside a laser beam, spec 27 #23). Scanning,
-- sprinting and crouching are not affected.
function DisguiseService.setSwapBlocker(blocker: (Player) -> boolean)
	swapBlocker = blocker
end

-- The selected Instinct's disguise numbers (GameConfig.Instincts), or the usual ones.
local function agentRules(player: Player): { DisguiseSlots: number?, ScanSeconds: number?, DisguiseSeconds: number? }
	return KitRules.of(player) :: any
end

local function slotLimit(player: Player): number
	return agentRules(player).DisguiseSlots or config.DisguiseSlots
end

local function blocked(player: Player): boolean
	local blocker = actionBlocker
	return carriers[player] == true or (blocker ~= nil and blocker(player))
end

local function swapBlocked(player: Player): boolean
	local blocker = swapBlocker
	return blocked(player) or (blocker ~= nil and blocker(player))
end

-- Is a disguise change under way?
function DisguiseService.isChanging(player: Player): boolean
	local state = states[player]
	return state ~= nil and os.clock() < state.swapEndsAt
end

function DisguiseService.isExposed(player: Player): boolean
	local state = states[player]
	return state ~= nil and state.exposed
end

-- The clearance tier of the look on the character (spec 6.2). An Exposed agent has none (spec 6.2: any Tier 1+ zone
-- treats them as a trespasser), which is tier 0 here.
function DisguiseService.getClearance(player: Player): number
	local state = states[player]
	if not state or state.exposed then
		return 0
	end
	return state.worn.Tier
end

-- The tier of the disguise an Exposed player would get back (spec 7.5), or the one worn now.
function DisguiseService.getDisguiseTier(player: Player): number
	local state = states[player]
	return if state then state.lastDisguise.Tier else 0
end

-- Ticket 16f: the look on the character now (True Form while Exposed).
function DisguiseService.wornOutfit(player: Player): OutfitDef?
	local state = states[player]
	return if state then state.worn else nil
end

function DisguiseService.getMovement(player: Player): (boolean, boolean)
	local state = states[player]
	if not state then
		return false, false
	end
	return state.sprinting, state.crouching
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

local function speedFor(state: State): number
	if frozen[state.player] then
		return 0
	end
	local walk = if state.exposed then GameConfig.Speeds.ExposedWalk else GameConfig.NPC.WalkSpeed[state.worn.Role]
	local slow = if os.clock() < state.slowUntil then state.slowMult else 1
	if carriers[state.player] then
		slow *= GameConfig.Package.CarrierSpeedMult
	end
	if state.crouching then
		return walk * GameConfig.Speeds.CrouchMult * slow
	elseif state.sprinting and not noSprint[state.player] then
		return GameConfig.Speeds.Sprint * slow
	end
	return walk * slow
end

local function sendUpdate(player: Player, state: State)
	local slots: { string | boolean } = {}
	for index = 1, slotLimit(player) do
		local stored = state.slots[index]
		slots[index] = if stored then stored.OutfitId else false
	end
	local update: Types.DisguiseUpdate = {
		Exposed = state.exposed,
		Worn = state.worn.OutfitId,
		Insertion = state.insertion.OutfitId,
		Slots = slots,
	}
	RemoteService.fireClient("DisguiseUpdate", player, update)
end

local function notify(player: Player, text: string)
	RemoteService.fireClient("Notification", player, text)
end

-- Who or what a scan target id names: an NPC, or another player's character. Returns its outfit and position.
local function resolveTarget(scanner: Player, targetId: string): NpcInfo?
	if npcLookup then
		local npc = npcLookup(targetId)
		if npc then
			return npc
		end
	end
	for other, otherState in states do
		local character = other.Character
		if other ~= scanner and character and character.Name == targetId then
			local humanoid, root = aliveRoot(other)
			if humanoid and root then
				-- Scanning a player copies the NPC disguise they wear, never anything else (spec 6.3). An Exposed
				-- one is scanned as the disguise they last wore, and it takes longer (OPEN_QUESTIONS C2).
				return {
					outfit = otherState.lastDisguise,
					position = root.Position,
					scannable = true,
					scanSeconds = if otherState.exposed then config.ExposedScanSeconds else nil,
				}
			end
		end
	end
	return nil
end

-- Range and line of sight, from the scanner's body to the target's (spec 6.3).
local function canScan(scanner: Player, target: NpcInfo): boolean
	local humanoid, root = aliveRoot(scanner)
	if not (humanoid and root) or not target.scannable then
		return false
	end
	if coverHooks and not coverHooks.canScan(scanner) then
		return false
	end
	local offset = target.position - root.Position
	if
		Vector3.new(offset.X, 0, offset.Z).Magnitude
		> config.ScanRange * Effects.get(scanner, "ScanRange", 1) + config.ScanRangeSlack
	then
		return false
	end
	local lift = Vector3.new(0, config.ScanSightHeight, 0)
	local from = root.Position + lift
	local to = target.position + lift
	return workspace:Raycast(from, to - from, sightParams) == nil and not Smoke.blocks(from, to)
end

local function cancelScan(player: Player, state: State)
	if state.scan then
		state.scan = nil
		RemoteService.fireClient("ScanState", player, { State = "Cancelled" })
	end
end

local function startScan(player: Player, state: State, targetId: string)
	local target = resolveTarget(player, targetId)
	if not target or not canScan(player, target) then
		cancelScan(player, state)
		return
	end
	if state.scan and state.scan.targetId == targetId then
		return -- already scanning this one
	end
	cancelScan(player, state)
	state.applyId += 1 -- starting a scan cancels a disguise change in progress
	local seconds = (target.scanSeconds or agentRules(player).ScanSeconds or config.ScanSeconds)
		* Effects.get(player, "ScanTime", 1) -- Cold Read
	state.scan = { targetId = targetId, startedAt = os.clock(), seconds = seconds }
	RemoteService.fireClient("ScanState", player, { State = "Started", Seconds = seconds })
end

local function finishScan(player: Player, state: State, target: NpcInfo)
	state.scan = nil
	-- A free slot first; when all are full the newest scan replaces a stored look that is not the one being worn.
	if #state.slots < slotLimit(player) then
		table.insert(state.slots, target.outfit)
	else
		local replace = #state.slots
		for index = #state.slots, 1, -1 do
			if state.slots[index] ~= state.worn then
				replace = index
				break
			end
		end
		state.slots[replace] = target.outfit
	end
	RemoteService.fireClient("ScanState", player, { State = "Done" })
	sendUpdate(player, state)
end

-- Runs every ScanCheckSeconds for the scans in progress.
local function checkScans()
	for player, state in states do
		local scan = state.scan
		if scan then
			local target = resolveTarget(player, scan.targetId)
			if not target or not canScan(player, target) then
				cancelScan(player, state)
			elseif os.clock() - scan.startedAt >= scan.seconds then
				finishScan(player, state, target)
			end
		end
	end
end

-- A short puff where a disguise is stripped on exposure, visible to anyone close enough to see it (spec 7.2).
local function puff(root: BasePart)
	local anchor = Instance.new("Part")
	anchor.Name = "Puff"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Position = root.Position
	local emitter = Instance.new("ParticleEmitter")
	emitter.Enabled = false
	emitter.Lifetime = NumberRange.new(0.6, 1)
	emitter.Speed = NumberRange.new(3, 6)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new(0.8, 1.6)
	emitter.Transparency = NumberSequence.new(0.4, 1)
	emitter.Color = ColorSequence.new(Color3.fromRGB(235, 235, 240))
	emitter.Parent = anchor
	anchor.Parent = workspace
	emitter:Emit(config.DisguisePuffParticles)
	task.delay(config.DisguisePuffSeconds, function()
		anchor:Destroy()
	end)
end

local function wear(player: Player, state: State, outfit: OutfitDef, character: Model, humanoid: Humanoid)
	OutfitApplier.apply(character, outfit)
	state.worn = outfit
	humanoid.WalkSpeed = speedFor(state)
	sendUpdate(player, state)
end

-- Strips the disguise (spec 7.2): a puff, then True Form after ExposeStripSeconds. The player counts as exposed from
-- the moment this is called.
function DisguiseService.expose(player: Player)
	local state = states[player]
	if not state or state.exposed then
		return
	end
	cancelScan(player, state)
	state.applyId += 1
	state.swapEndsAt = 0
	local applyId = state.applyId
	state.exposed = true
	state.lastDisguise = state.worn
	state.sprinting = false
	state.crouching = false

	local _, root = aliveRoot(player)
	if root then
		puff(root)
	end
	task.delay(config.ExposeStripSeconds, function()
		local humanoid = aliveRoot(player)
		if states[player] ~= state or state.applyId ~= applyId or not humanoid then
			return
		end
		wear(player, state, OutfitDefs.trueForm, humanoid.Parent :: Model, humanoid)
	end)
	-- Tell the player now; the look follows after the strip.
	sendUpdate(player, state)
end

-- The look goes on: no puff on a disguise change, rivals nearby see a swap marker instead (brief Q6).
local function commit(player: Player, state: State, target: OutfitDef, humanoid: Humanoid, root: BasePart)
	local feet = root.Position - Vector3.new(0, humanoid.HipHeight + root.Size.Y / 2, 0)
	SwapMarkerService.place(player, feet, target.Tier)
	local wasExposed = state.exposed
	state.exposed = false
	state.lastDisguise = target
	wear(player, state, target, humanoid.Parent :: Model, humanoid)
	if wasExposed and coverHooks then
		coverHooks.onRecovered(player)
	end
end

local function onRequestDisguise(player: Player)
	local state = states[player]
	local humanoid, root = aliveRoot(player)
	if not (state and humanoid and root) or swapBlocked(player) then
		return
	end
	cancelScan(player, state)

	local target: OutfitDef
	if state.exposed then
		if not (coverHooks and coverHooks.canRecover(player)) then
			return
		end
		-- Re-covering gives a new random outfit of the same tier as the last disguise (STEP7_QUESTIONS E2).
		target = OutfitDefs.randomForTier(state.lastDisguise.Tier, rng)
	else
		-- Cycles through the stored looks, then the insertion outfit, to the one after the look worn now.
		local options: { OutfitDef } = table.clone(state.slots)
		table.insert(options, state.insertion)
		local worn = table.find(options, state.worn) or 0
		target = options[worn % #options + 1]
		if target == state.worn then
			return
		end
	end
	if ZoneService.tierAt(root.Position) > target.Tier then
		notify(player, "You can't change into that here")
		return
	end

	state.applyId += 1
	local applyId = state.applyId
	local seconds = agentRules(player).DisguiseSeconds or config.DisguiseSeconds -- Feint's Smoke and Mirrors: 0.3 s
	state.swapEndsAt = os.clock() + seconds
	if state.exposed then
		for _, listener in recoverListeners do
			task.spawn(listener, player, seconds)
		end
	end
	for _, listener in swapListeners do
		listener(player)
	end
	task.delay(seconds, function()
		local stillHumanoid, stillRoot = aliveRoot(player)
		if states[player] ~= state or state.applyId ~= applyId or not (stillHumanoid and stillRoot) then
			return
		end
		state.swapEndsAt = 0
		-- The player may have walked somewhere the disguise is not allowed since they pressed the key.
		if ZoneService.tierAt(stillRoot.Position) > target.Tier then
			notify(player, "You can't change into that here")
			endRecover(player)
			return
		end
		if state.exposed and not (coverHooks and coverHooks.canRecover(player)) then
			endRecover(player)
			return
		end
		commit(player, state, target, stillHumanoid, stillRoot)
		endRecover(player)
	end)
end

-- Ticket 16a (Guise's Quick Change, spec 15.1): switches to a stored look at once, ignoring the combat lockout. Refused while
-- Security is tracking the player or they carry the Package, when no stored look differs from the one worn, or where the
-- look's tier is below the zone. Returns false and a reason to show when refused.
-- Ticket 17b (Disguise Kit gadget): at once, a random Guest look without scanning anyone. Refused while Security tracks the
-- player, in combat lockout, or while carrying the Package, and where a Guest look is below the zone's tier. Returns false and a
-- reason when refused.
function DisguiseService.kitChange(player: Player): (boolean, string?)
	local state = states[player]
	local humanoid, root = aliveRoot(player)
	if not (state and humanoid and root) or swapBlocked(player) then
		return false, nil
	end
	if not (coverHooks and coverHooks.canKit(player)) then
		return false, "You can't change right now"
	end
	local target = OutfitDefs.random(Enums.Role.Guest, rng)
	for _ = 1, 4 do
		if target ~= state.worn then
			break
		end
		target = OutfitDefs.random(Enums.Role.Guest, rng)
	end
	if ZoneService.tierAt(root.Position) > target.Tier then
		return false, "You can't change into that here"
	end
	cancelScan(player, state)
	state.applyId += 1
	state.swapEndsAt = 0
	for _, listener in swapListeners do
		listener(player)
	end
	commit(player, state, target, humanoid, root)
	return true, nil
end

function DisguiseService.quickChange(player: Player): (boolean, string?)
	local state = states[player]
	local humanoid, root = aliveRoot(player)
	if not (state and humanoid and root) or swapBlocked(player) then
		return false, nil
	end
	local target: OutfitDef? = nil
	for _, stored in state.slots do
		if stored ~= state.worn then
			target = stored
			break
		end
	end
	if not target then
		return false, "No stored disguise to change into"
	elseif not (coverHooks and coverHooks.canQuickChange(player)) then
		return false, "You can't change right now"
	elseif ZoneService.tierAt(root.Position) > target.Tier then
		return false, "You can't change into that here"
	end
	cancelScan(player, state)
	state.applyId += 1 -- cancels a disguise change in progress
	state.swapEndsAt = 0
	for _, listener in swapListeners do
		listener(player)
	end
	commit(player, state, target, humanoid, root)
	return true, nil
end

-- Auto re-cover (ticket auto-recover) -------------------------------------------------------------------------------------

local function autoEnabled(player: Player): boolean
	local chosen = autoRecover[player]
	return if chosen ~= nil then chosen else config.AutoRecoverDefault
end

local function sendAuto(player: Player, active: boolean)
	local info: Types.AutoRecoverInfo =
		{ Enabled = autoEnabled(player), Active = active, Seconds = config.AutoRecoverSeconds }
	RemoteService.fireClient("AutoRecoverState", player, info)
end

-- An Exposed player who may re-cover (CoverService: no lockout, not tracked, in a zone their look allows, not carrying the
-- Package) starts a ring; when it has run its time the disguise goes back on as if they had pressed Disguise. If anything stops
-- re-covering the ring ends; they press Disguise at any time to do it at once.
local function checkAuto()
	local now = os.clock()
	for player, state in states do
		local ready = state.exposed
			and autoEnabled(player)
			and now >= state.swapEndsAt
			and not swapBlocked(player)
			and coverHooks ~= nil
			and coverHooks.canRecover(player)
		if ready and not state.autoSince then
			state.autoSince = now
			sendAuto(player, true)
			for _, listener in recoverListeners do
				task.spawn(listener, player, config.AutoRecoverSeconds)
			end
		elseif ready and state.autoSince and now - state.autoSince >= config.AutoRecoverSeconds then
			state.autoSince = nil
			sendAuto(player, false)
			onRequestDisguise(player)
		elseif not ready and state.autoSince then
			state.autoSince = nil
			sendAuto(player, false)
			endRecover(player) -- the ring was cancelled
		end
	end
end

local function onRequestAutoRecover(player: Player, on: unknown)
	if typeof(on) ~= "boolean" then
		return
	end
	autoRecover[player] = on
	notify(player, if on then "Auto re-cover on" else "Auto re-cover off")
	local state = states[player]
	if state and not on and state.autoSince then
		state.autoSince = nil
		endRecover(player)
	end
	sendAuto(player, state ~= nil and state.autoSince ~= nil)
end

local function onRequestScan(player: Player, targetId: unknown)
	local state = states[player]
	if not state or blocked(player) then
		return
	end
	if typeof(targetId) ~= "string" then
		cancelScan(player, state)
		return
	end
	startScan(player, state, targetId)
end

local function onRequestSprint(player: Player, on: unknown)
	local state = states[player]
	local humanoid = aliveRoot(player)
	if not state or not humanoid or typeof(on) ~= "boolean" or blocked(player) then
		return
	end
	state.sprinting = on
	humanoid.WalkSpeed = speedFor(state)
end

local function onRequestCrouch(player: Player, on: unknown)
	local state = states[player]
	local humanoid = aliveRoot(player)
	if not state or not humanoid or typeof(on) ~= "boolean" or blocked(player) then
		return
	end
	state.crouching = on
	humanoid.WalkSpeed = speedFor(state)
end

-- Picks a random Guest outfit no other player is currently wearing, so spawns do not start as twins (spec 6.5).
local function pickInsertion(player: Player): OutfitDef
	local taken: { [string]: boolean } = {}
	for other, otherState in states do
		if other ~= player then
			taken[otherState.worn.OutfitId] = true
		end
	end
	local options: { OutfitDef } = {}
	for _, outfit in OutfitDefs.byRole[Enums.Role.Guest] do
		if not taken[outfit.OutfitId] then
			table.insert(options, outfit)
		end
	end
	return options[rng:NextInteger(1, #options)]
end

-- Walking speed is multiplied by `mult` for `seconds` (a stagger). The server owns WalkSpeed, so the slow cannot be
-- ignored by the client. A newer slow replaces an older one.
function DisguiseService.applySlow(player: Player, mult: number, seconds: number)
	local state = states[player]
	local humanoid = aliveRoot(player)
	if not state or not humanoid then
		return
	end
	seconds *= KitRules.of(player).StatusMult or 1 -- Anchor
	state.slowId += 1
	local id = state.slowId
	state.slowUntil, state.slowMult = os.clock() + seconds, mult
	humanoid.WalkSpeed = speedFor(state)
	task.delay(seconds, function()
		local current = states[player]
		local nowHumanoid = aliveRoot(player)
		if current == state and state.slowId == id and nowHumanoid then
			nowHumanoid.WalkSpeed = speedFor(state)
		end
	end)
end

-- Ticket 13a: the Package carrier walks at CarrierSpeedMult and cannot scan, change or re-cover (spec 11).
function DisguiseService.setCarrier(player: Player, carrying: boolean)
	carriers[player] = if carrying then true else nil
	local state = states[player]
	local humanoid = aliveRoot(player)
	if state and humanoid then
		humanoid.WalkSpeed = speedFor(state)
	end
end

-- Ticket 17e: while true the player cannot sprint (their sprint request still stands, but they walk).
function DisguiseService.setSprintBlocked(player: Player, cannotSprint: boolean)
	noSprint[player] = if cannotSprint then true else nil
	local state = states[player]
	local humanoid = aliveRoot(player)
	if state and humanoid then
		humanoid.WalkSpeed = speedFor(state)
	end
end

-- Ticket 10a: no walking while frozen (the Insertion phase). Safe to call before the player's character exists.
function DisguiseService.setFrozen(player: Player, isFrozen: boolean)
	frozen[player] = if isFrozen then true else nil
	local state = states[player]
	local humanoid = aliveRoot(player)
	if state and humanoid then
		humanoid.WalkSpeed = speedFor(state)
	end
end

function DisguiseService.spawn(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local insertion = pickInsertion(player)
	local state: State = {
		player = player,
		insertion = insertion,
		worn = insertion,
		lastDisguise = insertion,
		exposed = false,
		slots = {},
		scan = nil,
		applyId = 0,
		swapEndsAt = 0,
		sprinting = false,
		crouching = false,
		slowUntil = 0,
		slowMult = 1,
		slowId = 0,
	}
	states[player] = state
	OutfitApplier.apply(character, insertion)
	humanoid.WalkSpeed = speedFor(state)
	sendUpdate(player, state)
	sendAuto(player, false) -- tells the client whether Auto re-cover is on
end

function DisguiseService.Init() end

function DisguiseService.Start()
	RemoteService.onRequest("RequestScan", onRequestScan)
	RemoteService.onRequest("RequestDisguise", onRequestDisguise)
	RemoteService.onRequest("RequestSprint", onRequestSprint)
	RemoteService.onRequest("RequestCrouch", onRequestCrouch)
	RemoteService.onRequest("RequestAutoRecover", onRequestAutoRecover)

	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
		frozen[player] = nil
		carriers[player] = nil
		autoRecover[player] = nil
		noSprint[player] = nil
	end)
	RunService.Heartbeat:Connect(function(dt)
		validateAccumulator += dt
		if validateAccumulator >= config.ScanCheckSeconds then
			validateAccumulator = 0
			checkScans()
		end
		autoElapsed += dt
		if autoElapsed >= 1 / config.AutoRecoverCheckHz then
			autoElapsed = 0
			checkAuto()
		end
	end)
end

return DisguiseService
