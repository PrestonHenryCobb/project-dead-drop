--!strict
-- Creates every RemoteEvent and RemoteFunction from shared/Remotes at boot and is the only way the server talks over them.
--
--   RemoteService.onRequest("RequestScan", function(player, targetId) ... end)
--   RemoteService.onInvoke("RequestEquipLoadout", function(player, request) return true end)
--   RemoteService.fireClient("Notification", player, text)
--
-- Every client -> server remote is rate-limited here before a handler sees it. Handlers still have to validate
-- their arguments (types, ranges, game state); the rate limiter only stops floods.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local RateLimiter = require(Shared:WaitForChild("Util"):WaitForChild("RateLimiter"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local RemoteService = {}

local events: { [string]: RemoteEvent } = {}
local functions: { [string]: RemoteFunction } = {}
local limiters: { [string]: RateLimiter.RateLimiter } = {}

local function limitFor(name: string): { PerSecond: number, Burst: number }
	local overrides = GameConfig.Network.RateLimits :: { [string]: { PerSecond: number, Burst: number } }
	return overrides[name] or GameConfig.Network.DefaultRateLimit
end

local function getEvent(name: string): RemoteEvent
	local event = events[name]
	assert(event, `Unknown remote "{name}". Add it to shared/Remotes.luau first.`)
	return event
end

function RemoteService.Init()
	assert(not ReplicatedStorage:FindFirstChild(Remotes.FolderName), "Remotes folder already exists")
	local folder = Instance.new("Folder")
	folder.Name = Remotes.FolderName

	for _, name in Remotes.ServerToClient do
		local event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = folder
		events[name] = event
	end
	for _, name in Remotes.ClientToServer do
		local event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = folder
		events[name] = event
		local limit = limitFor(name)
		limiters[name] = RateLimiter.new(limit.PerSecond, limit.Burst)
	end
	for _, name in Remotes.ClientToServerFunctions do
		local remote = Instance.new("RemoteFunction")
		remote.Name = name
		remote.Parent = folder
		functions[name] = remote
		local limit = limitFor(name)
		limiters[name] = RateLimiter.new(limit.PerSecond, limit.Burst)
	end

	folder.Parent = ReplicatedStorage
end

function RemoteService.Start()
	Players.PlayerRemoving:Connect(function(player)
		for _, limiter in limiters do
			limiter:Remove(player)
		end
	end)
end

-- Connects a handler for a client -> server remote. Requests over the rate limit are dropped silently.
function RemoteService.onRequest(name: string, handler: (player: Player, ...any) -> ()): RBXScriptConnection
	assert(Remotes.isClientToServer(name), `{name} is not a client -> server remote`)
	local limiter = limiters[name]
	return getEvent(name).OnServerEvent:Connect(function(player: Player, ...: any)
		if not limiter:Allow(player) then
			return
		end
		handler(player, ...)
	end)
end

-- Sets the handler for a client -> server RemoteFunction; what it returns goes back to the caller. A call over the
-- rate limit returns (false, "RateLimited") without reaching the handler.
function RemoteService.onInvoke(name: string, handler: (player: Player, ...any) -> ...any)
	assert(Remotes.isClientFunction(name), `{name} is not a client -> server function`)
	local limiter = limiters[name]
	functions[name].OnServerInvoke = function(player: Player, ...: any): ...any
		if not limiter:Allow(player) then
			return false, "RateLimited"
		end
		return handler(player, ...)
	end
end

function RemoteService.fireClient(name: string, player: Player, ...: any)
	assert(Remotes.isServerToClient(name), `{name} is not a server -> client remote`)
	getEvent(name):FireClient(player, ...)
end

function RemoteService.fireClients(name: string, targets: { Player }, ...: any)
	assert(Remotes.isServerToClient(name), `{name} is not a server -> client remote`)
	local event = getEvent(name)
	for _, player in targets do
		event:FireClient(player, ...)
	end
end

function RemoteService.fireAllClients(name: string, ...: any)
	assert(Remotes.isServerToClient(name), `{name} is not a server -> client remote`)
	getEvent(name):FireAllClients(...)
end

return RemoteService
