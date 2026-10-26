--!strict
-- The single list of RemoteEvents and RemoteFunctions (spec 25.6). The server creates all of them at boot inside
-- ReplicatedStorage/Remotes; never create remotes by hand in Studio.
-- Client -> server remotes are always rate-limited; see GameConfig.Network.

local DeepFreeze = require(script.Parent.Util.DeepFreeze)

local Remotes = {
	-- Server -> client
	ServerToClient = {
		"TestLoadoutChanged", -- Ticket studio-test-loadout: Studio-only, selected weapon to its owner only.
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
		"AgentSense", -- to one player: an Agent Sense shimmer or the exposed-enemy vignette (spec 8.3)
		"AmmoUpdate", -- to the owner only: magazine and reserve (spec 13.5), and a reload starting
		"HealthUpdate", -- to the owner only: health and armour (spec 13.1)
		"ShotHeard", -- to players within earshot of a shot: where it came from and where it landed (spec 23)
		"MeleeState", -- to the owner only: a takedown started or ended (spec 13.4)
		"SwapMarker", -- to a rival who comes within range: where someone changed disguise, until when (brief Q6)
		"ScopeGlint", -- to a rival agent who can see a scoped DMR: where the glint is (STEP8 unique effects)
		"InteractState", -- to the holder only: a hold-interaction (revive, execute, later intel and doors) began or ended
		"TakedownVictim", -- to the target of a takedown only: the hold on them began or ended (R5-takedown)
		"TeamRoster", -- to each member of a team only: who is on it (rule 3; spec 3.3 teammate markers build on it)
		-- Ticket menu-phase0
		"PreDeployStateUpdated", -- to each member of a team only: agent select picks and the cutoff (Types.PreDeployState)
		"ProfileStateUpdated", -- to the owner only: their profile and loadout changed (Types.MetaSnapshot)
	},

	-- Client -> server (requests only; the server validates every one)
	ClientToServer = {
		"RequestTestLoadout", -- Ticket studio-test-loadout: ignored outside Studio; server chooses the next weapon.
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
		"RequestCrouch", -- crouch on or off (spec 6.8)
		"RequestSense", -- the character in the crosshair within Agent Sense range, or nil (spec 8.3)
		"RequestDraw", -- aim (draw) the weapon on or off (spec 13.2)
		"RequestCrawl", -- while downed: the way to crawl, a flat direction or zero (spec 14.1)
		-- Ticket menu-phase0
		"RequestQueueMode", -- the mode to queue for (Types.QueueMode)
		"RequestStartPreDeploy", -- start agent select for the player's party
		"RequestLockInPreDeploy", -- agent select pick (Types.LoadoutRequest); may be sent again to revise until the cutoff
	},

	-- Client -> server RemoteFunctions, for menu requests that need an answer. Each returns (ok: boolean, reason: string?)
	-- unless noted. Rate-limited like the events; a limited call returns (false, "RateLimited").
	ClientToServerFunctions = {
		"GetPlayerMetaProfile", -- returns Types.MetaSnapshot
		"RequestEquipLoadout", -- (Types.LoadoutRequest)
		"RequestClaimStarterAgent", -- (agentId): the free first-launch pick for that agent's class
		"RequestClaimDossierTier", -- (dossierId, tierIndex)
		"RequestSelectActiveDossier", -- (dossierId)
		"RequestBlackMarketPurchase", -- (offerId)
		-- (packageId) Studio-only mock grant for testing the Mint; real Stocks come from Robux purchases (Step 21).
		"RequestMintStrikeStocks",
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
local clientFunctions: { [string]: true } = {}
for _, name in Remotes.ClientToServerFunctions do
	assert(not serverToClient[name] and not clientToServer[name], `Remote {name} is listed twice`)
	clientFunctions[name] = true
end

local module = {
	ServerToClient = Remotes.ServerToClient,
	ClientToServer = Remotes.ClientToServer,
	ClientToServerFunctions = Remotes.ClientToServerFunctions,
	FolderName = Remotes.FolderName,
}

function module.isServerToClient(name: string): boolean
	return serverToClient[name] == true
end

function module.isClientToServer(name: string): boolean
	return clientToServer[name] == true
end

function module.isClientFunction(name: string): boolean
	return clientFunctions[name] == true
end

return DeepFreeze(module)
