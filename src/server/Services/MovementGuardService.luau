--!strict
-- Ticket 23-audit (spec 26): "validate movement speed server-side (allow 20% tolerance), check teleports". The server sets
-- every player's WalkSpeed itself (DisguiseService), so a client that moves faster than that, or jumps across the map in
-- one step, is doing something the game never asked for.
--
-- Every GameConfig.MovementGuard.SampleSeconds the flat distance each living player moved is compared with the most their
-- WalkSpeed allows (plus Tolerance and SlackStuds). Bad samples are counted in a window; at ViolationsToFlag the player is
-- flagged and logged (rate-limited), and only kicked if MovementGuard.Kick is true, which it is not until a playtest shows
-- the traversals the client drives (ziplines, gondola, elevators, spring pads, vents) are not being flagged. Height is not
-- checked: falls are measured by CombatService and spring pads launch upward.
--
--   MovementGuardService.grace(player, seconds)   ignore this player's movement for a while (a known fast traversal)
--   MovementGuardService.flags(player) -> number  how many times the player has been flagged this session

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local MovementGuardService = {}

local config = GameConfig.MovementGuard

type Track = {
	position: Vector3,
	at: number,
	graceUntil: number,
	bad: number, -- bad samples in the current window
	lastBadAt: number,
	flagged: number,
	lastWarnAt: number,
}

local tracks: { [Player]: Track } = {}
local elapsed = 0

local function track(player: Player): Track
	local existing = tracks[player]
	if existing then
		return existing
	end
	local created: Track = {
		position = Vector3.zero,
		at = 0,
		graceUntil = os.clock() + config.GraceSeconds,
		bad = 0,
		lastBadAt = -math.huge,
		flagged = 0,
		lastWarnAt = -math.huge,
	}
	tracks[player] = created
	return created
end

function MovementGuardService.grace(player: Player, seconds: number)
	local entry = track(player)
	entry.graceUntil = math.max(entry.graceUntil, os.clock() + seconds)
	entry.at = 0 -- the next sample only records where they are
end

function MovementGuardService.flags(player: Player): number
	local entry = tracks[player]
	return if entry then entry.flagged else 0
end

local function flag(player: Player, entry: Track, kind: string, moved: number, allowed: number, now: number)
	entry.flagged += 1
	if now - entry.lastWarnAt >= config.WarnEverySeconds then
		entry.lastWarnAt = now
		warn(
			`[MovementGuard] {player.Name} {kind}: moved {string.format("%.1f", moved)} studs in one sample, allowed {string.format(
				"%.1f",
				allowed
			)} (flag {entry.flagged})`
		)
	end
	if config.Kick then
		player:Kick(config.KickMessage)
	end
end

local function sample(player: Player, now: number)
	local entry = track(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (humanoid and root and root:IsA("BasePart")) or humanoid.Health <= 0 then
		entry.at = 0
		return
	end
	local position = root.Position
	local previousAt = entry.at
	local previous = entry.position
	entry.position, entry.at = position, now
	if previousAt == 0 or now < entry.graceUntil then
		return
	end
	local dt = now - previousAt
	if dt <= 0 then
		return
	end
	local moved = Vector3.new(position.X - previous.X, 0, position.Z - previous.Z).Magnitude
	-- A step can arrive late, so allow for the real time between samples, never less than one sample.
	local window = math.max(dt, config.SampleSeconds)
	local allowed = humanoid.WalkSpeed * (1 + config.Tolerance) * window + config.SlackStuds
	if moved <= allowed then
		if now - entry.lastBadAt >= config.ResetSeconds then
			entry.bad = 0
		end
		return
	end
	entry.bad += 1
	entry.lastBadAt = now
	if entry.bad >= config.ViolationsToFlag or moved > config.TeleportStuds then
		entry.bad = 0
		flag(
			player,
			entry,
			if moved > config.TeleportStuds then "teleported" else "moved too fast",
			moved,
			allowed,
			now
		)
	end
end

function MovementGuardService.Init() end

function MovementGuardService.Start()
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			MovementGuardService.grace(player, config.GraceSeconds)
		end)
	end)
	for _, player in Players:GetPlayers() do
		player.CharacterAdded:Connect(function()
			MovementGuardService.grace(player, config.GraceSeconds)
		end)
	end
	Players.PlayerRemoving:Connect(function(player)
		tracks[player] = nil
	end)
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < config.SampleSeconds then
			return
		end
		elapsed = 0
		local now = os.clock()
		for _, player in Players:GetPlayers() do
			sample(player, now)
		end
	end)
end

return MovementGuardService
