--!strict
-- Ticket 19-pings (spec 21.3): team pings. A player presses the ping button and a marker appears for their team only
-- ("Look here", "Suspect" on a person, "Intel", "Danger"). At most GameConfig.UI.MaxPingsPerPlayer are up at once: a new one
-- replaces the oldest. A Suspect ping lasts UI.SuspectPingSeconds, the others Ping.Seconds.
--
-- Identity secrecy (CLAUDE.md rule 3): a Suspect ping names a body by the model name every client already sees and never says
-- whether it is a player or an NPC, so the marker teaches nothing. Markers go only to the pinger and their team; the client
-- draws them (nothing is placed on a character).
--
-- The request is (kind, position, targetId?). The server checks the player is in the match and not downed, the kind is known, the
-- position is finite and within Ping.RangeStuds of them, and a Suspect target is a body that exists and is in range.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Types = require(Shared:WaitForChild("Types"))
local Validate = require(Shared:WaitForChild("Util"):WaitForChild("Validate"))
local History = require(script.Parent.Parent.Combat.History)
local DownedService = require(script.Parent.DownedService)
local MatchService = require(script.Parent.MatchService)
local RemoteService = require(script.Parent.RemoteService)
local TeamService = require(script.Parent.TeamService)

local PingService = {}

local config = GameConfig.Ping

local active: { [Player]: { Types.PingInfo } } = {}
local nextId = 0

-- The pinger and their team's members who are still in the game.
local function audience(player: Player): { Player }
	local teamId = TeamService.teamOf(player)
	if not teamId then
		return { player }
	end
	local list: { Player } = {}
	for _, member in TeamService.members(teamId) do
		if member.Parent then
			table.insert(list, member)
		end
	end
	if not table.find(list, player) then
		table.insert(list, player)
	end
	return list
end

local function remove(player: Player, id: number)
	local list = active[player]
	if not list then
		return
	end
	for index, info in list do
		if info.Id == id then
			table.remove(list, index)
			RemoteService.fireClients("PingCleared", audience(player), id)
			return
		end
	end
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- A body by the model name the client sees. History keys an NPC by that name but a player as "P" and a UserId, which must never
-- reach a client (it would say the body is a player), so players are matched by their character model's name instead.
local function findBody(modelName: string): History.Target?
	local direct = History.targets[modelName]
	if direct and direct.kind == "Npc" then
		return direct
	end
	for _, target in History.targets do
		local model = target.rootPart.Parent
		if target.kind == "Agent" and model and model.Name == modelName then
			return target
		end
	end
	return nil
end

local function onRequest(player: Player, kind: unknown, position: unknown, targetId: unknown)
	if not MatchService.isInMatch() or DownedService.isOut(player) then
		return
	end
	local root = rootOf(player)
	if type(kind) ~= "string" or not (config.Kinds :: { [string]: boolean })[kind] or not root then
		return
	end
	local at = Validate.vector3(position)
	if not at or (at - root.Position).Magnitude > config.RangeStuds then
		return
	end
	local seconds = config.Seconds
	local marked: string? = nil
	if kind == "Suspect" then
		local target = if type(targetId) == "string" then findBody(targetId) else nil
		if
			not target
			or target.player == player
			or (target.rootPart.Position - root.Position).Magnitude > config.RangeStuds
		then
			return
		end
		at = target.rootPart.Position
		marked = targetId :: string -- the model name the client sent, never the History id
		seconds = GameConfig.UI.SuspectPingSeconds
	end

	local list = active[player]
	if not list then
		list = {}
		active[player] = list
	end
	while #list >= GameConfig.UI.MaxPingsPerPlayer do
		remove(player, list[1].Id)
	end
	nextId += 1
	local info: Types.PingInfo = {
		Id = nextId,
		Kind = kind,
		Position = at,
		TargetId = marked,
		ExpiresAt = workspace:GetServerTimeNow() + seconds,
		From = player.DisplayName,
	}
	table.insert(list, info)
	RemoteService.fireClients("PingPlaced", audience(player), info)
	local id = info.Id
	task.delay(seconds, remove, player, id)
end

function PingService.Init() end

function PingService.Start()
	RemoteService.onRequest("RequestPing", onRequest)
	MatchService.onPhaseChanged(function(phase)
		if phase == "Lobby" or phase == "Insertion" then
			table.clear(active)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		local list = active[player]
		if list then
			for _, info in table.clone(list) do
				remove(player, info.Id)
			end
		end
		active[player] = nil
	end)
end

return PingService
