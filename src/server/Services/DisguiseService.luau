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
--   DisguiseService.setNpcLookup(function(id) -> NpcInfo?)   how scans find NPCs; NPCService provides it
--   DisguiseService.setCoverHooks(hooks)       how CoverService limits scanning and re-covering

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
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
}

type Scan = {
	targetId: string,
	startedAt: number,
	seconds: number,
}

type State = {
	insertion: OutfitDef,
	worn: OutfitDef, -- the look on the character now (TrueForm while Exposed)
	lastDisguise: OutfitDef, -- the last NPC disguise worn; what an Exposed player is scanned as, and the re-cover tier
	exposed: boolean,
	slot: OutfitDef?, -- one slot for now (Cover.DisguiseSlots); the second slot comes with Vesper in Step 16
	scan: Scan?,
	applyId: number, -- bumped whenever a disguise change starts or is cancelled
	swapEndsAt: number, -- when the disguise change in progress finishes; 0 when none is
	sprinting: boolean,
	crouching: boolean,
}

local DisguiseService = {}

local config = GameConfig.Cover
local rng = Random.new()
local states: { [Player]: State } = {}
local npcLookup: ((string) -> NpcInfo?)? = nil
local coverHooks: CoverHooks? = nil
local swapListeners: { (Player) -> () } = {}
local actionBlocker: ((Player) -> boolean)? = nil
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

-- Something that stops all disguise actions for a player (DownedService: a downed agent cannot scan, change or
-- re-cover).
function DisguiseService.setActionBlocker(blocker: (Player) -> boolean)
	actionBlocker = blocker
end

local function blocked(player: Player): boolean
	local blocker = actionBlocker
	return blocker ~= nil and blocker(player)
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
	local walk = if state.exposed then GameConfig.Speeds.ExposedWalk else GameConfig.NPC.WalkSpeed[state.worn.Role]
	if state.crouching then
		return walk * GameConfig.Speeds.CrouchMult
	elseif state.sprinting then
		return GameConfig.Speeds.Sprint
	end
	return walk
end

local function sendUpdate(player: Player, state: State)
	local update: Types.DisguiseUpdate = {
		Exposed = state.exposed,
		Worn = state.worn.OutfitId,
		Insertion = state.insertion.OutfitId,
		Slots = { if state.slot then state.slot.OutfitId else false },
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
	if Vector3.new(offset.X, 0, offset.Z).Magnitude > config.ScanRange + config.ScanRangeSlack then
		return false
	end
	local lift = Vector3.new(0, config.ScanSightHeight, 0)
	local from = root.Position + lift
	local to = target.position + lift
	return workspace:Raycast(from, to - from, sightParams) == nil
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
	local seconds = target.scanSeconds or config.ScanSeconds
	state.scan = { targetId = targetId, startedAt = os.clock(), seconds = seconds }
	RemoteService.fireClient("ScanState", player, { State = "Started", Seconds = seconds })
end

local function finishScan(player: Player, state: State, target: NpcInfo)
	state.scan = nil
	state.slot = target.outfit
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

local function onRequestDisguise(player: Player)
	local state = states[player]
	local humanoid, root = aliveRoot(player)
	if not (state and humanoid and root) or blocked(player) then
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
		target = state.insertion
		if state.slot and state.slot ~= state.worn then
			target = state.slot
		end
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
	state.swapEndsAt = os.clock() + config.DisguiseSeconds
	for _, listener in swapListeners do
		listener(player)
	end
	task.delay(config.DisguiseSeconds, function()
		local stillHumanoid, stillRoot = aliveRoot(player)
		if states[player] ~= state or state.applyId ~= applyId or not (stillHumanoid and stillRoot) then
			return
		end
		state.swapEndsAt = 0
		-- The player may have walked somewhere the disguise is not allowed since they pressed the key.
		if ZoneService.tierAt(stillRoot.Position) > target.Tier then
			notify(player, "You can't change into that here")
			return
		end
		if state.exposed and not (coverHooks and coverHooks.canRecover(player)) then
			return
		end
		-- No puff on a disguise change; rivals nearby see a swap marker instead (brief Q6).
		local feet = stillRoot.Position - Vector3.new(0, stillHumanoid.HipHeight + stillRoot.Size.Y / 2, 0)
		SwapMarkerService.place(player, feet, target.Tier)
		local wasExposed = state.exposed
		state.exposed = false
		state.lastDisguise = target
		wear(player, state, target, stillHumanoid.Parent :: Model, stillHumanoid)
		if wasExposed and coverHooks then
			coverHooks.onRecovered(player)
		end
	end)
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

function DisguiseService.spawn(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local insertion = pickInsertion(player)
	local state: State = {
		insertion = insertion,
		worn = insertion,
		lastDisguise = insertion,
		exposed = false,
		slot = nil,
		scan = nil,
		applyId = 0,
		swapEndsAt = 0,
		sprinting = false,
		crouching = false,
	}
	states[player] = state
	OutfitApplier.apply(character, insertion)
	humanoid.WalkSpeed = speedFor(state)
	sendUpdate(player, state)
end

function DisguiseService.Init()
	assert(config.DisguiseSlots == 1, "DisguiseService has one slot until the second slot is built in Step 16")
end

function DisguiseService.Start()
	RemoteService.onRequest("RequestScan", onRequestScan)
	RemoteService.onRequest("RequestDisguise", onRequestDisguise)
	RemoteService.onRequest("RequestSprint", onRequestSprint)
	RemoteService.onRequest("RequestCrouch", onRequestCrouch)

	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
	RunService.Heartbeat:Connect(function(dt)
		validateAccumulator += dt
		if validateAccumulator >= config.ScanCheckSeconds then
			validateAccumulator = 0
			checkScans()
		end
	end)
end

return DisguiseService
