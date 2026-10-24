--!strict
-- Where every person was a moment ago (spec 13.3, lag compensation). Shots are tested against these poses rewound to
-- what the shooter's screen showed, up to GameConfig.Combat.LagCompSeconds back, so a shot at someone who has since
-- moved still counts.
--
-- A target is an NPC that is on its feet, or a player's character. Each keeps a short ring of samples taken at
-- LagCompHistoryHz; poseAt() blends the two samples round a time. Nothing here changes the world.
--
--   History.track(target)       start sampling a target (the ring is created here)
--   History.untrack(id)
--   History.sample(now)         read every tracked target's parts; call at LagCompHistoryHz
--   History.poseAt(target, t)   (root, head) at server time t, clamped to what is stored, or nil if nothing is
--   History.targets             the tracked targets, by id

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local NpcTypes = require(script.Parent.Parent.NPC.NpcTypes)

type Sample = { t: number, root: Vector3, head: Vector3 }

export type Target = {
	id: string, -- the NPC's model name, or "P" and a UserId for a player
	kind: "Npc" | "Agent",
	player: Player?,
	npc: NpcTypes.Npc?,
	rootPart: BasePart,
	headPart: BasePart,
	rootHeight: number, -- how high the root's centre sits above the feet
	bodyRadius: number,
	headRadius: number,
	delay: number, -- how far behind the server clients draw this target
	ring: { Sample },
	next: number, -- where the next sample goes
	count: number,
	seen: number, -- the last sweep that found this target still valid (NPCs are swept by CombatService)
}

local History = {}

local config = GameConfig.Combat
local RING_SIZE = math.ceil(config.LagCompSeconds * config.LagCompHistoryHz) + 3

History.targets = {} :: { [string]: Target }

-- Builds a target from a model whose root and head exist. Returns nil while the rig is still arriving.
function History.make(
	id: string,
	kind: "Npc" | "Agent",
	model: Model,
	rootHeight: number,
	delay: number,
	owner: { player: Player?, npc: NpcTypes.Npc? }
): Target?
	local root = model:FindFirstChild("HumanoidRootPart")
	local head = model:FindFirstChild("Head")
	if not (root and root:IsA("BasePart") and head and head:IsA("BasePart")) then
		return nil
	end
	local ring: { Sample } = {}
	for index = 1, RING_SIZE do
		ring[index] = { t = -math.huge, root = Vector3.zero, head = Vector3.zero }
	end
	return {
		id = id,
		kind = kind,
		player = owner.player,
		npc = owner.npc,
		rootPart = root,
		headPart = head,
		rootHeight = rootHeight,
		bodyRadius = config.Hitbox.BodyRadius,
		headRadius = math.max(config.Hitbox.HeadMinRadius, head.Size.Y * config.Hitbox.HeadRadiusScale),
		delay = delay,
		ring = ring,
		next = 1,
		count = 0,
		seen = 0,
	}
end

function History.track(target: Target)
	History.targets[target.id] = target
end

function History.untrack(id: string)
	History.targets[id] = nil
end

function History.sample(now: number)
	for _, target in History.targets do
		local sample = target.ring[target.next]
		sample.t = now
		sample.root = target.rootPart.Position
		sample.head = target.headPart.Position
		target.next = target.next % RING_SIZE + 1
		target.count = math.min(target.count + 1, RING_SIZE)
	end
end

-- Where the target was at server time `t`: the two stored samples round it, blended. Earlier than the oldest sample
-- gives the oldest; later than the newest gives the newest.
function History.poseAt(target: Target, t: number): (Vector3?, Vector3?)
	if target.count == 0 then
		return nil, nil
	end
	local older: Sample? = nil
	local newer: Sample? = nil
	for offset = 1, target.count do
		-- walk from the newest sample back to the oldest
		local index = (target.next - 1 - offset) % RING_SIZE + 1
		local sample = target.ring[index]
		if sample.t <= t then
			older = sample
			break
		end
		newer = sample
	end
	if not older then
		local oldest = newer :: Sample
		return oldest.root, oldest.head
	elseif not newer then
		return older.root, older.head
	end
	local span = newer.t - older.t
	local alpha = if span > 1e-6 then (t - older.t) / span else 1
	return older.root:Lerp(newer.root, alpha), older.head:Lerp(newer.head, alpha)
end

return History
