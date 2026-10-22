--!strict
-- The single list of RemoteEvents (spec 25.6). The server creates all of them at boot inside
-- ReplicatedStorage/Remotes; never create remotes by hand in Studio.
-- Client -> server remotes are always rate-limited; see GameConfig.Network.

local DeepFreeze = require(script.Parent.Util.DeepFreeze)

local Remotes = {
	-- Server -> client
	ServerToClient = {
		"PhaseChanged",
		"TimerSync",
		"CoverStateChanged",
		"SuspicionUpdate",
		"TrespassWarning",
		"ExposedPing",
		"IntelUpdate",
		"GlobalIntelUpdate",
		"VaultProgress",
		"PackageState",
		"ExtractionState",
		"AlarmLevel",
		"HitConfirm",
		"DamageTaken",
		"Downed",
		"Revived",
		"Eliminated",
		"KillFeed",
		"FundsUpdate",
		"CooldownUpdate",
		"Notification",
		"NPCAnimation", -- NPC id and the animation it is playing (implementation detail of spec 5.3)
		"DisguiseUpdate", -- to the owner only: the disguise worn and the slots (spec 6.3, 6.4)
		"ScanState", -- to the scanner only: a scan started, was cancelled or finished (spec 6.3)
	},

	-- Client -> server (requests only; the server validates every one)
	ClientToServer = {
		"RequestScan",
		"RequestDisguise",
		"RequestInteract",
		"RequestInteractCancel",
		"FireRequest",
		"ReloadRequest",
		"RequestAbility",
		"RequestGadget",
		"RequestMelee",
		"RequestPurchase",
		"RequestPing",
		"RequestDropPackage",
		"RequestPassPackage",
		"RequestEmote",
		"RequestSprint", -- sprint on or off (spec 6.8)
		"RequestDebugEvent", -- development only; ignored unless GameConfig.Debug.TestEvents is on
	},

	FolderName = "Remotes",
}

-- Lookup sets, so code can check direction without scanning the lists.
local serverToClient: { [string]: true } = {}
for _, name in Remotes.ServerToClient do
	serverToClient[name] = true
end
local clientToServer: { [string]: true } = {}
for _, name in Remotes.ClientToServer do
	assert(not serverToClient[name], `Remote {name} is listed in both directions`)
	clientToServer[name] = true
end

local module = {
	ServerToClient = Remotes.ServerToClient,
	ClientToServer = Remotes.ClientToServer,
	FolderName = Remotes.FolderName,
}

function module.isServerToClient(name: string): boolean
	return serverToClient[name] == true
end

function module.isClientToServer(name: string): boolean
	return clientToServer[name] == true
end

return DeepFreeze(module)
