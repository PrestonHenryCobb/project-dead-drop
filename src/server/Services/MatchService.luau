--!strict
-- Ticket 10a: the match phase state machine (spec 2). The only thing that changes a phase.
--
--   Lobby -> Insertion -> Infiltration -> VaultBreach -> PackageHeist -> (Overtime) -> Results -> Lobby
--
--   * Lobby: players queue (LobbyService runs each team's agent select). A team that finishes select is "ready" and waits
--     here. The match starts when nobody is still selecting and either MinPlayers are ready or the fill countdown
--     (Match.FillCountdownMax, counted from the first ready team) has run out with at least Match.MinTeamsToStart teams
--     (spec 3.1). Debug.FastMatchStart starts as soon as one team is ready.
--   * Insertion: ready players are spawned and frozen (no walking, jumping or attacks) for Match.InsertionSeconds.
--   * Infiltration: the main timer (Match.MainTimerSeconds) starts. The Vault unlocks at Match.ForcedVaultUnlockElapsed at
--     the latest; Step 11 will advance to VaultBreach sooner when the Intel total is reached.
--   * Results: the scoreboard for Match.ResultsSeconds, then characters are removed and the lobby opens again.
--
-- Every transition fires PhaseChanged(phase, Types.PhaseData) to all clients. Nothing here marks a character or an NPC.
--
--   MatchService.phase() -> Types.Phase
--   MatchService.isInMatch() -> boolean               Insertion up to Overtime
--   MatchService.teamCount() -> number                teams in the match in progress
--   MatchService.canQueue() -> boolean                the lobby is open to new teams
--   MatchService.advance(to: Types.Phase) -> boolean  Insertion to Overtime transitions only (Steps 11 to 13 use it)
--   MatchService.finish(winnerTeamId: number?)         ends the match: a winner, or nil for Mission Failed
--   MatchService.onPhaseChanged(listener)             listener(phase)
--   MatchService.selectionStarted(teamId) / selectionFinished(teamId, members)   called by LobbyService

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Types = require(Shared:WaitForChild("Types"))
local CombatService = require(script.Parent.CombatService)
local DisguiseService = require(script.Parent.DisguiseService)
local DownedService = require(script.Parent.DownedService)
local MetaProgressionService = require(script.Parent.MetaProgressionService)
local RemoteService = require(script.Parent.RemoteService)
local RigService = require(script.Parent.RigService)
local SpectateService = require(script.Parent.SpectateService)
local TeamService = require(script.Parent.TeamService)

local config = GameConfig.Match

-- The next phases each phase may move to (Results is reached through finish).
local NEXT: { [string]: { string } } = {
	Insertion = { "Infiltration" },
	Infiltration = { "VaultBreach" },
	VaultBreach = { "PackageHeist" },
	PackageHeist = { "Overtime" },
}

local BANNERS: { [string]: string } = {
	Infiltration = "INFILTRATE THE GALA",
	VaultBreach = "THE VAULT IS OPEN FOR BREACH",
	PackageHeist = "THE PACKAGE IS LOOSE",
	Overtime = "OVERTIME",
}

local MatchService = {}

local phase: Types.Phase = "Lobby"
local startedAt = 0
local endsAt: number? = nil
local mainEndsAt: number? = nil
local forcedVaultAt: number? = nil
local results: Types.MatchResults? = nil

local selecting: { [number]: boolean } = {}
local ready: { [number]: { Player } } = {} -- teams that finished agent select and wait for the match
local fillEndsAt: number? = nil

local matchTeams: { [number]: { Player } } = {} -- the teams of the match in progress
local out: { [Player]: boolean } = {}
local listeners: { (Types.Phase) -> () } = {}
local tickElapsed = 0
local packageHeld: (() -> boolean)? = nil

local function now(): number
	return workspace:GetServerTimeNow()
end

local function playersIn(teams: { [number]: { Player } }): { Player }
	local list: { Player } = {}
	for _, members in teams do
		for _, member in members do
			table.insert(list, member)
		end
	end
	return list
end

local function sendPhase(targets: { Player }, data: Types.PhaseData)
	RemoteService.fireClients("PhaseChanged", targets, phase, data)
end

local function phaseData(banner: string?): Types.PhaseData
	return {
		StartedAt = startedAt,
		EndsAt = endsAt,
		MainEndsAt = mainEndsAt,
		ForcedVaultAt = forcedVaultAt,
		Banner = banner,
		Results = results,
	}
end

local function broadcastPhase(banner: string?)
	local data = phaseData(banner)
	if phase == "Insertion" then
		-- Each player's briefing names their own team (the colour only that team may see).
		local total = 0
		for _ in matchTeams do
			total += 1
		end
		local count = #playersIn(matchTeams)
		for teamId, members in matchTeams do
			local own = table.clone(data)
			own.Brief = { Mode = TeamService.mode(), TeamId = teamId, Teams = total, Players = count }
			sendPhase(members, own)
		end
		return
	end
	RemoteService.fireAllClients("PhaseChanged", phase, data)
end

local function setPhase(next: Types.Phase, phaseSeconds: number?)
	phase = next
	startedAt = now()
	endsAt = if phaseSeconds then startedAt + phaseSeconds else nil
	if GameConfig.Debug.PrintEvents then
		print(`[Match] {next}`)
	end
	broadcastPhase(BANNERS[next])
	for _, listener in listeners do
		task.spawn(listener, next)
	end
end

local function readyCount(): number
	return #playersIn(ready)
end

local function teamCount(teams: { [number]: { Player } }): number
	local total = 0
	for _ in teams do
		total += 1
	end
	return total
end

-- Tells the players waiting in the lobby how many are ready.
local function sendWaiting()
	local data = phaseData(nil)
	data.EndsAt = fillEndsAt
	data.ReadyPlayers = readyCount()
	sendPhase(playersIn(ready), data)
end

local function freeze(player: Player, frozen: boolean)
	CombatService.setFrozen(player, frozen)
	DisguiseService.setFrozen(player, frozen)
end

local function shouldStart(): boolean
	if next(selecting) ~= nil or next(ready) == nil then
		return false
	end
	if GameConfig.Debug.FastMatchStart then
		return true
	end
	local modeConfig = GameConfig.Modes[TeamService.mode()]
	if teamCount(ready) < config.MinTeamsToStart then
		return false
	end
	return readyCount() >= modeConfig.MinPlayers or (fillEndsAt ~= nil and now() >= fillEndsAt)
end

local function startInsertion()
	matchTeams, ready, fillEndsAt = ready, {}, nil
	table.clear(out)
	results = nil
	mainEndsAt, forcedVaultAt = nil, nil
	setPhase("Insertion", config.InsertionSeconds)
	for _, member in playersIn(matchTeams) do
		task.spawn(function()
			freeze(member, true) -- before the character exists, so there is no moment of walking
			RigService.spawn(member)
		end)
	end
end

local function memberResults(member: Player): Types.ResultsMember
	local loadout = MetaProgressionService.getLoadout(member)
	return {
		UserId = member.UserId,
		DisplayName = member.DisplayName,
		AgentId = loadout and loadout.AgentId,
		Out = out[member] == true,
	}
end

-- A player who left is still listed (matchTeams keeps the Player objects), marked Out.
local function buildResults(winnerTeamId: number?): Types.MatchResults
	local teams: { Types.ResultsTeam } = {}
	for teamId, members in matchTeams do
		local list: { Types.ResultsMember } = {}
		for _, member in members do
			table.insert(list, memberResults(member))
		end
		table.insert(teams, { TeamId = teamId, Won = teamId == winnerTeamId, Members = list })
	end
	table.sort(teams, function(a, b)
		return a.TeamId < b.TeamId
	end)
	return {
		WinnerTeamId = winnerTeamId,
		Reason = if winnerTeamId then "Extracted" else "MissionFailed",
		Teams = teams,
	}
end

function MatchService.finish(winnerTeamId: number?)
	if not MatchService.isInMatch() then
		return
	end
	for _, member in playersIn(matchTeams) do
		freeze(member, false)
	end
	mainEndsAt, forcedVaultAt = nil, nil
	results = buildResults(winnerTeamId)
	setPhase("Results", config.ResultsSeconds)
end

-- Back to the lobby: characters go, the menu opens again, and everyone can queue for the next match.
local function resetToLobby()
	SpectateService.stopAll()
	for _, member in playersIn(matchTeams) do
		local character = member.Character
		if character then
			character:Destroy()
		end
	end
	matchTeams, results = {}, nil
	table.clear(out)
	mainEndsAt, forcedVaultAt = nil, nil
	setPhase("Lobby", nil)
end

function MatchService.phase(): Types.Phase
	return phase
end

function MatchService.isInMatch(): boolean
	return phase == "Insertion"
		or phase == "Infiltration"
		or phase == "VaultBreach"
		or phase == "PackageHeist"
		or phase == "Overtime"
end

-- How many teams are in the match in progress.
function MatchService.teamCount(): number
	return teamCount(matchTeams)
end

function MatchService.canQueue(): boolean
	return phase == "Lobby"
end

-- Ticket 13a: how the main timer asks whether someone is carrying the Package (spec 19: then Overtime begins).
function MatchService.setPackageCheck(check: () -> boolean)
	packageHeld = check
end

function MatchService.onPhaseChanged(listener: (Types.Phase) -> ())
	table.insert(listeners, listener)
end

function MatchService.advance(to: Types.Phase): boolean
	local allowed = NEXT[phase]
	if not allowed or not table.find(allowed, to) then
		return false
	end
	if phase == "Insertion" then
		for _, member in playersIn(matchTeams) do
			freeze(member, false)
		end
		local start = now()
		mainEndsAt = start + config.MainTimerSeconds
		forcedVaultAt = start + config.ForcedVaultUnlockElapsed
	end
	setPhase(to, if to == "Overtime" then GameConfig.Overtime.CapSeconds else nil)
	return true
end

function MatchService.selectionStarted(teamId: number)
	selecting[teamId] = true
end

function MatchService.selectionFinished(teamId: number, members: { Player })
	selecting[teamId] = nil
	if #members == 0 then
		return
	end
	ready[teamId] = members
	if not fillEndsAt then
		fillEndsAt = now() + config.FillCountdownMax
	end
	sendWaiting()
end

-- Everyone on a team who is eliminated or gone: if nobody is left alive the match is over for all of them.
local function checkAllOut()
	if GameConfig.Debug.AutoRespawn or not MatchService.isInMatch() then
		return -- a Studio respawn brings eliminated players back, so being out is not final
	end
	for _, member in playersIn(matchTeams) do
		if not out[member] then
			return
		end
	end
	MatchService.finish(nil)
end

local function onPlayerGone(player: Player)
	for teamId, members in ready do
		local index = table.find(members, player)
		if index then
			table.remove(members, index)
			if #members == 0 then
				ready[teamId] = nil
			end
		end
	end
	if next(ready) == nil and next(selecting) == nil then
		fillEndsAt = nil
	end
	if MatchService.isInMatch() then
		out[player] = true
		checkAllOut()
	end
end

local function tick()
	local clock = now()
	if phase == "Lobby" then
		if shouldStart() then
			startInsertion()
		end
	elseif phase == "Insertion" then
		if endsAt and clock >= endsAt then
			MatchService.advance("Infiltration")
		end
	elseif phase == "Overtime" then
		if endsAt and clock >= endsAt then
			MatchService.finish(nil) -- the hard cap (spec 19)
		end
	elseif MatchService.isInMatch() then
		if mainEndsAt and clock >= mainEndsAt then
			local check = packageHeld
			if phase == "PackageHeist" and check and check() then
				MatchService.advance("Overtime")
			else
				MatchService.finish(nil)
			end
		elseif phase == "Infiltration" and forcedVaultAt and clock >= forcedVaultAt then
			MatchService.advance("VaultBreach")
		end
	elseif phase == "Results" and endsAt and clock >= endsAt then
		resetToLobby()
	end
end

function MatchService.Init() end

function MatchService.Start()
	if not GameConfig.Debug.MenuOnJoin then
		return -- no lobby: players spawn straight in and there is no match to run
	end
	DownedService.onEliminated(function(player)
		if MatchService.isInMatch() and not out[player] then
			out[player] = true
			checkAllOut()
		end
	end)
	Players.PlayerRemoving:Connect(onPlayerGone)
	local function watch(player: Player)
		-- A Studio respawn is a new life, so the player is back in.
		player.CharacterAdded:Connect(function()
			if GameConfig.Debug.AutoRespawn then
				out[player] = nil
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	RunService.Heartbeat:Connect(function(dt)
		tickElapsed += dt
		if tickElapsed >= config.TickSeconds then
			tickElapsed = 0
			tick()
		end
	end)
	setPhase("Lobby", nil)
end

return MatchService
