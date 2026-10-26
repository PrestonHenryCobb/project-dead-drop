--!strict
-- Ticket menu-services: queueing and agent select, from the menu into the match.
--
-- A player in the menu asks to deploy (RequestStartPreDeploy). Their team's agent select starts and runs the full
-- GameConfig.Lobby.AgentSelectSeconds; it never ends early, and picks can be changed until the cutoff (SPEC_CHANGES
-- 2026-10-25). Teammates still in the menu are brought into the same select. The first teammate to lock in an agent
-- gets it; nobody else on the team can lock that agent (META_DRAFT). At the cutoff every member is equipped and spawned.
--
-- The state is sent only to the team's own members (CLAUDE.md rule 3: no rival learns a team's agents).
--
-- Until the match loop (Step 10) and matchmaking (Step 22) exist, "the match" is the map this server already runs:
-- deploying spawns the player into it, and a player who has deployed stays in it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Types = require(Shared:WaitForChild("Types"))
local WeaponDefs = require(Shared:WaitForChild("Defs"):WaitForChild("WeaponDefs"))
local CombatService = require(script.Parent.CombatService)
local MetaProgressionService = require(script.Parent.MetaProgressionService)
local RemoteService = require(script.Parent.RemoteService)
local RigService = require(script.Parent.RigService)
local TeamService = require(script.Parent.TeamService)

type Pick = {
	loadout: Types.PlayerLoadout?, -- nil: no agent free for them yet
	lockedIn: boolean,
}

type Selection = {
	teamId: number,
	endsAt: number, -- server clock
	picks: { [Player]: Pick },
}

local LobbyService = {}

local selections: { [number]: Selection } = {}
local deployed: { [Player]: boolean } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

-- The agent a teammate has locked in, so nobody else on the team can take it.
local function lockedBy(selection: Selection, agentId: string, except: Player): Player?
	for member, pick in selection.picks do
		if member ~= except and pick.lockedIn and pick.loadout and pick.loadout.AgentId == agentId then
			return member
		end
	end
	return nil
end

local function broadcast(selection: Selection, active: boolean)
	local members: { Types.PreDeployMember } = {}
	local targets: { Player } = {}
	for member, pick in selection.picks do
		table.insert(targets, member)
		table.insert(members, {
			UserId = member.UserId,
			DisplayName = member.DisplayName,
			LockedIn = pick.lockedIn,
			AgentId = pick.loadout and pick.loadout.AgentId,
			HardwareId = pick.loadout and pick.loadout.HardwareId,
		})
	end
	table.sort(members, function(a, b)
		return a.UserId < b.UserId
	end)
	local state: Types.PreDeployState = {
		Active = active,
		Mode = MetaProgressionService.queueInfo().Mode,
		EndsAt = selection.endsAt,
		Members = members,
	}
	RemoteService.fireClients("PreDeployStateUpdated", targets, state)
end

-- A starting pick for someone entering select: their equipped loadout, unless a teammate has already locked that agent.
local function startingPick(selection: Selection, player: Player): Pick
	local loadout = MetaProgressionService.getLoadout(player)
	if loadout and lockedBy(selection, loadout.AgentId, player) then
		loadout = nil
	end
	return { loadout = loadout, lockedIn = false }
end

-- At the cutoff every member gets an agent no teammate has: locked picks first (the server never lets two lock the same
-- agent), then the rest in join order, each keeping their own pick if it is still free, else the first agent they own
-- that is free (with its W1, which every agent has built and open from mastery 1).
-- SPEC-QUESTION: if every agent a player owns is taken by teammates, they keep their equipped loadout, duplicating an
-- agent, rather than being left out of the match; with 3 starter agents and at most 2 per team this cannot happen yet.
local function resolveLoadouts(selection: Selection): { [Player]: Types.PlayerLoadout }
	local order: { Player } = {}
	for member in selection.picks do
		table.insert(order, member)
	end
	table.sort(order, function(a: Player, b: Player)
		local aLocked, bLocked = selection.picks[a].lockedIn, selection.picks[b].lockedIn
		if aLocked ~= bLocked then
			return aLocked
		end
		return a.UserId < b.UserId
	end)
	local taken: { [string]: boolean } = {}
	local result: { [Player]: Types.PlayerLoadout } = {}
	for _, member in order do
		local loadout = selection.picks[member].loadout
		if not loadout or taken[loadout.AgentId] then
			loadout = nil
			for _, agentId in MetaProgressionService.ownedAgents(member) do
				if not taken[agentId] then
					loadout = { AgentId = agentId, HardwareId = WeaponDefs.getForAgent(agentId)[1].Id }
					break
				end
			end
		end
		loadout = loadout or MetaProgressionService.getLoadout(member)
		if loadout then
			taken[loadout.AgentId] = true
			result[member] = loadout
		end
	end
	return result
end

local function finish(selection: Selection)
	if selections[selection.teamId] ~= selection then
		return
	end
	selections[selection.teamId] = nil
	broadcast(selection, false)
	local final = resolveLoadouts(selection)
	for member in selection.picks do
		local loadout = final[member]
		if loadout then
			MetaProgressionService.setLoadout(member, loadout)
			CombatService.setLoadoutWeapon(member, loadout.HardwareId)
		end
		deployed[member] = true
		task.spawn(RigService.spawn, member)
	end
end

local function inMenu(player: Player): boolean
	return not deployed[player] and player.Character == nil
end

local function onStart(player: Player)
	if not inMenu(player) or not MetaProgressionService.getLoadout(player) then
		return -- already in the match, or owns no agent yet (the free picks come first)
	end
	local teamId = TeamService.teamOf(player)
	if not teamId then
		return
	end
	local selection = selections[teamId]
	if not selection then
		local created: Selection = {
			teamId = teamId,
			endsAt = now() + GameConfig.Lobby.AgentSelectSeconds,
			picks = {},
		}
		selection = created
		selections[teamId] = created
		task.delay(GameConfig.Lobby.AgentSelectSeconds, finish, created)
	end
	local active = selection :: Selection
	-- Everyone on the team who is still in the menu and owns an agent joins this select.
	for _, member in TeamService.members(teamId) do
		if not active.picks[member] and inMenu(member) and MetaProgressionService.getLoadout(member) then
			active.picks[member] = startingPick(active, member)
		end
	end
	broadcast(active, true)
end

local function onLockIn(player: Player, request: unknown)
	local teamId = TeamService.teamOf(player)
	local selection = teamId and selections[teamId]
	local pick = selection and selection.picks[player]
	if not selection or not pick or now() >= selection.endsAt then
		return
	end
	local loadout = MetaProgressionService.validateLoadout(player, request)
	if not loadout or lockedBy(selection, loadout.AgentId, player) then
		broadcast(selection, true) -- refused: resend, so the client shows the server's state again
		return
	end
	pick.loadout = loadout
	pick.lockedIn = true
	broadcast(selection, true)
end

-- Every mode is one server's mode until matchmaking; the request only confirms the client's choice is available.
local function onQueueMode(player: Player, mode: unknown)
	local snapshot = MetaProgressionService.snapshot(player)
	if snapshot and type(mode) == "string" and table.find(snapshot.Queue.Available, mode :: Types.QueueMode) then
		RemoteService.fireClient("ProfileStateUpdated", player, snapshot)
	end
end

function LobbyService.Init() end

function LobbyService.Start()
	if not GameConfig.Debug.MenuOnJoin then
		-- Players spawn straight in (RigService), so the menu never opens and agent select never runs.
		return
	end
	RemoteService.onRequest("RequestStartPreDeploy", onStart)
	RemoteService.onRequest("RequestLockInPreDeploy", onLockIn)
	RemoteService.onRequest("RequestQueueMode", onQueueMode)
	Players.PlayerRemoving:Connect(function(player)
		deployed[player] = nil
		for _, selection in selections do
			if selection.picks[player] then
				selection.picks[player] = nil
				broadcast(selection, true)
			end
		end
	end)
end

return LobbyService
