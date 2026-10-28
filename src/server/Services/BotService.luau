--!strict
-- Ticket 13B-a: bots, the rival teams that fill the lobby (BUILD_ORDER 13B, owner choice "crowd-NPC bots").
--
-- A bot is an ordinary crowd NPC picked at random when the match starts; nothing on it marks it as a bot (CLAUDE.md
-- rule 3). BotService walks it with NPCService.sendTo:
--   * Infiltration: to the nearest Intel station its team has not taken, then works it for the station's hack time times
--     the profile's HackMult (IntelService.takeFor). After the profile's IntelGoal stations it waits for the vault.
--   * Vault Breach: after TerminalDelaySeconds to the nearest terminal not yet hacked, and stands on it. VaultService
--     counts a bot on a dais for its team (contesting humans, and x1.25 once its team has 3 Intel).
--   * Package Heist and later: bots go back to being crowd (released).
-- A bot that is downed gets up 60 s later like any NPC and carries on. Bots do not shoot, take the Package or win; they
-- cannot be revived or be a human's teammate. They count as rival teams in the briefing.
--
--   BotService.teamIds() -> { number }

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local BotRegistry = require(script.Parent.Parent.Bots.BotRegistry)
local IntelService = require(script.Parent.IntelService)
local MatchService = require(script.Parent.MatchService)
local NPCService = require(script.Parent.NPCService)
local TeamService = require(script.Parent.TeamService)
local VaultService = require(script.Parent.VaultService)

local BotService = {}

local config = GameConfig.Bots
local rng = Random.new()
local vaultBreachAt = 0 -- os.clock() when the Vault Breach began
local sinceThink = 0

local function profile()
	return config.Profiles[config.Difficulty]
end

local function flatDistance(a: Vector3, b: Vector3): number
	local offset = a - b
	return Vector3.new(offset.X, 0, offset.Z).Magnitude
end

local function release()
	for _, bot in BotRegistry.list() do
		NPCService.releaseBot(bot.npc)
	end
	BotRegistry.clear()
end

-- Picks `count` crowd NPCs for a team (not the Warden or the Curator, not downed, not already a bot).
local function pickNpcs(count: number)
	local pool = {}
	for _, npc in NPCService.getNpcs() do
		if not npc.limits and not npc.bot and (npc.state == "Idle" or npc.state == "Walk") then
			table.insert(pool, npc)
		end
	end
	local picked = {}
	for _ = 1, math.min(count, #pool) do
		table.insert(picked, table.remove(pool, rng:NextInteger(1, #pool)))
	end
	return picked
end

local function spawnBots(humanTeams: number)
	release()
	if not config.Enabled then
		return
	end
	local mode = GameConfig.Modes[TeamService.mode()]
	local humans = 0
	for _, player in Players:GetPlayers() do
		if TeamService.teamOf(player) then
			humans += 1
		end
	end
	local room = GameConfig.Match.MaxPlayers - humans
	local teams = math.min(math.max(0, config.TargetTeams - humanTeams), math.floor(room / mode.TeamSize))
	for index = 1, teams do
		local teamId = config.TeamIdBase + index
		for _, npc in pickNpcs(mode.TeamSize) do
			local bot: BotRegistry.Bot = {
				teamId = teamId,
				npc = npc,
				intelTaken = 0,
				stationId = nil,
				workingUntil = 0,
				destination = nil,
				sentAt = 0,
			}
			NPCService.makeBot(npc, function()
				bot.sentAt = 0 -- arrived: the next think decides what to do here
			end)
			BotRegistry.add(bot)
		end
	end
	if GameConfig.Debug.PrintEvents then
		print(`[Bots] {#BotRegistry.list()} bot(s) in {teams} team(s), {config.Difficulty}`)
	end
end

local function goTo(bot: BotRegistry.Bot, position: Vector3, now: number)
	if bot.destination ~= position or now - bot.sentAt >= config.ResendSeconds then
		if NPCService.sendTo(bot.npc, position) then
			bot.destination = position
			bot.sentAt = now
		end
	end
end

local function thinkIntel(bot: BotRegistry.Bot, now: number)
	if bot.workingUntil ~= 0 then
		if now >= bot.workingUntil then
			if bot.stationId then
				IntelService.takeFor(bot.teamId, bot.stationId)
			end
			bot.intelTaken += 1
			bot.stationId, bot.workingUntil, bot.destination = nil, 0, nil
		end
		return
	end
	if bot.intelTaken >= profile().IntelGoal then
		return
	end
	local here = bot.npc.ground
	if not bot.stationId then
		local claimed: { [string]: boolean } = {}
		for _, other in BotRegistry.list() do
			if other.teamId == bot.teamId and other.stationId then
				claimed[other.stationId] = true -- a teammate is already on it
			end
		end
		local best, bestDistance = nil, math.huge
		for _, station in IntelService.untaken(bot.teamId) do
			local distance = (station.position - here).Magnitude
			if not claimed[station.id] and distance < bestDistance then
				best, bestDistance = station, distance
			end
		end
		if not best then
			return
		end
		bot.stationId = best.id
	end
	for _, station in IntelService.untaken(bot.teamId) do
		if station.id == bot.stationId then
			if flatDistance(station.position, here) <= config.ArriveStuds and bot.npc.state == "Idle" then
				bot.workingUntil = now + station.seconds * profile().HackMult
			else
				goTo(bot, station.position, now)
			end
			return
		end
	end
	bot.stationId = nil -- the team took it meanwhile
end

local function thinkVault(bot: BotRegistry.Bot, now: number)
	if now - vaultBreachAt < profile().TerminalDelaySeconds then
		return
	end
	local here = bot.npc.ground
	local best, bestDistance = nil, math.huge
	for _, position in VaultService.openTerminals() do
		local distance = (position - here).Magnitude
		if distance < bestDistance then
			best, bestDistance = position, distance
		end
	end
	if
		not best
		or flatDistance(best, here) <= config.ArriveStuds and math.abs(best.Y - here.Y) < config.ArriveStuds
	then
		return
	end
	if bot.npc.state == "Idle" and (best - here).Magnitude <= config.WarpStuds and bot.destination ~= nil then
		-- It walked as near as the graph goes (a vault core has no nodes): the last steps are a placement.
		NPCService.warpBot(bot.npc, best)
		return
	end
	goTo(bot, best, now)
end

local function think()
	local phase = MatchService.phase()
	local now = os.clock()
	for _, bot in BotRegistry.list() do
		if BotRegistry.alive(bot) and bot.npc.state ~= "Held" then
			if phase == "Infiltration" then
				thinkIntel(bot, now)
			elseif phase == "VaultBreach" then
				thinkVault(bot, now)
			end
		else
			bot.stationId, bot.workingUntil, bot.destination = nil, 0, nil
		end
	end
end

function BotService.teamIds(): { number }
	local ids: { number } = {}
	local seen: { [number]: boolean } = {}
	for _, bot in BotRegistry.list() do
		if not seen[bot.teamId] then
			seen[bot.teamId] = true
			table.insert(ids, bot.teamId)
		end
	end
	return ids
end

function BotService.Init() end

function BotService.Start()
	if not GameConfig.Debug.MenuOnJoin then
		return
	end
	MatchService.setBotSpawner(spawnBots)
	MatchService.onPhaseChanged(function(phase)
		if phase == "VaultBreach" then
			vaultBreachAt = os.clock()
		elseif phase == "PackageHeist" or phase == "Overtime" or phase == "Results" or phase == "Lobby" then
			release()
		end
	end)
	RunService.Heartbeat:Connect(function(dt)
		sinceThink += dt
		if sinceThink >= 1 / config.ThinkHz then
			sinceThink = 0
			think()
		end
	end)
end

return BotService
