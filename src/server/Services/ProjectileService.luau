--!strict
-- Server-simulated arcing projectiles: Suture's flare and Feint's throwing knives (tickets 8.5e, 8.5f; contracts in
-- .ai-sync/WEAPON_SERVER_CONTRACTS.md). CombatService validates the request (alive, rate, ammo, origin near the head)
-- and hands the throw here; clients only ever draw what this reports.
--
--   * A projectile flies under WeaponProjectile.Gravity from the aim direction at Speed. Each step is traced against the
--     map and against every person's rewound pose (Ballistics), so a fast knife cannot skip through a body. Teammates
--     are passed through; the shooter is never hit.
--   * Flare: a direct hit does Damage (55, no extra splash); everyone else within SplashRadius with a clear line to the
--     landing point takes SplashDamage; the landing point lights the area for LightSeconds (a ProjectileImpact field,
--     no damage); the struck character glows for the shooter's team for GlowSeconds (TargetGlow).
--   * Knife: a hit does Damage (Damage x HeadshotMult on an Exposed head; a disguised agent's head counts as body). The
--     knife then rests where it landed as a part in workspace.LandedKnives with a pick-up prompt. Any agent holding
--     knives (an opponent too) can pick one up, up to the carrying limit; the part is removed in the same step that
--     the round is returned, so it can never be picked up twice.
--   * A knife throw is silent (CombatService skips the gunshot for HearStuds 0); the landing and the pick-up are not
--     announced to NPCs either.
--
-- Nothing is put on a character. ProjectileService.Start registers itself with CombatService.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Types = require(Shared:WaitForChild("Types"))
local Ballistics = require(script.Parent.Parent.Combat.Ballistics)
local History = require(script.Parent.Parent.Combat.History)
local CombatService = require(script.Parent.CombatService)
local CoverService = require(script.Parent.CoverService)
local MatchService = require(script.Parent.MatchService)
local RemoteService = require(script.Parent.RemoteService)
local TeamService = require(script.Parent.TeamService)

type WeaponDef = Types.WeaponDef
type Target = History.Target

type Flight = {
	id: number,
	shooter: Player,
	def: WeaponDef,
	origin: Vector3,
	position: Vector3,
	velocity: Vector3,
	age: number,
	startedAt: number, -- server clock
	viewers: { [Player]: boolean },
}

local ProjectileService = {}

local config = GameConfig.Combat.Projectile
local FOLDER_NAME = "LandedKnives"
local MAX_STEP_SECONDS = 0.1

local flights: { [number]: Flight } = {}
local inFlight: { [Player]: number } = {}
local landed: { [BasePart]: boolean } = {}
local nextId = 0
local folder: Folder

-- Rays in the character group skip characters and meet only the map (and what blocks shots: glass, shut doors).
local mapParams = RaycastParams.new()
mapParams.CollisionGroup = GameConfig.Rig.CollisionGroup
mapParams.RespectCanCollide = true

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return root
	end
	return nil
end

-- The shooter, plus every player within ViewStuds of a point.
local function viewersAround(position: Vector3, shooter: Player): { [Player]: boolean }
	local viewers: { [Player]: boolean } = { [shooter] = true }
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		if root and (root.Position - position).Magnitude <= config.ViewStuds then
			viewers[player] = true
		end
	end
	return viewers
end

local function send(name: string, viewers: { [Player]: boolean }, build: (Player) -> any)
	for player in viewers do
		if player.Parent then
			RemoteService.fireClient(name, player, build(player))
		end
	end
end

local function floorBelow(position: Vector3): Vector3?
	local hit = workspace:Raycast(position, Vector3.new(0, -config.FloorProbeStuds, 0), mapParams)
	return if hit then hit.Position else nil
end

-- Knives -----------------------------------------------------------------------------------------------------------

local function onPickup(player: Player, part: BasePart, reach: number)
	if not landed[part] then
		return -- already taken: the first trigger removed it
	end
	local root = rootOf(player)
	if not root or (root.Position - part.Position).Magnitude > reach + config.PickupSlackStuds then
		return
	end
	if CombatService.refillThrowable(player, "Knife", 1) > 0 then
		landed[part] = nil
		part:Destroy()
	end
end

local function landKnife(def: WeaponDef, position: Vector3, facing: Vector3)
	local proj = def.Projectile :: Types.WeaponProjectile
	local part = Instance.new("Part")
	part.Name = "LandedKnife"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Material = Enum.Material.Metal
	part.Color = Color3.fromRGB(150, 152, 158)
	part.Size = config.KnifeSize
	part.CFrame = CFrame.lookAt(position, position + facing)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Pick up knife"
	prompt.ObjectText = ""
	prompt.HoldDuration = config.PickupHoldSeconds
	prompt.MaxActivationDistance = proj.PickupStuds or 0
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = GameConfig.Controls.Interact
	prompt.Parent = part
	local reach = proj.PickupStuds or 0
	prompt.Triggered:Connect(function(player)
		onPickup(player, part, reach)
	end)
	landed[part] = true
	part.Parent = folder
end

-- Flares -----------------------------------------------------------------------------------------------------------

local function splash(flight: Flight, direct: Target?, at: Vector3)
	local proj = flight.def.Projectile :: Types.WeaponProjectile
	local damage, radius = proj.SplashDamage, proj.SplashRadius
	if not damage or not radius then
		return
	end
	local from = at + Vector3.new(0, 0.5, 0)
	for _, target in History.targets do
		local player = target.player
		if
			target ~= direct
			and player ~= flight.shooter
			and not (player and TeamService.areTeammates(flight.shooter, player))
		then
			local offset = target.rootPart.Position - from
			if offset.Magnitude <= radius and workspace:Raycast(from, offset, mapParams) == nil then
				CombatService.damageTarget(flight.shooter, target, damage, false, at)
			end
		end
	end
end

local function glow(flight: Flight, target: Target)
	local proj = flight.def.Projectile :: Types.WeaponProjectile
	if not proj.GlowSeconds then
		return
	end
	local teamId = TeamService.teamOf(flight.shooter)
	local recipients = if teamId then TeamService.members(teamId) else { flight.shooter }
	-- The model name every client sees, never History's "P" and a UserId, which would say the body is a player.
	local model = target.rootPart.Parent
	local modelName = if model then model.Name else target.id
	local info: Types.TargetGlowInfo =
		{ TargetId = modelName, ExpiresAt = workspace:GetServerTimeNow() + proj.GlowSeconds }
	RemoteService.fireClients("TargetGlow", recipients, info)
end

-- Ending a flight -------------------------------------------------------------------------------------------------

local function finish(flight: Flight, reason: string, position: Vector3, normal: Vector3?, hit: Ballistics.Hit?)
	flights[flight.id] = nil
	inFlight[flight.shooter] = math.max(0, (inFlight[flight.shooter] or 1) - 1)
	local def = flight.def
	local proj = def.Projectile :: Types.WeaponProjectile
	local now = workspace:GetServerTimeNow()
	local lightUntil: number? = nil
	local direct: Target? = nil
	if hit then
		direct = hit.target
		local head = hit.head
			and not (hit.target.kind == "Agent" and not CoverService.isExposed(hit.target.player :: Player))
		local amount = def.Damage * (if head then def.HeadshotMult else 1)
		CombatService.damageTarget(flight.shooter, hit.target, amount, head, flight.origin)
	end
	if proj.Kind == "Flare" then
		lightUntil = now + (proj.LightSeconds or 0)
		if direct then
			glow(flight, direct)
		end
		splash(flight, direct, position)
	else
		local facing = flight.velocity.Unit
		local rest = if hit then floorBelow(position) or position else position
		local offset = if normal
			then normal * config.LandedNormalOffset
			else Vector3.new(0, config.LandedNormalOffset, 0)
		landKnife(def, rest + offset, facing)
	end
	local viewers = viewersAround(position, flight.shooter)
	for player in flight.viewers do
		viewers[player] = true
	end
	local info: Types.ProjectileImpactInfo =
		{ Id = flight.id, Reason = reason, Position = position, Normal = normal, LightUntil = lightUntil }
	send("ProjectileImpact", viewers, function()
		return info
	end)
end

local function step(flight: Flight, dt: number)
	local proj = flight.def.Projectile :: Types.WeaponProjectile
	local gravity = Vector3.new(0, -proj.Gravity, 0)
	local from = flight.position
	local to = from + flight.velocity * dt + gravity * (0.5 * dt * dt)
	flight.velocity += gravity * dt
	flight.age += dt
	local delta = to - from
	local length = delta.Magnitude
	if length > 1e-4 then
		local direction = delta / length
		local hits, endPoint, hitWall, shield =
			Ballistics.trace(flight.shooter, from, direction, workspace:GetServerTimeNow(), 4, length)
		for _, hit in hits do
			local player = hit.target.player
			if not (player and TeamService.areTeammates(flight.shooter, player)) then
				local reason = if hit.target.kind == "Npc" then "Npc" else "Agent"
				finish(flight, reason, from + direction * hit.distance, -direction, hit)
				return
			end
		end
		if hitWall or shield then -- ticket 16b: a Riot Wall stops a flare or a knife like a wall
			local wall = workspace:Raycast(from, direction * length, mapParams)
			finish(flight, "Wall", endPoint, if wall then wall.Normal else nil, nil)
			return
		end
	end
	flight.position = to
	if flight.age >= proj.MaxSeconds then
		finish(flight, "Expired", to, nil, nil)
	end
end

local function launch(shooter: Player, def: WeaponDef, origin: Vector3, direction: Vector3)
	local proj = def.Projectile :: Types.WeaponProjectile
	nextId += 1
	local flight: Flight = {
		id = nextId,
		shooter = shooter,
		def = def,
		origin = origin,
		position = origin,
		velocity = direction * proj.Speed,
		age = 0,
		startedAt = workspace:GetServerTimeNow(),
		viewers = viewersAround(origin, shooter),
	}
	flights[flight.id] = flight
	inFlight[shooter] = (inFlight[shooter] or 0) + 1
	send("ProjectileLaunched", flight.viewers, function(player)
		local info: Types.ProjectileLaunchInfo = {
			Id = flight.id,
			Kind = proj.Kind,
			Origin = origin,
			Velocity = flight.velocity,
			Gravity = proj.Gravity,
			StartedAt = flight.startedAt,
			Own = player == shooter,
		}
		return info
	end)
end

function ProjectileService.Init()
	folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = workspace
end

-- A new match starts clean: nothing in the air and no knife left on the floor from the last one.
local function clear()
	table.clear(flights)
	table.clear(inFlight)
	table.clear(landed)
	folder:ClearAllChildren()
end

function ProjectileService.Start()
	MatchService.onPhaseChanged(function(phase)
		if phase == "Lobby" or phase == "Insertion" then
			clear()
		end
	end)
	CombatService.setProjectileHooks({
		canLaunch = function(player)
			return (inFlight[player] or 0) < config.MaxPerPlayer
		end,
		launch = launch,
	})
	Players.PlayerRemoving:Connect(function(player)
		inFlight[player] = nil
	end)
	RunService.Heartbeat:Connect(function(dt)
		local clamped = math.min(dt, MAX_STEP_SECONDS)
		for _, flight in flights do
			step(flight, clamped)
		end
	end)
end

return ProjectileService
