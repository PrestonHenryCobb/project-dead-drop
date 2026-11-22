--!strict
-- Ticket 13B-a: bots, the rival teams that fill the lobby (BUILD_ORDER 13B, owner choice "crowd-NPC bots").
--
-- A bot is an ordinary crowd NPC picked at random when the match starts; nothing on it marks it as a bot (CLAUDE.md
-- rule 3). BotService walks it with NPCService.sendTo:
--   * Infiltration: to the nearest Intel station its team has not taken, then works it for the station's hack time times
--     the profile's HackMult (IntelService.takeFor). After the profile's IntelGoal stations it waits for the vault.
--   * Vault Breach: after TerminalDelaySeconds to the nearest terminal not yet hacked, and stands on it. VaultService
--     counts a bot on a dais for its team (contesting humans, and x1.25 once its team has 3 Intel).
--   * Package Heist and Overtime: after PackageDelaySeconds a team's nearest bot walks to the Package and takes it. A bot
--     carrying it walks to the nearest extraction terminal, calls extraction, waits for the green zone, stands in it for the
--     channel time and wins (a bot team can win the match). Competitive bots also hunt a rival carrier.
--   * Always, from Infiltration: a bot shoots an Exposed human it can see within its profile's range (Shot), with a chance
--     to hit. Humans stay safe from bots while their Cover holds, which is what Cover is.
-- A bot that is downed gets up 60 s later like any NPC and carries on. Bots cannot be revived, be a human's teammate or use
-- gadgets. They count as rival teams in the briefing. Bots go back to the crowd when the match ends.
--
--   BotService.teamIds() -> { number }

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local BotRegistry = require(script.Parent.Parent.Bots.BotRegistry)
local CombatService = require(script.Parent.CombatService)
local CoverService = require(script.Parent.CoverService)
local DownedService = require(script.Parent.DownedService)
local ExtractionService = require(script.Parent.ExtractionService)
local IntelService = require(script.Parent.IntelService)
local MatchService = require(script.Parent.MatchService)
local NPCService = require(script.Parent.NPCService)
local SpawnService = require(script.Parent.SpawnService)
local PackageService = require(script.Parent.PackageService)
local TeamService = require(script.Parent.TeamService)
local VaultService = require(script.Parent.VaultService)

local BotService = {}

local config = GameConfig.Bots
local rng = Random.new()
local vaultBreachAt = 0 -- os.clock() when the Vault Breach began
local sinceThink = 0
local heistAt = 0 -- os.clock() when the Package Heist began
local paidDoor: { [number]: boolean } = {} -- bot teams that have paid for the Package room's front door

local sight = RaycastParams.new()
sight.CollisionGroup = GameConfig.Rig.CollisionGroup
sight.RespectCanCollide = true

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
		local members = pickNpcs(mode.TeamSize)
		for slot, npc in members do
			local bot: BotRegistry.Bot = {
				teamId = teamId,
				npc = npc,
				intelTaken = 0,
				stationId = nil,
				workingUntil = 0,
				destination = nil,
				sentAt = 0,
				nextShotAt = 0,
			}
			NPCService.makeBot(npc, function()
				bot.sentAt = 0 -- arrived: the next think decides what to do here
			end)
			BotRegistry.add(bot)
			-- Spec 11: a bot team starts at an Insertion Point of its own, like a human team, instead of wherever its crowd NPCs were.
			local spot = SpawnService.botSpot(index, slot, #members)
			if spot then
				NPCService.warpBot(npc, spot)
			end
		end
	end
	if GameConfig.Debug.PrintEvents then
		print(`[Bots] {#BotRegistry.list()} bot(s) in {teams} team(s), {config.Difficulty}`)
	end
end

local function goTo(bot: BotRegistry.Bot, position: Vector3, now: number)
	local walking = bot.npc.state == "Walk"
	if bot.destination ~= position or (not walking and now - bot.sentAt >= config.ResendSeconds) then
		if NPCService.sendTo(bot.npc, position) then
			bot.destination = position
			bot.sentAt = now
		end
	end
end

local function thinkIntel(bot: BotRegistry.Bot, now: number, goal: number)
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
	if bot.intelTaken >= goal then
		return
	end
	local here = bot.npc.ground
	if not bot.stationId then
		local claimed: { [string]: boolean } = {}
		local crowding: { [string]: number } = {} -- bots of other teams already heading for each station
		for _, other in BotRegistry.list() do
			if other.stationId then
				if other.teamId == bot.teamId then
					claimed[other.stationId] = true -- a teammate is already on it
				else
					crowding[other.stationId] = (crowding[other.stationId] or 0) + 1
				end
			end
		end
		-- The nearest station, but each rival already going there makes it SpreadPenaltyStuds farther, so the teams fan out over the map.
		local best, bestDistance = nil, math.huge
		for _, station in IntelService.untaken(bot.teamId) do
			local distance = (station.position - here).Magnitude
				+ (crowding[station.id] or 0) * config.SpreadPenaltyStuds
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
		-- Nearest terminal, but each other bot already sent to it makes it SpreadPenaltyStuds farther, so they do not all stack on one.
		local crowded = 0
		for _, other in BotRegistry.list() do
			if other ~= bot and other.destination == position then
				crowded += 1
			end
		end
		local distance = (position - here).Magnitude + crowded * config.SpreadPenaltyStuds
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

-- A bot shoots the nearest Exposed human it can see (Cover hides everyone else).
local function shoot(bot: BotRegistry.Bot, now: number)
	local shot = profile().Shot
	if now < bot.nextShotAt then
		return
	end
	local eye = bot.npc.ground + Vector3.new(0, config.EyeStuds, 0)
	local best, bestRoot, bestDistance = nil, nil, shot.RangeStuds
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") and CoverService.isExposed(player) and not DownedService.isOut(player) then
			local distance = (root.Position - eye).Magnitude
			if distance <= bestDistance and workspace:Raycast(eye, root.Position - eye, sight) == nil then
				best, bestRoot, bestDistance = player, root, distance
			end
		end
	end
	if not (best and bestRoot) then
		return
	end
	bot.nextShotAt = now + shot.IntervalSeconds
	local hit = rng:NextNumber() < shot.HitChance
	CombatService.botFire(
		eye,
		bestRoot.Position,
		if hit then best else nil,
		shot.Damage,
		config.HearStuds,
		config.WeaponId
	)
end

-- The bot team's nearest living bot to the Package is the one that fetches it.
local function isFetcher(bot: BotRegistry.Bot, target: Vector3): boolean
	local best, bestDistance = nil, math.huge
	for _, other in BotRegistry.list() do
		if other.teamId == bot.teamId and BotRegistry.alive(other) then
			local distance = (other.npc.ground - target).Magnitude
			if distance < bestDistance then
				best, bestDistance = other, distance
			end
		end
	end
	return best == bot
end

-- An extraction pad is outdoors and may lie beyond the last graph node: a bot that walked as near as the graph goes is
-- placed on the pad.
local function goToSite(bot: BotRegistry.Bot, pad: Vector3, now: number)
	if bot.npc.state == "Idle" and bot.destination ~= nil and (pad - bot.npc.ground).Magnitude <= config.WarpStuds then
		NPCService.warpBot(bot.npc, pad)
	else
		goTo(bot, pad, now)
	end
end

local function thinkCarrier(bot: BotRegistry.Bot, now: number)
	local state, siteId, caller = ExtractionService.state()
	local sites = ExtractionService.sites()
	local here = bot.npc.ground
	if state == "Open" and caller == bot.teamId and siteId then
		for _, site in sites do
			if site.id == siteId then
				if ExtractionService.inOpenZone(here) then
					if bot.workingUntil == 0 then
						bot.workingUntil = now + GameConfig.Extraction.ChannelSeconds
					elseif now >= bot.workingUntil then
						ExtractionService.botExtract(bot)
						bot.workingUntil = 0
					end
				else
					bot.workingUntil = 0
					goToSite(bot, site.pad, now)
				end
			end
		end
		return
	end
	bot.workingUntil = 0
	if (state == "Countdown" or state == "Hover") and caller == bot.teamId and siteId then
		for _, site in sites do
			if site.id == siteId and flatDistance(site.pad, here) > config.ArriveStuds then
				goToSite(bot, site.pad, now) -- wait on the pad for the zone to open
			end
		end
		return
	end
	-- Not called yet (or a rival's call that this team means to beat): go to the nearest terminal and call.
	local best, bestDistance = nil, math.huge
	for _, site in sites do
		local distance = (site.terminal - here).Magnitude
		if distance < bestDistance then
			best, bestDistance = site, distance
		end
	end
	if not best then
		return
	end
	if flatDistance(best.terminal, here) <= GameConfig.Extraction.CallReachStuds then
		ExtractionService.botCall(bot, best.id)
	else
		goToSite(bot, best.pad, now)
	end
end

local function thinkHeist(bot: BotRegistry.Bot, now: number)
	if PackageService.carrierBot() == bot then
		thinkCarrier(bot, now)
		return
	end
	local status = PackageService.status()
	local position = PackageService.position()
	if (status == "Pedestal" or status == "Dropped") and position then
		if now - heistAt < profile().PackageDelaySeconds or not isFetcher(bot, position) then
			return
		end
		if
			(position - Vector3.new(0, config.PackageFloorDrop, 0) - bot.npc.ground).Magnitude
			<= GameConfig.Package.PickupRange
		then
			if bot.workingUntil == 0 then
				bot.workingUntil = now + GameConfig.Package.PickupSeconds
			elseif now >= bot.workingUntil then
				bot.workingUntil = 0
				if PackageService.botPickup(bot) then
					NPCService.unwarpBot(bot.npc) -- out of the room it was placed in, back to its node
				end
			end
		else
			bot.workingUntil = 0
			-- The Package room's front door costs Intel to hack open; a bot stopped at it pays, then is placed inside (the
			-- room has no graph nodes). A team that cannot pay goes back to taking Intel.
			local stuck = bot.npc.state == "Idle" and bot.destination ~= nil
			if stuck and (position - bot.npc.ground).Magnitude <= config.WarpStuds then
				local cost = GameConfig.Doors.HackCost.PackageDoor
				if paidDoor[bot.teamId] or IntelService.spend(bot.teamId, cost) then
					paidDoor[bot.teamId] = true
					NPCService.warpBot(bot.npc, position - Vector3.new(0, config.PackageFloorDrop, 0))
				else
					thinkIntel(bot, now, math.huge)
				end
			else
				goTo(bot, position, now)
			end
		end
	elseif status == "Carried" and profile().Hunts and PackageService.carrierTeam() ~= bot.teamId and position then
		if (position - bot.npc.ground).Magnitude > profile().Shot.RangeStuds / 2 then
			goTo(bot, position, now)
		end
	end
end

local function think()
	local phase = MatchService.phase()
	local now = os.clock()
	for _, bot in BotRegistry.list() do
		if BotRegistry.alive(bot) and bot.npc.state ~= "Held" then
			if phase == "Infiltration" then
				thinkIntel(bot, now, profile().IntelGoal)
				if bot.intelTaken >= profile().IntelGoal and bot.workingUntil == 0 then
					thinkVault(bot, now) -- done with Intel: scout the terminals (the first hack starts the Vault Breach)
				end
			elseif phase == "VaultBreach" then
				thinkVault(bot, now)
			elseif phase == "PackageHeist" or phase == "Overtime" then
				thinkHeist(bot, now)
			end
			if phase ~= "Insertion" then
				shoot(bot, now)
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
		elseif phase == "PackageHeist" then
			heistAt = os.clock()
			table.clear(paidDoor)
			for _, bot in BotRegistry.list() do
				NPCService.unwarpBot(bot.npc) -- off the dais, back to its node
				bot.stationId, bot.workingUntil, bot.destination = nil, 0, nil
			end
		elseif phase == "Results" or phase == "Lobby" then
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
