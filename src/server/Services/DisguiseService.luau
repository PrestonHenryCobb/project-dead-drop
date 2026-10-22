--!strict
-- Disguises (spec 6): scanning an NPC or another agent to copy how they look, keeping it in a slot, and putting it on.
--
--   * Scan: aim at a character within ScanRange and hold for ScanSeconds. The server checks range and line of sight
--     the whole time and cancels the scan if either fails. Scanning is silent: the target gets no sign of it.
--   * Disguise: puts on the slot's outfit, or the insertion outfit if the slot is empty or already worn. Takes
--     DisguiseSeconds, and is refused where the new disguise's tier is below the zone the player is standing in.
--   * Speed: a disguised player walks at their disguise role's speed. Sprint (RequestSprint) is allowed at the
--     sprint speed; making it suspicious is Step 7.
--
-- A player is dressed through OutfitApplier, the same code NPCs go through, so a disguise is identical to the NPC it
-- copied (outfit, scale, face). Nothing is stored on the character: the state lives only here.
--
--   DisguiseService.spawn(player, character)   dresses a freshly spawned character in a random Guest insertion outfit
--   DisguiseService.setNpcLookup(function(id) -> NpcInfo?)   how scans find NPCs; NPCService provides it

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
local ZoneService = require(script.Parent.ZoneService)

type OutfitDef = Types.OutfitDef

-- What a scan needs to know about an NPC.
export type NpcInfo = {
	outfit: OutfitDef,
	position: Vector3,
	scannable: boolean, -- false while it is downed or down for good
}

type Scan = {
	targetId: string,
	startedAt: number,
}

type State = {
	insertion: OutfitDef,
	worn: OutfitDef,
	slot: OutfitDef?, -- one slot for now (Cover.DisguiseSlots); the second slot comes with Vesper in Step 16
	scan: Scan?,
	applyId: number, -- bumped whenever a disguise change starts or is cancelled
	sprinting: boolean,
}

local DisguiseService = {}

local config = GameConfig.Cover
local rng = Random.new()
local states: { [Player]: State } = {}
local npcLookup: ((string) -> NpcInfo?)? = nil
local validateAccumulator = 0

-- Rays in the character group skip characters and only meet the map.
local sightParams = RaycastParams.new()
sightParams.CollisionGroup = GameConfig.Rig.CollisionGroup

function DisguiseService.setNpcLookup(lookup: (string) -> NpcInfo?)
	npcLookup = lookup
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
	if state.sprinting then
		return GameConfig.Speeds.Sprint
	end
	return GameConfig.NPC.WalkSpeed[state.worn.Role]
end

local function sendUpdate(player: Player, state: State)
	local update: Types.DisguiseUpdate = {
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
				-- Scanning a player copies the NPC disguise they wear, never anything else (spec 6.3).
				return { outfit = otherState.worn, position = root.Position, scannable = true }
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
	state.scan = { targetId = targetId, startedAt = os.clock() }
	RemoteService.fireClient("ScanState", player, { State = "Started", Seconds = config.ScanSeconds })
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
			elseif os.clock() - scan.startedAt >= config.ScanSeconds then
				finishScan(player, state, target)
			end
		end
	end
end

-- A short puff where the swap happened, visible to anyone close enough to see it (spec 6.4).
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

local function onRequestDisguise(player: Player)
	local state = states[player]
	local humanoid, root = aliveRoot(player)
	if not (state and humanoid and root) then
		return
	end
	cancelScan(player, state)

	local target = state.insertion
	if state.slot and state.slot ~= state.worn then
		target = state.slot
	end
	if target == state.worn then
		return
	end
	if ZoneService.tierAt(root.Position) > target.Tier then
		notify(player, "You can't change into that here")
		return
	end

	state.applyId += 1
	local applyId = state.applyId
	task.delay(config.DisguiseSeconds, function()
		local stillHumanoid, stillRoot = aliveRoot(player)
		if states[player] ~= state or state.applyId ~= applyId or not (stillHumanoid and stillRoot) then
			return
		end
		-- The player may have walked somewhere the disguise is not allowed since they pressed the key.
		if ZoneService.tierAt(stillRoot.Position) > target.Tier then
			notify(player, "You can't change into that here")
			return
		end
		puff(stillRoot)
		wear(player, state, target, stillHumanoid.Parent :: Model, stillHumanoid)
	end)
end

local function onRequestScan(player: Player, targetId: unknown)
	local state = states[player]
	if not state then
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
	if not state or not humanoid or typeof(on) ~= "boolean" then
		return
	end
	state.sprinting = on
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
		slot = nil,
		scan = nil,
		applyId = 0,
		sprinting = false,
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
