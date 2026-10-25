--!strict
-- Teams (spec 3). Which mode the match plays and who is on which team. Until the lobby and matchmaking exist (Steps 10
-- and 22) the mode is GameConfig.Debug.TestMode and players fill teams in join order, TeamSize to a team.
--
-- Identity secrecy (CLAUDE.md rule 3): nothing about teams is put on a character or player. Each team's members are
-- sent their own roster (TeamRoster) and nobody else's; teammate markers are built from it on the client.
--
--   TeamService.mode() -> string                 a key of GameConfig.Modes
--   TeamService.isSolos() -> boolean            Solos rules: no downed state, an extra plate (spec 14.3)
--   TeamService.teamOf(player) -> number?
--   TeamService.areTeammates(a, b) -> boolean   false for a player and themself
--   TeamService.members(teamId) -> { Player }
--   TeamService.onChanged(listener)             called with a team id whenever its members change

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Types = require(Shared:WaitForChild("Types"))
local RemoteService = require(script.Parent.RemoteService)

local TeamService = {}

local modeName = GameConfig.Debug.TestMode
local mode = GameConfig.Modes[modeName]
local teams: { [number]: { Player } } = {}
local teamOf: { [Player]: number } = {}
local listeners: { (number) -> () } = {}

function TeamService.mode(): string
	return modeName
end

function TeamService.isSolos(): boolean
	return mode.TeamSize == 1
end

function TeamService.teamOf(player: Player): number?
	return teamOf[player]
end

function TeamService.areTeammates(a: Player, b: Player): boolean
	return a ~= b and teamOf[a] ~= nil and teamOf[a] == teamOf[b]
end

function TeamService.members(teamId: number): { Player }
	return table.clone(teams[teamId] or {})
end

function TeamService.onChanged(listener: (number) -> ())
	table.insert(listeners, listener)
end

local function sendRoster(teamId: number)
	local members = teams[teamId] or {}
	local info: Types.TeamRosterInfo = { TeamId = teamId, Members = table.clone(members) }
	for _, member in members do
		RemoteService.fireClient("TeamRoster", member, info)
	end
	for _, listener in listeners do
		listener(teamId)
	end
end

local function join(player: Player)
	local chosen: number? = nil
	for teamId = 1, math.huge do
		local members = teams[teamId]
		if not members or #members < mode.TeamSize then
			chosen = teamId
			break
		end
	end
	local teamId = chosen :: number
	teams[teamId] = teams[teamId] or {}
	table.insert(teams[teamId], player)
	teamOf[player] = teamId
	sendRoster(teamId)
end

local function leave(player: Player)
	local teamId = teamOf[player]
	if not teamId then
		return
	end
	teamOf[player] = nil
	local members = teams[teamId]
	local index = table.find(members, player)
	if index then
		table.remove(members, index)
	end
	if #members == 0 then
		teams[teamId] = nil
	end
	sendRoster(teamId)
end

function TeamService.Init()
	assert(mode, `Debug.TestMode {modeName} is not a key of GameConfig.Modes`)
end

function TeamService.Start()
	Players.PlayerAdded:Connect(join)
	for _, player in Players:GetPlayers() do
		join(player)
	end
	Players.PlayerRemoving:Connect(leave)
end

return TeamService
