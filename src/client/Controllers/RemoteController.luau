--!strict
-- The client's only way to talk over remotes. Remotes are created by the server at boot, so lookups wait for them.
--
--   RemoteController.connect("PhaseChanged", function(phase, data) ... end)
--   RemoteController.fire("RequestScan", targetId)
--   local ok, reason = RemoteController.invoke("RequestEquipLoadout", request) -- yields for the server's answer
--
-- Client -> server calls are requests only; the server validates them and may ignore them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))

local RemoteController = {}

local cache: { [string]: Instance } = {}

local function getRemote(name: string): Instance
	local cached = cache[name]
	if cached then
		return cached
	end
	local folder = ReplicatedStorage:WaitForChild(Remotes.FolderName)
	local remote = folder:WaitForChild(name)
	cache[name] = remote
	return remote
end

local function getEvent(name: string): RemoteEvent
	return getRemote(name) :: RemoteEvent
end

function RemoteController.Init() end

-- Waits for every remote so later controllers never see a half-built set.
function RemoteController.Start()
	for _, name in Remotes.ServerToClient do
		getRemote(name)
	end
	for _, name in Remotes.ClientToServer do
		getRemote(name)
	end
	for _, name in Remotes.ClientToServerFunctions do
		getRemote(name)
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

-- Calls a client -> server RemoteFunction and yields until the server answers. Call it from a task, never a render step.
function RemoteController.invoke(name: string, ...: any): ...any
	assert(Remotes.isClientFunction(name), `{name} is not a client -> server function`)
	return (getRemote(name) :: RemoteFunction):InvokeServer(...)
end

return RemoteController
