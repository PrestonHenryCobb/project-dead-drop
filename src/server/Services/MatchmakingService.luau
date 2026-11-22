--!strict
-- Ticket matchmaking (Step 22, spec 25.7): the lobby place queues players and teleports them to a reserved match server; the match
-- server adopts the mode they queued for and starts their agent select. Dormant ("Single" role) until both place ids are set in
-- GameConfig.Matchmaking and Enabled is true, and in Studio, where teleporting does not work.
--
-- Lobby servers:
--   RequestFindMatch(mode) puts the player in that mode's MemoryStore queue and tells them they are searching (MatchmakingState).
--   Every lobby server, every TickSeconds, tries to form a match from each queue: it reads the mode's MinPlayers all-or-nothing (the
--   read is atomic across servers, so two servers never form the same match), tops up to MaxPlayers, reserves a match server and
--   publishes the match on MessagingService. Each lobby server then teleports the players it holds who are in that match.
--   Entries are individual (no party grouping yet) and a cancelled player is simply not teleported when their entry comes up.
-- Match servers:
--   A player who arrives from a lobby starts agent select at once, as if they had pressed Play (TeamService has already taken the
--   mode from the teleport data). Empty slots are filled by the bots (BotService). When the results screen ends, everyone is
--   teleported back to the lobby place (the menu); if that fails, the match server opens its own lobby as before.
--
--   MatchmakingService.role() -> "Single" | "Lobby" | "Match"

local MemoryStoreService = game:GetService("MemoryStoreService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local PlaceRole = require(Shared:WaitForChild("Util"):WaitForChild("PlaceRole"))
local Types = require(Shared:WaitForChild("Types"))
local LobbyService = require(script.Parent.LobbyService)
local MatchService = require(script.Parent.MatchService)
local MetaProgressionService = require(script.Parent.MetaProgressionService)
local RemoteService = require(script.Parent.RemoteService)

local MatchmakingService = {}

local config = GameConfig.Matchmaking

local searching: { [Player]: string } = {} -- the mode each queued player on this server is waiting for
local queues: { [string]: MemoryStoreQueue } = {}

function MatchmakingService.role(): string
	return PlaceRole.get()
end

local function tell(player: Player, state: string, mode: string?, reason: string?)
	local info: Types.MatchmakingStateInfo = { State = state, Mode = mode, Reason = reason }
	RemoteService.fireClient("MatchmakingState", player, info)
end

local function queueFor(mode: string): MemoryStoreQueue
	local queue = queues[mode]
	if not queue then
		queue = MemoryStoreService:GetQueue(config.QueuePrefix .. mode, config.ReadInvisibilitySeconds)
		queues[mode] = queue
	end
	return queue
end

local function isQueueable(mode: unknown): boolean
	return type(mode) == "string" and table.find(config.Modes, mode) ~= nil
end

local function onFind(player: Player, mode: unknown): (boolean, string?)
	if PlaceRole.get() ~= "Lobby" then
		return false, "NotAvailable"
	end
	if not isQueueable(mode) then
		return false, "UnknownMode"
	end
	local chosen = mode :: string
	if searching[player] then
		return false, "AlreadySearching"
	end
	if not MetaProgressionService.getLoadout(player) then
		return false, "NoAgent" -- the free first-launch picks come first
	end
	local ok = pcall(function()
		queueFor(chosen):AddAsync(player.UserId, config.QueueExpirySeconds, 0)
	end)
	if not ok then
		return false, "QueueUnavailable"
	end
	searching[player] = chosen
	tell(player, "Searching", chosen, nil)
	-- A search that finds nobody in time ends by itself (the queue entry has expired too).
	task.delay(config.QueueExpirySeconds, function()
		if searching[player] == chosen then
			searching[player] = nil
			tell(player, "Failed", chosen, "NoMatchFound")
		end
	end)
	return true, nil
end

local function onCancel(player: Player): (boolean, string?)
	local mode = searching[player]
	if not mode then
		return false, "NotSearching"
	end
	searching[player] = nil
	tell(player, "Idle", mode, nil)
	return true, nil
end

-- Reads one match's worth of players from a mode's queue and announces it. Runs on every lobby server; the queue read decides who wins.
local function tryForm(mode: string)
	local rules = GameConfig.Modes[mode]
	local queue = queueFor(mode)
	local ok, userIds = pcall(function()
		local items, readId = queue:ReadAsync(rules.MinPlayers, true, 0)
		if not items or #items < rules.MinPlayers then
			return nil
		end
		local ids: { number } = {}
		for _, item in items do
			if type(item) == "number" then
				table.insert(ids, item)
			end
		end
		local more, moreId = queue:ReadAsync(rules.MaxPlayers - #ids, false, 0)
		if more then
			for _, item in more do
				if type(item) == "number" then
					table.insert(ids, item)
				end
			end
		end
		queue:RemoveAsync(readId)
		if moreId then
			queue:RemoveAsync(moreId)
		end
		return ids
	end)
	if not ok or not userIds or #userIds == 0 then
		return
	end
	local reserved, code = pcall(function()
		return TeleportService:ReserveServer(config.MatchPlaceId)
	end)
	if not reserved then
		return -- the players were taken off the queue; their search will time out. Rare, and the next search works
	end
	pcall(function()
		MessagingService:PublishAsync(config.MatchTopic, { Mode = mode, Code = code, UserIds = userIds })
	end)
end

local function teleportMatch(message: any)
	local data = message.Data
	if
		type(data) ~= "table"
		or type(data.Code) ~= "string"
		or type(data.UserIds) ~= "table"
		or type(data.Mode) ~= "string"
	then
		return
	end
	local group: { Player } = {}
	for _, userId in data.UserIds do
		local player = if type(userId) == "number" then Players:GetPlayerByUserId(userId) else nil
		if player and searching[player] == data.Mode then
			table.insert(group, player)
		end
	end
	if #group == 0 then
		return
	end
	for _, player in group do
		searching[player] = nil
		tell(player, "Found", data.Mode, nil)
	end
	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = data.Code
	options:SetTeleportData({ Mode = data.Mode, Matched = true })
	local ok, reason = pcall(function()
		TeleportService:TeleportAsync(config.MatchPlaceId, group, options)
	end)
	if not ok then
		for _, player in group do
			tell(player, "Failed", data.Mode, tostring(reason))
		end
	end
end

-- The results screen is over: send everyone back to the lobby place, the menu. A failed teleport leaves them in this server's lobby.
local function returnToLobby()
	local group = Players:GetPlayers()
	if #group == 0 then
		return
	end
	local ok = pcall(function()
		TeleportService:TeleportAsync(config.LobbyPlaceId, group)
	end)
	if not ok then
		warn("[Matchmaking] could not return the players to the lobby place")
	end
end

local function greetArrival(player: Player)
	local data = player:GetJoinData().TeleportData
	if type(data) ~= "table" or data.Matched ~= true then
		return
	end
	local waited = 0
	while player.Parent and not MetaProgressionService.getLoadout(player) and waited < config.JoinLoadWaitSeconds do
		task.wait(config.JoinLoadPollSeconds)
		waited += config.JoinLoadPollSeconds
	end
	if player.Parent and MetaProgressionService.getLoadout(player) then
		LobbyService.begin(player)
	end
end

function MatchmakingService.Init() end

function MatchmakingService.Start()
	local role = PlaceRole.get()
	if role == "Single" then
		return
	end
	if role == "Match" then
		Players.PlayerAdded:Connect(function(player)
			task.spawn(greetArrival, player)
		end)
		for _, player in Players:GetPlayers() do
			task.spawn(greetArrival, player)
		end
		local sawResults = false
		MatchService.onPhaseChanged(function(phase)
			if phase == "Results" then
				sawResults = true
			elseif phase == "Lobby" and sawResults then
				returnToLobby() -- the results screen has ended (not the server's first Lobby at boot)
			end
		end)
		return
	end
	RemoteService.onInvoke("RequestFindMatch", onFind)
	RemoteService.onInvoke("RequestCancelFindMatch", onCancel)
	Players.PlayerRemoving:Connect(function(player)
		searching[player] = nil
	end)
	pcall(function()
		MessagingService:SubscribeAsync(config.MatchTopic, teleportMatch)
	end)
	task.spawn(function()
		while true do
			task.wait(config.TickSeconds)
			for _, mode in config.Modes do
				tryForm(mode)
			end
		end
	end)
end

return MatchmakingService
