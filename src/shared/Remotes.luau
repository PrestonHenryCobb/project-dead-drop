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
		"WristWatchState", -- to the owner only: the wrist watch goes up or down (Types.WristWatchInfo); the client draws the first-person watch
		"InteractState", -- to the holder only: a hold-interaction (revive, execute, later intel and doors) began or ended
		"TakedownVictim", -- to the target of a takedown only: the hold on them began or ended (R5-takedown)
		"TeamRoster", -- to each member of a team only: who is on it (rule 3; spec 3.3 teammate markers build on it)
		-- Tickets 8.5a/b/e/f (weapon server contracts, see .ai-sync/WEAPON_SERVER_CONTRACTS.md)
		"ProjectileLaunched", -- a flare or knife is in flight (Types.ProjectileLaunchInfo)
		"ProjectileImpact", -- it landed (Types.ProjectileImpactInfo)
		"SmokeCloud", -- to everyone: a smoke cloud (Types.SmokeCloudInfo)
		"TargetGlow", -- to Suture's team only: a flare-struck character glows (Types.TargetGlowInfo)
		"CombatStatus", -- to the victim only: stagger or shove (Types.CombatStatusInfo)
		-- Ticket 9c
		"SpectateState", -- to a spectator only: who they watch, or the drone (Types.SpectateStateInfo)
		"SpectatorChat", -- to spectators only: a filtered chat line (Types.SpectatorChatInfo)
		-- GPS carrier tracking (docs/GPS_DESIGN.md)
		"CarrierTrackState", -- to the Package carrier only: rivals they see now (Types.CarrierTrackInfo)
		"TrackedCue", -- to a tracked rival only, no payload: they were seen (a vignette and a whisper)
		-- Ticket 18e
		"AssetState", -- to the owner only: their four Asset slots and which are found (Types.AssetStateInfo)
		-- Ticket 19-pings
		"PingPlaced", -- to the pinger and their team only: a marker to draw (Types.PingInfo)
		"PingCleared", -- the id (a number) of a marker that ended early
		-- Ticket 21-rewards
		"MatchRewards", -- to one player after a match: their XP breakdown, level and Credits (Types.MatchRewardsInfo)
		-- Ticket 18c
		"ShopState", -- to the shopper only: the Supply Cache shop they have open (Types.ShopStateInfo)
		-- Ticket 17d
		"BugCamState", -- to the owner only: where their Bug Cams are, to view them (Types.BugCamStateInfo)
		-- Ticket auto-recover
		"AutoRecoverState", -- to the owner only: a re-cover ring started or ended, and whether the option is on (Types.AutoRecoverInfo)
		-- Ticket 17
		"Launch", -- to the player a Spring Pad throws: the velocity to take (Vector3)
		"GadgetState", -- to the owner only: their gadgets, charges and what is held (Types.GadgetStateInfo)
		-- Ticket 16c
		"SparrowState", -- to Lattice only: her drone took off or ended (Types.SparrowStateInfo)
		-- Ticket menu-phase0
		"PreDeployStateUpdated", -- to each member of a team only: agent select picks and the cutoff (Types.PreDeployState)
		"SprayPlaced", -- to everyone: a spray on a wall (Types.SprayInfo; ticket spray)
		"SprayCleared", -- to everyone: the id (a number) of a spray that ended early
		"MatchmakingState", -- to the owner only: searching, match found, or failed (Types.MatchmakingStateInfo)
		"ProfileStateUpdated", -- to the owner only: their profile and loadout changed (Types.MetaSnapshot)
	},

	-- Client -> server (requests only; the server validates every one)
	ClientToServer = {
		"RequestTestLoadout", -- Ticket studio-test-loadout: ignored outside Studio; server chooses the next weapon.
		"RequestScan",
		"RequestDisguise",
		"RequestInteract",
		"RequestInteractCancel",
		"RequestDropPackage", -- ticket 13a: the carrier drops the Package (spec 11)
		"FireRequest",
		"ReloadRequest",
		"RequestAbility",
		"RequestGadget",
		"RequestMelee",
		"RequestPurchase",
		"RequestSpray", -- (position, normal): place your equipped spray on the wall you aim at (ticket spray); the server checks everything
		"RequestPing", -- ticket 19-pings: (kind, position, targetId?) a team-only marker; the server limits range, count and kind
		"RequestPassPackage",
		"RequestEmote",
		"RequestSprint", -- sprint on or off (spec 6.8)
		"RequestCrouch", -- crouch on or off (spec 6.8)
		"RequestSense", -- the character in the crosshair within Agent Sense range, or nil (spec 8.3)
		"RequestDraw", -- aim (draw) the weapon on or off (spec 13.2)
		"RequestCrawl", -- while downed: the way to crawl, a flat direction or zero (spec 14.1)
		-- Ticket 9c
		"RequestSpectate", -- "Next", "Previous" or "Drone"; only honoured for an eliminated player
		"RequestDronePosition", -- the drone camera's wanted position; the server limits speed and clamps it
		"RequestSpectatorChat", -- a chat line for the other spectators
		-- Ticket 18c
		"RequestShopBuy", -- an item id of the open shop (a string)
		"RequestShopClose", -- leave the open shop
		-- Ticket auto-recover
		"RequestAutoRecover", -- turn the Auto re-cover option on or off (a boolean)
		-- GPS carrier tracking
		"RequestCarrierTrack", -- the carrier's tracking key went down (true) or up (false); the server tells a tap from a hold
		-- Ticket 7B-glass-elevators
		"RequestElevatorFloor", -- the level name ("G", "M", ...) the player in a cab wants (a string)
		-- Ticket 16c
		"RequestSparrowMove", -- the way the drone should fly, a vector of up to length 1 in world space (zero to hover)
		-- Ticket menu-phase0
		"RequestQueueMode", -- the mode to queue for (Types.QueueMode)
		"RequestStartPreDeploy", -- start agent select for the player's party
		"RequestLockInPreDeploy", -- agent select pick (Types.LoadoutRequest); may be sent again to revise until the cutoff
	},

	-- Client -> server RemoteFunctions, for menu requests that need an answer. Each returns (ok: boolean, reason: string?)
	-- unless noted. Rate-limited like the events; a limited call returns (false, "RateLimited").
	ClientToServerFunctions = {
		"GetPlayerMetaProfile", -- returns Types.MetaSnapshot
		"RequestRoute", -- GPS (docs/GPS_DESIGN.md): (targetId?) returns Types.RouteResult
		"RequestEquipLoadout", -- (Types.LoadoutRequest)
		"RequestClaimStarterAgent", -- (agentId): the free first-launch pick for that agent's class
		"RequestClaimDossierTier", -- (dossierId, tierIndex)
		"RequestSelectActiveDossier", -- (dossierId)
		"RequestBlackMarketPurchase", -- (offerId): a daily offer id, or the featured bundle id; returns (ok, reason?)
		"GetBlackMarketOffers", -- returns Types.BlackMarketState (ticket shop-skeleton)
		"RequestFindMatch", -- (mode): queue for a match on the lobby place (ticket matchmaking); returns (ok, reason?)
		"RequestCancelFindMatch", -- leave the queue; returns (ok, reason?)
		"RequestEquipCosmetic", -- (kind, cosmeticId?): equip an owned Title or Card, or clear it with nil (ticket equip-cosmetics); returns (ok, reason?)
		"RequestBuyDossierPremium", -- (dossierId): unlock a Dossier's premium track with Stocks (ticket dossier); returns (ok, reason?)
		"RequestBuyAgent", -- (agentId): buy a locked agent with Credits (ticket shop-skeleton)
		-- (packageId) Studio-only mock grant for testing the Mint; real Stocks come from Robux purchases (Step 21).
		"RequestMintStrikeStocks",
	},

	FolderName = "Remotes",
}

-- Lookup sets, so code can check direction without scanning the lists.
-- A name listed twice would make two instances with one name: the client would wait on the first, the server would hook the last.
local serverToClient: { [string]: true } = {}
for _, name in Remotes.ServerToClient do
	assert(not serverToClient[name], `Remote {name} is listed twice`)
	serverToClient[name] = true
end
local clientToServer: { [string]: true } = {}
for _, name in Remotes.ClientToServer do
	assert(not serverToClient[name], `Remote {name} is listed in both directions`)
	assert(not clientToServer[name], `Remote {name} is listed twice`)
	clientToServer[name] = true
end
local clientFunctions: { [string]: true } = {}
for _, name in Remotes.ClientToServerFunctions do
	assert(
		not serverToClient[name] and not clientToServer[name] and not clientFunctions[name],
		`Remote {name} is listed twice`
	)
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
