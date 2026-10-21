--!strict
-- The client's only way to talk over remotes. Remotes are created by the server at boot, so lookups wait for them.
--
--   RemoteController.connect("PhaseChanged", function(phase, data) ... end)
--   RemoteController.fire("RequestScan", targetId)
--
-- Client -> server calls are requests only; the server validates them and may ignore them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))

local RemoteController = {}

local cache: { [string]: RemoteEvent } = {}

local function getEvent(name: string): RemoteEvent
	local cached = cache[name]
	if cached then
		return cached
	end
	local folder = ReplicatedStorage:WaitForChild(Remotes.FolderName)
	local event = folder:WaitForChild(name) :: RemoteEvent
	cache[name] = event
	return event
end

function RemoteController.Init() end

-- Waits for every remote so later controllers never see a half-built set.
function RemoteController.Start()
	for _, name in Remotes.ServerToClient do
		getEvent(name)
	end
	for _, name in Remotes.ClientToServer do
		getEvent(name)
	end
end

function RemoteController.connect(name: string, handler: (...any) -> ()): RBXScriptConnection
	assert(Remotes.isServerToClient(name), `{name} is not a server -> client remote`)
	return getEvent(name).OnClientEvent:Connect(handler)
end

function RemoteController.fire(name: string, ...: any)
	assert(Remotes.isClientToServer(name), `{name} is not a client -> server remote`)
	getEvent(name):FireServer(...)
end

return RemoteController
