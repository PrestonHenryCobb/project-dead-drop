--!strict
-- Ticket 16c: Lattice's Sparrow Drone (spec 15.3). She flies a small drone for SparrowDrone.Seconds while her body stands
-- still (it cannot walk or fire) and stays disguised.
--
--   * The client views from the drone and sends the way it wants to fly (RequestSparrowMove, at MoveHz); the server moves the
--     drone at Speed, stops it at walls, and keeps it within MaxRangeStuds of her body. It hovers if the client goes quiet.
--   * The drone is a part in the world that any shot but hers stops at and wears down (Combat/Shields): 40 HP, and it ends
--     when it is shot down. Damage to her body ends the flight too, as does her being downed or the match ending.
--   * It hacks where it hovers: the Intel and camera holds measure their reach from it instead of from her body (reach()).
--   * Every TagCheckSeconds it tags each enemy agent in True Form it can see within TagRange: the glow (TargetGlow) goes to
--     her team for TagSeconds.
--
--   DroneService.begin(player) -> (boolean, string?)   take off; false and a reason if she cannot
--   DroneService.position(player) -> Vector3?          where her drone is, if she is flying one

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Types = require(Shared:WaitForChild("Types"))
local Validate = require(Shared:WaitForChild("Util"):WaitForChild("Validate"))
local History = require(script.Parent.Parent.Combat.History)
local Shields = require(script.Parent.Parent.Combat.Shields)
local CombatService = require(script.Parent.CombatService)
local DisguiseService = require(script.Parent.DisguiseService)
local DownedService = require(script.Parent.DownedService)
local MatchService = require(script.Parent.MatchService)
local RemoteService = require(script.Parent.RemoteService)
local TeamService = require(script.Parent.TeamService)

type Flight = {
	player: Player,
	character: Model,
	part: Part,
	shield: Shields.Shield,
	endsAt: number,
	direction: Vector3,
	directionAt: number,
	nextTagAt: number,
	tagged: { [Player]: number }, -- os.clock() until which an enemy stays tagged
}

local DroneService = {}

local config = GameConfig.Agents.Lattice.SparrowDrone
local flights: { [Player]: Flight } = {}

-- Rays in the character group meet only the map (and what blocks shots), as for every other sight line.
local mapParams = RaycastParams.new()
mapParams.CollisionGroup = GameConfig.Rig.CollisionGroup
mapParams.RespectCanCollide = true

function DroneService.position(player: Player): Vector3?
	local flight = flights[player]
	return if flight then flight.part.Position else nil
end

local function bodyRoot(flight: Flight): BasePart?
	local character = flight.player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if
		character == flight.character
		and humanoid
		and humanoid.Health > 0
		and root
		and root:IsA("BasePart")
		and not DownedService.isOut(flight.player)
	then
		return root
	end
	return nil
end

local function land(flight: Flight)
	if flights[flight.player] ~= flight then
		return
	end
	flights[flight.player] = nil
	Shields.destroy(flight.shield)
	DisguiseService.setFrozen(flight.player, false)
	CombatService.setFrozen(flight.player, false)
	local info: Types.SparrowStateInfo = { Active = false, EndsAt = 0 }
	RemoteService.fireClient("SparrowState", flight.player, info)
end

function DroneService.begin(player: Player): (boolean, string?)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (character and root and root:IsA("BasePart")) or flights[player] or not MatchService.isInMatch() then
		return false, nil
	end
	local part = Instance.new("Part")
	part.Name = "Drone"
	part.Size = config.Size
	part.Color = config.Color
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CastShadow = false
	part.Position = root.Position + Vector3.new(0, config.HeightAbove, 0)
	local now = os.clock()
	local shield = Shields.adopt(player, part, config.HP, function()
		local current = flights[player]
		if current then
			land(current) -- shot down
		end
	end)
	flights[player] = {
		player = player,
		character = character,
		part = part,
		shield = shield,
		endsAt = now + config.Seconds,
		direction = Vector3.zero,
		directionAt = now,
		nextTagAt = now,
		tagged = {},
	}
	DisguiseService.setFrozen(player, true)
	CombatService.setFrozen(player, true)
	local info: Types.SparrowStateInfo = { Active = true, EndsAt = workspace:GetServerTimeNow() + config.Seconds }
	RemoteService.fireClient("SparrowState", player, info)
	return true, nil
end

-- Tags the enemy agents in True Form the drone can see, once per TagSeconds each.
local function tag(flight: Flight, now: number)
	local from = flight.part.Position
	local teamId = TeamService.teamOf(flight.player)
	local recipients = if teamId then TeamService.members(teamId) else { flight.player }
	for _, target in History.targets do
		local other = target.player
		if other and other ~= flight.player and not TeamService.areTeammates(flight.player, other) then
			local offset = target.rootPart.Position - from
			if
				DisguiseService.isExposed(other)
				and now >= (flight.tagged[other] or 0)
				and offset.Magnitude <= config.TagRange
				and workspace:Raycast(from, offset, mapParams) == nil
			then
				flight.tagged[other] = now + config.TagSeconds
				local info: Types.TargetGlowInfo =
					{ TargetId = target.id, ExpiresAt = workspace:GetServerTimeNow() + config.TagSeconds }
				RemoteService.fireClients("TargetGlow", recipients, info)
			end
		end
	end
end

local function fly(flight: Flight, root: BasePart, dt: number)
	local direction = if os.clock() - flight.directionAt <= config.MoveStaleSeconds
		then flight.direction
		else Vector3.zero
	if direction.Magnitude < 1e-3 then
		return
	end
	local step = direction * config.Speed * dt
	local from = flight.part.Position
	local hit = workspace:Spherecast(from, config.ClearanceStuds, step, mapParams)
	local travel = if hit then math.max(0, hit.Distance - 0.05) else step.Magnitude
	local to = from + step.Unit * travel
	if (to - root.Position).Magnitude <= config.MaxRangeStuds then
		flight.part.Position = to
	end
end

local function step(dt: number)
	local now = os.clock()
	for _, flight in flights do
		local root = bodyRoot(flight)
		if not root or now >= flight.endsAt or not MatchService.isInMatch() then
			land(flight)
		else
			fly(flight, root, dt)
			if now >= flight.nextTagAt then
				flight.nextTagAt = now + config.TagCheckSeconds
				tag(flight, now)
			end
		end
	end
end

local function onRequestMove(player: Player, direction: unknown)
	local flight = flights[player]
	local wanted = Validate.vector3(direction)
	if not flight or not wanted then
		return
	end
	flight.direction = if wanted.Magnitude > 1 then wanted.Unit else wanted
	flight.directionAt = os.clock()
end

function DroneService.Init() end

function DroneService.Start()
	RemoteService.onRequest("RequestSparrowMove", onRequestMove)
	CombatService.setDamageListener(function(victim)
		local flight = flights[victim]
		if flight then
			land(flight)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		local flight = flights[player]
		if flight then
			land(flight)
		end
	end)
	RunService.Heartbeat:Connect(step)
end

return DroneService
