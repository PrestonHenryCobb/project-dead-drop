--!strict
-- Agent Sense (spec 8.3): every agent can tell, up close, who else is an agent.
--
--   * Disguised enemy: if the player looks straight at an enemy agent within AgentSenseRange for AgentSenseSeconds, that
--     one person gets a faint shimmer outline for AgentSenseShimmerSeconds, for the looker only. Cooldown afterwards.
--   * Exposed enemy (STEP7_QUESTIONS G2): while one is within AgentSenseRange, the player is told where, and their
--     client draws a faint red edge glow if they are not already looking at them.
--
-- The client cannot know who is a player, so it only reports the character in its crosshair (RequestSense); the
-- server decides. An NPC in the crosshair gets no shimmer, which is itself the answer, as intended. Teammates never
-- shimmer; until teams exist (Step 10), every other player counts as an enemy.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local DisguiseService = require(script.Parent.DisguiseService)
local RemoteService = require(script.Parent.RemoteService)

type Sense = {
	targetId: string,
	startedAt: number,
}

type State = {
	sense: Sense?,
	cooldownUntil: number,
	nearExposed: string, -- the last list sent, as a key, so only changes are sent
}

local AgentSenseService = {}

local config = GameConfig.Cover
local states: { [Player]: State } = {}
local accumulator = 0

-- Rays in the character group skip characters and only meet the map.
local sightParams = RaycastParams.new()
sightParams.CollisionGroup = GameConfig.Rig.CollisionGroup
sightParams.RespectCanCollide = true

local function aliveRoot(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return root
	end
	return nil
end

-- Another player's character by the name the client reports, if it is within range and in sight.
local function playerInSight(viewer: Player, targetId: string): Player?
	local viewerRoot = aliveRoot(viewer)
	if not viewerRoot then
		return nil
	end
	for _, other in Players:GetPlayers() do
		local character = other.Character
		if other ~= viewer and character and character.Name == targetId then
			local otherRoot = aliveRoot(other)
			if otherRoot and (otherRoot.Position - viewerRoot.Position).Magnitude <= config.AgentSenseRange then
				local offset = otherRoot.Position - viewerRoot.Position
				if workspace:Raycast(viewerRoot.Position, offset, sightParams) == nil then
					return other
				end
			end
		end
	end
	return nil
end

-- A character in range and in sight, player or NPC. The server does not say which it was.
local function inSenseRange(viewer: Player, targetId: string): boolean
	local viewerRoot = aliveRoot(viewer)
	if not viewerRoot then
		return false
	end
	local model = workspace:FindFirstChild(targetId)
	local root = model and model:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return false
	end
	local offset = root.Position - viewerRoot.Position
	return offset.Magnitude <= config.AgentSenseRange
		and workspace:Raycast(viewerRoot.Position, offset, sightParams) == nil
end

local function onRequestSense(player: Player, targetId: unknown)
	local state = states[player]
	if not state then
		return
	end
	if typeof(targetId) ~= "string" then
		state.sense = nil
		return
	end
	if state.sense and state.sense.targetId == targetId then
		return
	end
	state.sense = { targetId = targetId, startedAt = os.clock() }
end

local function checkSense(player: Player, state: State, now: number)
	local sense = state.sense
	if not sense then
		return
	end
	if not inSenseRange(player, sense.targetId) then
		state.sense = nil
		return
	end
	if now - sense.startedAt < config.AgentSenseSeconds then
		return
	end
	sense.startedAt = now -- if they keep staring, a new look begins
	if now < state.cooldownUntil then
		return
	end
	local target = playerInSight(player, sense.targetId)
	-- Exposed agents are already visible; they are shown by the vignette instead (STEP7_QUESTIONS G2).
	if target and not DisguiseService.isExposed(target) then
		state.cooldownUntil = now + config.AgentSenseCooldown
		RemoteService.fireClient("AgentSense", player, {
			Kind = "Shimmer",
			Id = sense.targetId,
			Seconds = config.AgentSenseShimmerSeconds,
		})
	end
end

-- Tells a player where exposed enemies within range are, when that changes.
local function checkNearExposed(player: Player, state: State)
	local root = aliveRoot(player)
	local positions: { Vector3 } = {}
	local key = ""
	if root then
		for _, other in Players:GetPlayers() do
			local otherRoot = aliveRoot(other)
			if
				other ~= player
				and otherRoot
				and DisguiseService.isExposed(other)
				and (otherRoot.Position - root.Position).Magnitude <= config.AgentSenseRange
			then
				table.insert(positions, otherRoot.Position)
				key ..= tostring(other.UserId) .. ","
			end
		end
	end
	-- Positions move, so resend while anyone is in range; send once when the last one leaves.
	if key ~= "" or state.nearExposed ~= "" then
		state.nearExposed = key
		RemoteService.fireClient("AgentSense", player, { Kind = "Near", Positions = positions })
	end
end

function AgentSenseService.Init() end

function AgentSenseService.Start()
	RemoteService.onRequest("RequestSense", onRequestSense)

	local function track(player: Player)
		states[player] = { sense = nil, cooldownUntil = 0, nearExposed = "" }
	end
	Players.PlayerAdded:Connect(track)
	for _, player in Players:GetPlayers() do
		track(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)

	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < config.AgentSenseCheckSeconds then
			return
		end
		accumulator = 0
		local now = os.clock()
		for player, state in states do
			checkSense(player, state, now)
			checkNearExposed(player, state)
		end
	end)
end

return AgentSenseService
