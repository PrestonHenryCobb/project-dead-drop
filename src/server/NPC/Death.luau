--!strict
-- NPC death (spec 5.5). A killed NPC ragdolls, stays for CorpseSeconds, fades and is removed; a replacement of the
-- same role appears ReplacementSeconds after the death at a node far from the body.
--
-- Bodies are what other NPCs react to (spec 5.4), so this keeps a list of them for the reaction module.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local NpcTypes = require(script.Parent.NpcTypes)

type Npc = NpcTypes.Npc
type Crowd = NpcTypes.Crowd

export type Body = {
	model: Model,
	position: Vector3,
}

local Death = {}

local config = GameConfig.NPC
local RAGDOLL_LIFT = 10 -- studs/s of upward kick so a ragdoll does not just slump in place

-- Bodies currently lying around. Read by the reaction module.
Death.bodies = {} :: { Body }

local function ragdoll(npc: Npc, awayFrom: Vector3?)
	local model, root = npc.model, npc.root
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("AnimationConstraint") then
			descendant.Enabled = false
		elseif descendant:IsA("BallSocketConstraint") then
			descendant.Enabled = true
		end
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and not descendant:FindFirstAncestorOfClass("Accessory") then
			descendant.Anchored = false
			descendant.CanCollide = descendant ~= root
		end
	end
	-- The server simulates the body, so every player sees the same thing.
	root:SetNetworkOwner(nil)
	local push = Vector3.zero
	if awayFrom then
		local away = Vector3.new(root.Position.X - awayFrom.X, 0, root.Position.Z - awayFrom.Z)
		if away.Magnitude > 1e-3 then
			push = away.Unit * config.Death.RagdollSpeed
		end
	end
	root.AssemblyLinearVelocity = push + Vector3.new(0, RAGDOLL_LIFT, 0)
end

local function fadeAndRemove(body: Body)
	local info = TweenInfo.new(config.Death.FadeSeconds)
	for _, descendant in body.model:GetDescendants() do
		if descendant:IsA("BasePart") then
			TweenService:Create(descendant, info, { Transparency = 1 }):Play()
		end
	end
	task.delay(config.Death.FadeSeconds, function()
		local index = table.find(Death.bodies, body)
		if index then
			table.remove(Death.bodies, index)
		end
		body.model:Destroy()
	end)
end

-- Kills an NPC. `awayFrom` is where the blast came from, if any. `replace` is called with the NPC's role and the
-- place it died when its replacement is due.
function Death.kill(crowd: Crowd, npc: Npc, awayFrom: Vector3?, replace: (string, Vector3) -> ())
	if npc.state == "Dead" then
		return
	end
	npc.state = "Dead"
	npc.path = nil
	crowd.release(npc.node)
	ragdoll(npc, awayFrom)

	local body: Body = { model = npc.model, position = npc.ground }
	table.insert(Death.bodies, body)
	task.delay(config.CorpseSeconds, fadeAndRemove, body)

	local role, position = npc.role, npc.ground
	task.delay(config.ReplacementSeconds, replace, role, position)
end

return Death
