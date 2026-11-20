--!strict
-- Ticket spray (META_DRAFT: "placing a spray mid-match is an action NPCs never do, so it counts as suspicious"): a player places their
-- equipped Spray cosmetic on a wall they can see. RequestSpray(position, normal) is checked against the server's own ray from their head: the
-- aimed point must lie on a wall within ReachStuds with a clear line, and the spray goes where that ray met the wall, with the wall's own normal
-- (the client's normal is never used). Everyone gets SprayPlaced; it names no owner. Placing one is an odd action: it adds
-- GameConfig.Spray.SuspicionPercent to the player's suspicion, scaled by their witnesses (CoverService.noteOddAction).
-- A player has at most MaxPerPlayer; a fourth replaces the oldest. Sprays end after LifetimeSeconds and are cleared at Lobby and Insertion.
-- Cosmetics have no art yet: the client draws the spray's name until a decal exists.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Types = require(Shared:WaitForChild("Types"))
local CoverService = require(script.Parent.CoverService)
local DownedService = require(script.Parent.DownedService)
local MatchService = require(script.Parent.MatchService)
local MetaProgressionService = require(script.Parent.MetaProgressionService)
local RemoteService = require(script.Parent.RemoteService)

local SprayService = {}

local config = GameConfig.Spray

type Live = { id: number, owner: Player, expiresAt: number }

local live: { Live } = {}
local lastAt: { [Player]: number } = {}
local nextId = 0

-- Rays in the character group skip characters and meet only the map (and what blocks shots).
local mapParams = RaycastParams.new()
mapParams.CollisionGroup = GameConfig.Rig.CollisionGroup
mapParams.RespectCanCollide = true

local function finite(v: Vector3): boolean
	return v.X == v.X and v.Y == v.Y and v.Z == v.Z and v.Magnitude < math.huge
end

local function remove(entry: Live)
	local index = table.find(live, entry)
	if index then
		table.remove(live, index)
		RemoteService.fireAllClients("SprayCleared", entry.id)
	end
end

local function clearAll()
	for index = #live, 1, -1 do
		RemoteService.fireAllClients("SprayCleared", live[index].id)
		table.remove(live, index)
	end
end

local function onSpray(player: Player, position: unknown, _normal: unknown)
	if typeof(position) ~= "Vector3" or not finite(position) then
		return
	end
	local sprayId = MetaProgressionService.equippedSpray(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local head = character and character:FindFirstChild("Head")
	if
		not sprayId
		or not (humanoid and humanoid.Health > 0 and head and head:IsA("BasePart"))
		or not MatchService.isInMatch()
		or MatchService.phase() == "Insertion"
		or DownedService.isOut(player)
	then
		return
	end
	local now = os.clock()
	if now - (lastAt[player] or -math.huge) < config.CooldownSeconds then
		return
	end
	local offset = position - head.Position
	if offset.Magnitude < 1e-3 or offset.Magnitude > config.ReachStuds then
		return
	end
	local hit = workspace:Raycast(head.Position, offset.Unit * (offset.Magnitude + config.SurfaceSlackStuds), mapParams)
	if not hit or (hit.Position - position).Magnitude > config.SurfaceSlackStuds then
		return -- nothing there, or something in the way
	end
	lastAt[player] = now
	-- A fourth spray replaces this player's oldest.
	local mine: { Live } = {}
	for _, entry in live do
		if entry.owner == player then
			table.insert(mine, entry)
		end
	end
	if #mine >= config.MaxPerPlayer then
		remove(mine[1])
	end
	nextId += 1
	local entry: Live =
		{ id = nextId, owner = player, expiresAt = workspace:GetServerTimeNow() + config.LifetimeSeconds }
	table.insert(live, entry)
	local info: Types.SprayInfo = {
		Id = entry.id,
		SprayId = sprayId,
		Position = hit.Position,
		Normal = hit.Normal,
		ExpiresAt = entry.expiresAt,
	}
	RemoteService.fireAllClients("SprayPlaced", info)
	CoverService.noteOddAction(player, config.SuspicionPercent)
	task.delay(config.LifetimeSeconds, remove, entry)
end

function SprayService.Init() end

function SprayService.Start()
	RemoteService.onRequest("RequestSpray", onSpray)
	MatchService.onPhaseChanged(function(phase)
		if phase == "Lobby" or phase == "Insertion" then
			clearAll()
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastAt[player] = nil
		for index = #live, 1, -1 do
			if live[index].owner == player then
				RemoteService.fireAllClients("SprayCleared", live[index].id)
				table.remove(live, index)
			end
		end
	end)
end

return SprayService
