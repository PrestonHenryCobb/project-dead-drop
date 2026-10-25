--!strict
-- Downed, revive, execute and elimination (spec 14.1, 14.3; OPEN_QUESTIONS A7).
--
--   * At 0 HP an agent goes Downed (Solos: eliminated at once). They are Exposed, cannot shoot, aim, reload, melee,
--     scan or change disguise, and bleed out after Downed.BleedOutSeconds. The body lies and crawls exactly like a
--     downed NPC's: the server anchors the root face down at NPC.Death.RootLiftStuds and moves it at Speeds.Crawl
--     (eased like every walk, GameConfig.Movement) the way the client asks (RequestCrawl). Shots pass through it.
--     It falls the way the final hit sends it (Util/Knockdown: forward onto the front, backward onto the back, or to a
--     side and then onto the front), and the crawl waits until the fall has played (R4-body-animation).
--   * Hold Interact on a body (InteractService kind "Body", target = the model's name): a teammate is revived in
--     Downed.ReviveSeconds (back up with ReviveHP and no armour); anyone else downed, player or NPC, is executed in
--     ExecuteSeconds. Either breaks the holder's Cover (spec 7.2 #6). The client cannot tell which bodies are players.
--   * If every member of a team is downed or out, the downed ones die at once (team wipe).
--   * An eliminated agent's body lies like a bled-out NPC's for NPC.CorpseSeconds, then fades. NPCs react to downed
--     and eliminated players' bodies as to any other (Death.addPlayerBody).
--
-- SPEC-QUESTION: the spec does not say whether a downed agent can be finished by gunfire. Downed NPCs take no more
-- damage and both must behave alike, so shots pass through every downed body; execute or bleed-out finishes it.
--
--   DownedService.isDowned(player) -> boolean
--   DownedService.isOut(player) -> boolean       downed, eliminated, or without a living character
--   DownedService.onEliminated(listener)         listener(player) when a player is eliminated

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Types = require(Shared:WaitForChild("Types"))
local Knockdown = require(Shared:WaitForChild("Util"):WaitForChild("Knockdown"))
local Death = require(script.Parent.Parent.NPC.Death)
local CombatService = require(script.Parent.CombatService)
local CoverService = require(script.Parent.CoverService)
local DisguiseService = require(script.Parent.DisguiseService)
local InteractService = require(script.Parent.InteractService)
local NPCService = require(script.Parent.NPCService)
local RemoteService = require(script.Parent.RemoteService)
local TeamService = require(script.Parent.TeamService)

type Downed = {
	character: Model,
	humanoid: Humanoid,
	root: BasePart,
	ground: Vector3, -- where the body lies
	yaw: number, -- the way the head points
	heading: Vector3, -- the way it is crawling (kept while it slows to a stop)
	crawl: Vector3, -- the way the client asks to crawl, length 0 to 1
	speed: number,
	bleedAt: number, -- server clock
	fall: Knockdown.Fall, -- how it went down (R4-body-animation), from the final hit's direction
	posture: Knockdown.Posture, -- on its front or back
	knockUntil: number, -- server clock: the fall plays until then, and the crawl waits for it
}

local DownedService = {}

local config = GameConfig.Downed
local npcConfig = GameConfig.NPC
local movement = GameConfig.Movement
local CRAWL_SPEED = GameConfig.Speeds.Crawl
local GROUND_PROBE_UP = 2 -- studs above the body a floor check starts
local GROUND_PROBE_DOWN = 6 -- studs below the body a floor may be
local STEP_UP_STUDS = 1.5 -- a crawl may climb or drop this much between ticks; more is a ledge
local WALL_CLEARANCE = 1 -- studs left between a crawling body and a wall

local downed: { [Player]: Downed } = {}
local eliminated: { [Player]: boolean } = {} -- for this life; cleared when a new character spawns
local eliminatedListeners: { (Player) -> () } = {}

-- Rays in the character group skip characters and meet only the map.
local mapParams = RaycastParams.new()
mapParams.CollisionGroup = GameConfig.Rig.CollisionGroup
mapParams.RespectCanCollide = true

function DownedService.isDowned(player: Player): boolean
	return downed[player] ~= nil
end

function DownedService.isOut(player: Player): boolean
	if downed[player] or eliminated[player] then
		return true
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return not (humanoid and humanoid.Health > 0)
end

function DownedService.onEliminated(listener: (Player) -> ())
	table.insert(eliminatedListeners, listener)
end

local function floorBelow(position: Vector3): Vector3?
	local hit = workspace:Raycast(
		position + Vector3.new(0, GROUND_PROBE_UP, 0),
		Vector3.new(0, -(GROUND_PROBE_UP + GROUND_PROBE_DOWN), 0),
		mapParams
	)
	return if hit then hit.Position else nil
end

local function yawOf(direction: Vector3): number
	return math.atan2(-direction.X, -direction.Z)
end

-- On its front or back, head the way it crawls, exactly as a downed NPC lies (Util/Knockdown).
local function lay(body: Downed)
	body.root.CFrame = Knockdown.lyingCFrame(body.ground, body.yaw, body.posture)
end

-- `from` is where the final damaging hit came from (nil or the body itself for a fall): it decides the fall.
local function layDown(character: Model, humanoid: Humanoid, root: BasePart, from: Vector3?): Downed
	local feet = root.Position - Vector3.new(0, humanoid.HipHeight + root.Size.Y / 2, 0)
	local look = root.CFrame.LookVector
	local fall = Knockdown.classify(look, root.Position, from)
	local body: Downed = {
		character = character,
		humanoid = humanoid,
		root = root,
		ground = floorBelow(feet) or feet,
		yaw = Knockdown.lyingYaw(fall, yawOf(Vector3.new(look.X, 0, look.Z))),
		heading = Vector3.zero,
		crawl = Vector3.zero,
		speed = 0,
		bleedAt = math.huge,
		fall = fall,
		posture = Knockdown.posture(fall),
		knockUntil = workspace:GetServerTimeNow() + config.Knockdown.Seconds,
	}
	root.Anchored = true -- the server moves the body from now on, as it does a downed NPC's
	humanoid.PlatformStand = true
	lay(body)
	Death.addPlayerBody(character, function()
		return body.ground
	end)
	return body
end

local function fade(character: Model)
	local info = TweenInfo.new(npcConfig.Death.FadeSeconds)
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") then
			TweenService:Create(part, info, { Transparency = 1 }):Play()
		end
	end
	task.delay(npcConfig.Death.FadeSeconds, Death.removePlayerBody, character)
end

local checkTeamWipe: (Player) -> ()

local function eliminate(player: Player, from: Vector3?)
	if eliminated[player] then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local body = downed[player]
	downed[player] = nil
	local fromStanding = false
	if not body and character and humanoid and root and root:IsA("BasePart") and humanoid.Health > 0 then
		body = layDown(character, humanoid, root, from) -- Solos: straight from standing to a body on the floor
		fromStanding = true
	end
	eliminated[player] = true
	InteractService.cancel(player)
	CombatService.setTargetable(player, false)
	if humanoid then
		humanoid.Health = 0
	end
	local info: Types.EliminatedInfo = {
		Fall = if body then body.fall else "Forward",
		Posture = if body then body.posture else "Prone",
		FromStanding = fromStanding,
	}
	RemoteService.fireClient("Eliminated", player, info)
	for _, listener in eliminatedListeners do
		task.spawn(listener, player)
	end
	if body then
		task.delay(npcConfig.CorpseSeconds, fade, body.character)
	end
	checkTeamWipe(player)
end

-- Spec 14.1: if all members of a team are downed or eliminated at once, the downed ones die.
function checkTeamWipe(player: Player)
	local teamId = TeamService.teamOf(player)
	if not teamId then
		return
	end
	local members = TeamService.members(teamId)
	for _, member in members do
		if not DownedService.isOut(member) then
			return
		end
	end
	for _, member in members do
		if downed[member] then
			eliminate(member)
		end
	end
end

local function down(player: Player, from: Vector3)
	if downed[player] or eliminated[player] then
		return
	end
	if TeamService.isSolos() then
		eliminate(player, from) -- spec 14.3: no downed state in Solos
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (character and humanoid and root and root:IsA("BasePart")) then
		return
	end
	CoverService.expose(player, "Downed")
	CombatService.disarm(player)
	CombatService.setTargetable(player, false)
	InteractService.cancel(player)
	local body = layDown(character, humanoid, root, from)
	body.bleedAt = workspace:GetServerTimeNow() + config.BleedOutSeconds
	downed[player] = body
	local info: Types.DownedInfo = { BleedOutAt = body.bleedAt, Fall = body.fall, Posture = body.posture }
	RemoteService.fireClient("Downed", player, info)
	checkTeamWipe(player)
end

local function revive(player: Player)
	local body = downed[player]
	if not body then
		return
	end
	downed[player] = nil
	Death.removePlayerBody(body.character)
	local standHeight = body.humanoid.HipHeight + body.root.Size.Y / 2
	body.root.CFrame = CFrame.new(body.ground + Vector3.new(0, standHeight, 0)) * CFrame.Angles(0, body.yaw, 0)
	body.humanoid.PlatformStand = false
	body.root.Anchored = false
	CombatService.restore(player, config.ReviveHP, config.ReviveArmor)
	CombatService.setTargetable(player, true)
	RemoteService.fireClient("Revived", player)
end

-- One tick of a downed body's crawl: eased like any walk, stopped by walls and ledges, turning like an NPC.
local function crawl(body: Downed, dt: number)
	local want = body.crawl
	local target = CRAWL_SPEED * math.min(want.Magnitude, 1)
	if want.Magnitude > 1e-3 then
		body.heading = Vector3.new(want.X, 0, want.Z).Unit
	end
	if body.speed < target then
		body.speed = math.min(target, body.speed + CRAWL_SPEED / movement.AccelSeconds * dt)
	else
		body.speed = math.max(target, body.speed - CRAWL_SPEED / movement.DecelSeconds * dt)
	end
	if body.speed <= 0 or body.heading.Magnitude < 1e-3 then
		return
	end
	local step = body.heading * body.speed * dt
	local lift = Vector3.new(0, npcConfig.Death.RootLiftStuds, 0)
	if workspace:Raycast(body.ground + lift, body.heading * (step.Magnitude + WALL_CLEARANCE), mapParams) then
		body.speed = 0
		return
	end
	local nextGround = floorBelow(body.ground + step)
	if not nextGround or math.abs(nextGround.Y - body.ground.Y) > STEP_UP_STUDS then
		body.speed = 0
		return
	end
	body.ground = nextGround
	local turn = math.rad(npcConfig.MaxYawRate) * dt
	local delta = (yawOf(body.heading) - body.yaw + math.pi) % (2 * math.pi) - math.pi
	body.yaw += math.clamp(delta, -turn, turn)
	lay(body)
end

local function onRequestCrawl(player: Player, direction: unknown)
	local body = downed[player]
	if not body or typeof(direction) ~= "Vector3" or direction ~= direction then
		return
	end
	local flat = Vector3.new(direction.X, 0, direction.Z)
	body.crawl = if flat.Magnitude > 1 then flat.Unit else flat
end

-- InteractService "Body": revive a downed teammate, or execute any other downed body, player or NPC (spec 14.1).
local function beginBody(player: Player, targetName: string): InteractService.Interaction?
	if DownedService.isOut(player) then
		return nil
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local model = workspace:FindFirstChild(targetName)
	local targetRoot = model and model:IsA("Model") and model:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart") and targetRoot and targetRoot:IsA("BasePart")) or model == character then
		return nil
	end
	local function inReach(slack: number): boolean
		local offset = targetRoot.Position - root.Position
		return offset.Magnitude <= config.InteractStuds + slack
			and workspace:Raycast(root.Position, offset, mapParams) == nil
	end
	if not inReach(0) then
		return nil
	end

	local victim = Players:GetPlayerFromCharacter(model)
	local label: string
	local stillDowned: () -> boolean
	local complete: () -> ()
	if victim then
		local body = downed[victim]
		if not body then
			return nil
		end
		stillDowned = function()
			return downed[victim] == body
		end
		if TeamService.areTeammates(player, victim) then
			label = "Revive"
			complete = function()
				revive(victim)
			end
		else
			label = "Execute"
			complete = function()
				eliminate(victim)
			end
		end
	else
		local npc = NPCService.npcOf(model :: Model)
		if not npc or npc.state ~= "Downed" then
			return nil
		end
		label = "Execute"
		stillDowned = function()
			return npc.state == "Downed"
		end
		complete = function()
			NPCService.executeNpc(npc)
		end
	end

	CoverService.expose(player, label) -- spec 7.2 #6: reviving or executing breaks Cover
	return {
		label = label,
		seconds = if label == "Revive" then config.ReviveSeconds else config.ExecuteSeconds,
		stillValid = function()
			return not DownedService.isOut(player) and stillDowned() and inReach(config.InteractSlackStuds)
		end,
		complete = complete,
	}
end

function DownedService.Init() end

function DownedService.Start()
	CombatService.setDownedHooks({ onZeroHealth = down, isDowned = DownedService.isDowned })
	DisguiseService.setActionBlocker(DownedService.isOut)
	InteractService.register("Body", beginBody)
	RemoteService.onRequest("RequestCrawl", onRequestCrawl)

	local function track(player: Player)
		player.CharacterAdded:Connect(function()
			downed[player] = nil
			eliminated[player] = nil
		end)
	end
	Players.PlayerAdded:Connect(track)
	for _, player in Players:GetPlayers() do
		track(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local body = downed[player]
		if body then
			Death.removePlayerBody(body.character)
		end
		downed[player] = nil
		eliminated[player] = nil
		-- Spec 27 #4: leaving while downed counts as eliminated, so the rest of the team may now be wiped.
		local teamId = TeamService.teamOf(player)
		if teamId then
			for _, member in TeamService.members(teamId) do
				if member ~= player and downed[member] then
					task.defer(checkTeamWipe, member)
					break
				end
			end
		end
	end)

	RunService.Heartbeat:Connect(function(dt)
		local now = workspace:GetServerTimeNow()
		for player, body in downed do
			if now >= body.bleedAt then
				eliminate(player)
			elseif now >= body.knockUntil then
				crawl(body, dt) -- not while the fall is still playing
			end
		end
	end)
end

return DownedService
