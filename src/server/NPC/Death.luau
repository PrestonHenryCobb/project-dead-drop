--!strict
-- What happens to an NPC at 0 HP (spec 5.5, reworked in OPEN_QUESTIONS A7).
--
-- NPCs are not killed outright. They go down under the same rules as a downed player (spec 14.1): they drag
-- themselves away from the shot at Death.CrawlSpeed and bleed out after Downed.BleedOutSeconds, so a downed NPC and a
-- downed player look the same. A bled-out NPC lies still until WakeUp.Seconds after it went down, then stands up slowly
-- (the knockdown run backward) and goes back to its routine: nothing fades and nothing replaces it, so the crowd does not
-- thin (relayout-2, owner decision 2026-10-25). A body that stands up is always an NPC, because a player's body fades.
--
-- Bodies, downed or bled out, are what other NPCs react to (spec 5.4), so this keeps a list of them for the
-- reaction module. Downed and eliminated players are added too (DownedService), so NPCs react to any body alike.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local AnimationSync = require(script.Parent.AnimationSync)
local Movement = require(script.Parent.Movement)
local NavGraph = require(script.Parent.NavGraph)
local Knockdown = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("Knockdown"))
local NpcTypes = require(script.Parent.NpcTypes)

type Npc = NpcTypes.Npc
type Crowd = NpcTypes.Crowd
type Hooks = NpcTypes.Hooks

export type Body = {
	model: Model,
	npc: Npc?, -- nil for a player's body
	ground: () -> Vector3, -- where it lies
}

local Death = {}

local config = GameConfig.NPC
local WALL_CLEARANCE = 1 -- studs left between a crawling NPC and a wall
local PROBE_LIFT = Vector3.new(0, 1, 0)

-- Bodies currently lying around. Read by the reaction module.
Death.bodies = {} :: { Body }

local rayParams = RaycastParams.new()
rayParams.CollisionGroup = GameConfig.Rig.CollisionGroup -- characters do not collide with each other, so rays skip them

function Death.isDown(npc: Npc): boolean
	return npc.state == "Downed" or npc.state == "Eliminated" or npc.state == "Rising"
end

-- A short crawl directly away from where the shot came from (any direction if there was none), cut short by walls.
local function crawlPath(crowd: Crowd, npc: Npc, awayFrom: Vector3?): { Vector3 }
	local away = Vector3.zero
	if awayFrom then
		away = Vector3.new(npc.ground.X - awayFrom.X, 0, npc.ground.Z - awayFrom.Z)
	end
	if away.Magnitude < 1e-3 then
		local angle = crowd.rng:NextNumber(0, 2 * math.pi)
		away = Vector3.new(math.cos(angle), 0, math.sin(angle))
	end
	local step = away.Unit * config.Death.CrawlStuds
	local hit = workspace:Raycast(npc.ground + PROBE_LIFT, step, rayParams)
	if hit then
		step = step.Unit * math.max(0, (hit.Position - (npc.ground + PROBE_LIFT)).Magnitude - WALL_CLEARANCE)
	end
	-- Only onto floor (R1-ground); a downed body is not limited by tier.
	local spot = NavGraph.standable(crowd.graph, npc.ground, npc.ground + step, math.huge)
	return if spot then { spot } else {}
end

-- Puts an NPC down. `awayFrom` is where the shot or blast came from, if known. It falls the way the hit sends it
-- (Util/Knockdown, exactly as a player does), and crawls away once the fall is over.
function Death.down(crowd: Crowd, npc: Npc, awayFrom: Vector3?, now: number)
	if Death.isDown(npc) then
		return
	end
	crowd.release(npc.node)
	local facing = Vector3.new(-math.sin(npc.yaw), 0, -math.cos(npc.yaw))
	npc.fall = Knockdown.classify(facing, npc.ground, awayFrom)
	npc.posture = Knockdown.posture(npc.fall)
	npc.yaw = Knockdown.lyingYaw(npc.fall, npc.yaw)
	npc.downedAt = now
	npc.knockUntil = now + GameConfig.Downed.Knockdown.Seconds
	npc.state = "Downed"
	npc.stateUntil = now + GameConfig.Downed.BleedOutSeconds
	Movement.interrupt(npc)
	npc.resume = nil
	npc.path = crawlPath(crowd, npc, awayFrom)
	npc.pathIndex = 1
	npc.speed = config.Death.CrawlSpeed
	npc.moveSpeed = 0
	AnimationSync.set(npc, Knockdown.animation("Knockdown", npc.fall, npc.posture))
	table.insert(Death.bodies, {
		model = npc.model,
		npc = npc,
		ground = function()
			return npc.ground
		end,
	})
end

-- A downed or eliminated player's body (DownedService), so NPCs react to it as to any other.
function Death.addPlayerBody(model: Model, ground: () -> Vector3)
	table.insert(Death.bodies, { model = model, npc = nil, ground = ground })
end

function Death.removePlayerBody(model: Model)
	for index, body in Death.bodies do
		if body.model == model and body.npc == nil then
			table.remove(Death.bodies, index)
			return
		end
	end
end

-- An executed NPC (spec 14.1: an enemy holds Interact on a downed body) bleeds out at once.
function Death.execute(npc: Npc, now: number)
	if npc.state == "Downed" then
		npc.stateUntil = now
	end
end

-- The NPC is on its feet again: its body is no longer a body, and the crowd gives it a node and a routine.
local function stand(npc: Npc, now: number, hooks: Hooks)
	for index, body in Death.bodies do
		if body.npc == npc then
			table.remove(Death.bodies, index)
			break
		end
	end
	npc.hp = config.MaxHP
	npc.state = "Idle"
	npc.offset = Vector3.zero
	npc.path = nil
	npc.moveSpeed = 0
	npc.speed = npc.baseSpeed
	npc.idleUntil = now
	npc.reactedTo = {}
	AnimationSync.set(npc, "")
	hooks.revive(npc)
end

-- Moves a downed NPC on: crawling while it has path left, bleeding out, lying, then (WakeUp.Seconds after it went down)
-- getting up and standing.
function Death.update(npc: Npc, dt: number, now: number, hooks: Hooks)
	if npc.state == "Rising" then
		if now >= npc.stateUntil then
			stand(npc, now, hooks)
		end
		return
	end
	if npc.state == "Eliminated" then
		if now >= npc.downedAt + config.WakeUp.Seconds then
			npc.state = "Rising"
			npc.stateUntil = now + config.WakeUp.RiseSeconds
			AnimationSync.set(npc, Knockdown.animation("Rise", npc.fall, npc.posture))
		end
		return
	end
	if npc.state ~= "Downed" then
		return
	end
	if now >= npc.knockUntil and now < npc.stateUntil then
		local crawling = npc.path ~= nil
		if crawling then
			Movement.follow(npc, dt)
		end
		AnimationSync.set(npc, Knockdown.animation("Down", npc.fall, npc.posture, crawling))
	end
	if now < npc.stateUntil then
		return
	end

	npc.state = "Eliminated"
	npc.path = nil
	AnimationSync.set(npc, Knockdown.animation("Dead", npc.fall, npc.posture))
end

return Death
