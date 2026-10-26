--!strict
-- Ticket menu-services: each player's meta profile (agents owned, mastery, currencies, career) and equipped loadout,
-- and the menu requests that change them. The client asks; every request is checked here.
--
-- Profiles live in memory for the session. Saving them (session-locked DataStore) is Step 21; until then every join
-- starts from a fresh profile: no agents owned and one free pick open per class (SPEC_CHANGES 15.9/20).
--
--   MetaProgressionService.snapshot(player) -> Types.MetaSnapshot?
--   MetaProgressionService.getLoadout(player) -> Types.PlayerLoadout?
--   MetaProgressionService.validateLoadout(player, request) -> (Types.PlayerLoadout?, reason?)
--   MetaProgressionService.setLoadout(player, loadout)   equips a loadout validateLoadout returned, and tells the player
--   MetaProgressionService.ownedAgents(player) -> { AgentId } in menu order
--   MetaProgressionService.queueInfo() -> Types.QueueInfo     the modes this server can deploy into

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AgentDefs = require(Shared:WaitForChild("Defs"):WaitForChild("AgentDefs"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Types = require(Shared:WaitForChild("Types"))
local WeaponDefs = require(Shared:WaitForChild("Defs"):WaitForChild("WeaponDefs"))
local RemoteService = require(script.Parent.RemoteService)
local TeamService = require(script.Parent.TeamService)

type MetaProfile = Types.MetaProfile
type PlayerLoadout = Types.PlayerLoadout

local MetaProgressionService = {}

local profiles: { [Player]: MetaProfile } = {}
local loadouts: { [Player]: PlayerLoadout } = {}

local function startingMastery(): number
	return if RunService:IsStudio() then GameConfig.Debug.StudioMasteryLevel else 1
end

local function newProfile(): MetaProfile
	local picks: { [string]: boolean } = {}
	for _, agentId in AgentDefs.order do
		picks[AgentDefs.byId[agentId].Class] = true
	end
	return {
		Level = 1,
		Credits = 0,
		Stocks = 0,
		OwnedAgents = {},
		StarterPicksLeft = picks,
		Mastery = {},
		OwnedCosmetics = {},
		ActiveDossierId = nil,
		Dossiers = {},
		Career = {
			Matches = 0,
			Extractions = 0,
			IntelGathered = 0,
			Eliminations = 0,
			Takedowns = 0,
			MatchesUncompromised = 0,
		},
	}
end

local function masteryLevel(profile: MetaProfile, agentId: string): number
	local mastery = profile.Mastery[agentId]
	return if mastery then mastery.Level else 0
end

-- The modes this server can deploy into. One server plays one mode until matchmaking (Step 22).
function MetaProgressionService.queueInfo(): Types.QueueInfo
	local mode = TeamService.mode()
	local available: { Types.QueueMode } = {}
	if mode == "Solos" or mode == "Duos" then
		table.insert(available, mode :: Types.QueueMode)
	end
	return { Mode = available[1] or "Duos", Available = available }
end

function MetaProgressionService.snapshot(player: Player): Types.MetaSnapshot?
	local profile = profiles[player]
	if not profile then
		return nil
	end
	return { Profile = profile, Loadout = loadouts[player], Queue = MetaProgressionService.queueInfo() }
end

local function push(player: Player)
	local snapshot = MetaProgressionService.snapshot(player)
	if snapshot then
		RemoteService.fireClient("ProfileStateUpdated", player, snapshot)
	end
end

function MetaProgressionService.getLoadout(player: Player): PlayerLoadout?
	return loadouts[player]
end

function MetaProgressionService.ownedAgents(player: Player): { Types.AgentId }
	local profile = profiles[player]
	local owned: { Types.AgentId } = {}
	if profile then
		for _, agentId in AgentDefs.order do
			if profile.OwnedAgents[agentId] then
				table.insert(owned, agentId)
			end
		end
	end
	return owned
end

-- Checks a loadout request from a client: shape, an owned agent, one of that agent's built Hardware, and mastery high
-- enough for its slot. Returns a clean loadout (never the client's table) or the reason it was refused.
function MetaProgressionService.validateLoadout(player: Player, request: unknown): (PlayerLoadout?, string?)
	local profile = profiles[player]
	if not profile then
		return nil, "NoProfile"
	end
	if type(request) ~= "table" then
		return nil, "BadRequest"
	end
	local agentId = (request :: any).AgentId
	local hardwareId = (request :: any).HardwareId
	if type(agentId) ~= "string" or type(hardwareId) ~= "string" then
		return nil, "BadRequest"
	end
	local agent = AgentDefs.get(agentId)
	if not agent then
		return nil, "UnknownAgent"
	end
	if not profile.OwnedAgents[agent.Id] then
		return nil, "AgentLocked"
	end
	if not WeaponDefs.isValidForAgent(agent.Id, hardwareId) then
		return nil, "HardwareUnavailable"
	end
	for _, item in WeaponDefs.getForAgent(agent.Id) do
		if item.Id == hardwareId and masteryLevel(profile, agent.Id) < item.UnlockMasteryLevel then
			return nil, "MasteryTooLow"
		end
	end
	return { AgentId = agent.Id, HardwareId = hardwareId }, nil
end

function MetaProgressionService.setLoadout(player: Player, loadout: PlayerLoadout)
	if not profiles[player] then
		return
	end
	loadouts[player] = table.freeze(table.clone(loadout))
	push(player)
end

local function onEquip(player: Player, request: unknown): (boolean, string?)
	local loadout, reason = MetaProgressionService.validateLoadout(player, request)
	if not loadout then
		return false, reason
	end
	MetaProgressionService.setLoadout(player, loadout)
	return true, nil
end

-- First launch: one free agent from each class. The first agent claimed also becomes the equipped loadout, with its W1.
local function onClaimStarter(player: Player, agentId: unknown): (boolean, string?)
	local profile = profiles[player]
	if not profile then
		return false, "NoProfile"
	end
	local agent = if type(agentId) == "string" then AgentDefs.get(agentId) else nil
	if not agent then
		return false, "UnknownAgent"
	end
	if profile.OwnedAgents[agent.Id] then
		return false, "AlreadyOwned"
	end
	if not profile.StarterPicksLeft[agent.Class] then
		return false, "NoFreePick"
	end
	profile.StarterPicksLeft[agent.Class] = nil
	profile.OwnedAgents[agent.Id] = true
	profile.Mastery[agent.Id] = { Level = startingMastery(), XP = 0 }
	if not loadouts[player] then
		local first = WeaponDefs.getForAgent(agent.Id)[1]
		loadouts[player] = table.freeze({ AgentId = agent.Id, HardwareId = first.Id })
	end
	push(player)
	return true, nil
end

-- SPEC-QUESTION: Dossiers, Black Market offers and Stocks packages have no designed content yet (names, tiers, rewards,
-- prices), so these requests are refused rather than answered from invented data. Each gets its rules once its
-- catalogue is decided (Step 21).
local NO_CATALOGUE = {
	"RequestClaimDossierTier",
	"RequestSelectActiveDossier",
	"RequestBlackMarketPurchase",
	"RequestMintStrikeStocks",
}

function MetaProgressionService.Init() end

function MetaProgressionService.Start()
	RemoteService.onInvoke("GetPlayerMetaProfile", function(player: Player)
		return MetaProgressionService.snapshot(player)
	end)
	RemoteService.onInvoke("RequestEquipLoadout", onEquip)
	RemoteService.onInvoke("RequestClaimStarterAgent", onClaimStarter)
	for _, name in NO_CATALOGUE do
		RemoteService.onInvoke(name, function()
			return false, "NoCatalogue"
		end)
	end

	local function add(player: Player)
		profiles[player] = newProfile()
	end
	Players.PlayerAdded:Connect(add)
	for _, player in Players:GetPlayers() do
		add(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		profiles[player] = nil
		loadouts[player] = nil
	end)
end

return MetaProgressionService
