--!strict
-- Ticket menu-services: each player's meta profile (agents owned, mastery, currencies, career) and equipped loadout,
-- and the menu requests that change them. The client asks; every request is checked here.
--
-- A profile is loaded from the session-locked DataStore when a player joins (Data/ProfileStore, ticket 21-data), kept in
-- memory while they play, and saved every GameConfig.Data.AutosaveSeconds, on leave and when the server closes. A new
-- player starts fresh: no agents owned and one free pick open per class (SPEC_CHANGES 15.9/20). Where the DataStore cannot
-- be reached (Studio without API access) the profile lives for the session only.
--
--   MetaProgressionService.snapshot(player) -> Types.MetaSnapshot?
--   MetaProgressionService.getLoadout(player) -> Types.PlayerLoadout?
--   MetaProgressionService.validateLoadout(player, request) -> (Types.PlayerLoadout?, reason?)
--   MetaProgressionService.setLoadout(player, loadout)   equips a loadout validateLoadout returned, and tells the player
--   MetaProgressionService.ownedAgents(player) -> { AgentId } in menu order
--   MetaProgressionService.settleAccount(player, xp, won) -> Types.MatchRewardsInfo?   account XP, levels and Credits (RewardService)
--   MetaProgressionService.recordMatch(player, won, extracted)   a finished match: mastery XP for the agent played (a team win adds
--     the bonus), career counters (Extractions only if this player was still in at the end)
--   MetaProgressionService.transact(player, fn(profile) -> (ok, reason?)) -> (ok, reason?)   a validated profile change from the shop; saved and pushed on ok
--   MetaProgressionService.queueInfo() -> Types.QueueInfo     the modes this server can deploy into

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AgentDefs = require(Shared:WaitForChild("Defs"):WaitForChild("AgentDefs"))
local AssetDefs = require(Shared:WaitForChild("Defs"):WaitForChild("AssetDefs"))
local GadgetDefs = require(Shared:WaitForChild("Defs"):WaitForChild("GadgetDefs"))
local ShopDefs = require(Shared:WaitForChild("Defs"):WaitForChild("ShopDefs"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Types = require(Shared:WaitForChild("Types"))
local WeaponDefs = require(Shared:WaitForChild("Defs"):WaitForChild("WeaponDefs"))
local ProfileStore = require(script.Parent.Parent.Data.ProfileStore)
local RemoteService = require(script.Parent.RemoteService)
local TeamService = require(script.Parent.TeamService)

type MetaProfile = Types.MetaProfile
type PlayerLoadout = Types.PlayerLoadout

local MetaProgressionService = {}

local profiles: { [Player]: MetaProfile } = {}
local loadouts: { [Player]: PlayerLoadout } = {}
local persistent: { [Player]: boolean } = {} -- this server holds the player's lock and saves their profile
local dirty: { [Player]: boolean } = {}
local saving: { [Player]: boolean } = {}
local releasing: { [number]: boolean } = {} -- a UserId whose release save is still running: a quick rejoin waits for it

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
		XP = 0,
		LastWinDay = 0,
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

local dataConfig = GameConfig.Data

local function bounded(value: any, default: number, max: number): number
	if type(value) ~= "number" or value ~= value then
		return default
	end
	return math.floor(math.clamp(value, 0, max))
end

local function knownClasses(): { [string]: boolean }
	local classes: { [string]: boolean } = {}
	for _, agent in AgentDefs.byId do
		classes[agent.Class] = true
	end
	return classes
end

-- Turns whatever was saved into a valid profile: unknown agents, classes and malformed entries are dropped, numbers are
-- bounded, and anything missing takes its starting value. The saved table is never returned or mutated.
local function reconcile(saved: any): MetaProfile
	local profile = newProfile()
	if type(saved) ~= "table" then
		return profile
	end
	profile.Level = math.max(1, bounded(saved.Level, 1, dataConfig.MaxStat))
	profile.XP = bounded(saved.XP, 0, dataConfig.MaxStat)
	profile.LastWinDay = bounded(saved.LastWinDay, 0, dataConfig.MaxStat)
	profile.Credits = bounded(saved.Credits, 0, dataConfig.MaxCredits)
	profile.Stocks = bounded(saved.Stocks, 0, dataConfig.MaxCredits)
	if type(saved.OwnedAgents) == "table" then
		for agentId, owned in saved.OwnedAgents do
			if owned == true and type(agentId) == "string" and AgentDefs.get(agentId) then
				profile.OwnedAgents[agentId] = true
			end
		end
	end
	if type(saved.StarterPicksLeft) == "table" then
		local classes = knownClasses()
		local picks: { [string]: boolean } = {}
		for class, left in saved.StarterPicksLeft do
			if left == true and type(class) == "string" and classes[class] then
				picks[class] = true
			end
		end
		profile.StarterPicksLeft = picks
	end
	if type(saved.Mastery) == "table" then
		for agentId, mastery in saved.Mastery do
			if type(agentId) == "string" and AgentDefs.get(agentId) and type(mastery) == "table" then
				profile.Mastery[agentId] = {
					Level = bounded(mastery.Level, 0, GameConfig.Mastery.MaxLevel),
					XP = bounded(mastery.XP, 0, dataConfig.MaxStat),
				}
			end
		end
	end
	for agentId in profile.OwnedAgents do
		if not profile.Mastery[agentId] then
			profile.Mastery[agentId] = { Level = startingMastery(), XP = 0 }
		end
	end
	if type(saved.OwnedCosmetics) == "table" then
		for cosmeticId, owned in saved.OwnedCosmetics do
			if owned == true and type(cosmeticId) == "string" and ShopDefs.byId[cosmeticId] then
				profile.OwnedCosmetics[cosmeticId] = true
			end
		end
	end
	if type(saved.Dossiers) == "table" then
		for dossierId, progress in saved.Dossiers do
			if type(dossierId) == "string" and type(progress) == "table" then
				local claimed: { number } = {}
				if type(progress.Claimed) == "table" then
					for _, tier in progress.Claimed do
						if type(tier) == "number" and tier == tier and tier >= 1 then
							table.insert(claimed, math.floor(tier))
						end
					end
				end
				profile.Dossiers[dossierId] = {
					XP = bounded(progress.XP, 0, dataConfig.MaxStat),
					Premium = progress.Premium == true,
					Claimed = claimed,
				}
			end
		end
	end
	if type(saved.ActiveDossierId) == "string" and profile.Dossiers[saved.ActiveDossierId] then
		profile.ActiveDossierId = saved.ActiveDossierId
	end
	if type(saved.Career) == "table" then
		local career: { [string]: number } = profile.Career :: any
		for stat in career do
			career[stat] = bounded(saved.Career[stat], 0, dataConfig.MaxStat)
		end
	end
	return profile
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
	-- Ticket 17: the gadgets, if the request names any: at most Gadgets.Slots built gadgets, none twice.
	local gadgetIds: { string }? = nil
	local requested = (request :: any).GadgetIds
	if requested ~= nil then
		if type(requested) ~= "table" or #requested > GameConfig.Gadgets.Slots then
			return nil, "BadRequest"
		end
		local picked: { string } = {}
		local seen: { [string]: boolean } = {}
		for _, id in requested do
			if type(id) ~= "string" or not GadgetDefs.get(id) or seen[id] then
				return nil, "GadgetUnavailable"
			end
			seen[id] = true
			table.insert(picked, id)
		end
		gadgetIds = picked
	end
	-- Ticket 18e: the Asset loadout, if the request names one: four different Assets, one for each rarity slot in order.
	local assetIds: { string }? = nil
	local requestedAssets = (request :: any).AssetIds
	if requestedAssets ~= nil then
		if type(requestedAssets) ~= "table" or #requestedAssets ~= #AssetDefs.rarities then
			return nil, "BadRequest"
		end
		local pickedAssets: { string } = {}
		local seenAssets: { [string]: boolean } = {}
		for _, id in requestedAssets do
			if type(id) ~= "string" or not AssetDefs.get(id) or seenAssets[id] then
				return nil, "AssetUnavailable"
			end
			seenAssets[id] = true
			table.insert(pickedAssets, id)
		end
		assetIds = pickedAssets
	end
	-- Ticket kits-24: the Talent and Instinct, if the request names them: one of the agent's own, with mastery high enough for its slot.
	-- Left out, the agent's first of each (always unlocked) is taken.
	local talentId: string = agent.Talents[1].Id
	local requestedTalent = (request :: any).TalentId
	if requestedTalent ~= nil then
		local slot = if type(requestedTalent) == "string" then AgentDefs.talentSlot(agent.Id, requestedTalent) else nil
		if not slot then
			return nil, "TalentUnavailable"
		end
		if masteryLevel(profile, agent.Id) < GameConfig.Mastery.TalentUnlockLevels[slot] then
			return nil, "MasteryTooLow"
		end
		talentId = requestedTalent
	end
	local instinctId: string = agent.Instincts[1].Id
	local requestedInstinct = (request :: any).InstinctId
	if requestedInstinct ~= nil then
		local slot = if type(requestedInstinct) == "string"
			then AgentDefs.instinctSlot(agent.Id, requestedInstinct)
			else nil
		if not slot then
			return nil, "InstinctUnavailable"
		end
		if masteryLevel(profile, agent.Id) < GameConfig.Mastery.InstinctUnlockLevels[slot] then
			return nil, "MasteryTooLow"
		end
		instinctId = requestedInstinct
	end
	return {
		AgentId = agent.Id,
		HardwareId = hardwareId,
		GadgetIds = gadgetIds,
		AssetIds = assetIds,
		TalentId = talentId,
		InstinctId = instinctId,
	},
		nil
end

function MetaProgressionService.setLoadout(player: Player, loadout: PlayerLoadout)
	if not profiles[player] then
		return
	end
	loadouts[player] = table.freeze(table.clone(loadout))
	dirty[player] = true
	push(player)
end

-- Ticket 21-mastery: a match the player finished (MatchService.finish). The agent they played gains mastery XP and levels,
-- and the career counters move. The loadout is the one they deployed with; nothing happens without a profile or a loadout.
function MetaProgressionService.recordMatch(player: Player, won: boolean, extracted: boolean)
	local profile = profiles[player]
	local loadout = loadouts[player]
	if not profile or not loadout then
		return
	end
	local masteryConfig = GameConfig.Mastery
	local mastery = profile.Mastery[loadout.AgentId] or { Level = 1, XP = 0 }
	local xp = mastery.XP + masteryConfig.MatchXP + (if won then masteryConfig.WinBonusXP else 0)
	local level = mastery.Level
	while level < masteryConfig.MaxLevel and xp >= masteryConfig.XPPerLevel do
		xp -= masteryConfig.XPPerLevel
		level += 1
	end
	if level >= masteryConfig.MaxLevel then
		xp = 0
	end
	profile.Mastery[loadout.AgentId] = { Level = level, XP = xp }
	profile.Career.Matches += 1
	if extracted then
		profile.Career.Extractions += 1
	end
	dirty[player] = true
	push(player)
end

-- Ticket 21-rewards (spec 20.2, 20.3): XP to go from this level to the next.
local function xpForLevel(level: number): number
	local rewards = GameConfig.Rewards
	return math.min(rewards.LevelBase + rewards.LevelStep * level, rewards.LevelCap)
end

-- Adds a finished match's XP to the account: level-ups pay Credits, and a win pays the win bonus and, once a UTC day, the daily
-- first-win bonus. Returns what the player gets to see (RewardService fills in the XP lines), or nil without a profile.
function MetaProgressionService.settleAccount(player: Player, xp: number, won: boolean): Types.MatchRewardsInfo?
	local profile = profiles[player]
	if not profile then
		return nil
	end
	local rewards = GameConfig.Rewards
	local before = profile.Level
	profile.XP += xp
	while profile.XP >= xpForLevel(profile.Level) do
		profile.XP -= xpForLevel(profile.Level)
		profile.Level += 1
	end
	local levelCredits = (profile.Level - before) * rewards.CreditsPerLevel
	local winCredits, dailyCredits = 0, 0
	if won then
		winCredits = rewards.WinCredits
		local day = math.floor(os.time() / rewards.SecondsPerDay)
		if profile.LastWinDay ~= day then
			profile.LastWinDay = day
			dailyCredits = rewards.DailyFirstWinCredits
		end
	end
	profile.Credits = math.min(profile.Credits + levelCredits + winCredits + dailyCredits, dataConfig.MaxCredits)
	dirty[player] = true
	push(player)
	return {
		Lines = {},
		TotalXp = xp,
		LevelBefore = before,
		LevelAfter = profile.Level,
		XpIntoLevel = profile.XP,
		XpForLevel = xpForLevel(profile.Level),
		LevelCredits = levelCredits,
		WinCredits = winCredits,
		DailyCredits = dailyCredits,
	}
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
	dirty[player] = true
	push(player)
	return true, nil
end

-- Buying a locked agent with Credits (ticket shop-skeleton, GameConfig.Shop.AgentCredits). The free first-launch pick of the agent's
-- class must be used first, since it costs nothing. The new agent starts at mastery level 1 with its first Hardware free.
local function onBuyAgent(player: Player, agentId: unknown): (boolean, string?)
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
	if profile.StarterPicksLeft[agent.Class] then
		return false, "UseFreePick" -- the free pick for this class is still open
	end
	local price = GameConfig.Shop.AgentCredits
	if profile.Credits < price then
		return false, "NotEnoughCredits"
	end
	profile.Credits -= price
	profile.OwnedAgents[agent.Id] = true
	profile.Mastery[agent.Id] = { Level = startingMastery(), XP = 0 }
	dirty[player] = true
	push(player)
	return true, nil
end

-- Runs a change to the player's profile that another service has already validated (a Black Market purchase, a Mint grant): fn
-- edits the profile and answers (ok, reason). On ok the profile is saved at the next autosave and the player is told.
function MetaProgressionService.transact(
	player: Player,
	fn: (Types.MetaProfile) -> (boolean, string?)
): (boolean, string?)
	local profile = profiles[player]
	if not profile then
		return false, "NoProfile"
	end
	local ok, reason = fn(profile)
	if ok then
		dirty[player] = true
		push(player)
	end
	return ok, reason
end

-- SPEC-QUESTION: Dossiers have no designed content yet (names, tiers, rewards), so these requests are refused rather than
-- answered from invented data. (The Black Market and the Mint are StorefrontService.)
local NO_CATALOGUE = {
	"RequestClaimDossierTier",
	"RequestSelectActiveDossier",
}

-- Persistence (ticket 21-data) -------------------------------------------------------------------------------------

local function savedShape(player: Player): { [string]: any }
	return { Profile = profiles[player], Loadout = loadouts[player] }
end

-- Writes the profile (and, with release, lets go of the lock). One save per player at a time.
local function saveProfile(player: Player, release: boolean): boolean
	if not persistent[player] then
		return false
	end
	while saving[player] do
		task.wait(0.1)
	end
	if not persistent[player] then
		return false
	end
	saving[player] = true
	dirty[player] = false
	local ok = ProfileStore.save(player.UserId, savedShape(player), release)
	saving[player] = nil
	if not ok then
		dirty[player] = true -- try again at the next autosave
	elseif release then
		persistent[player] = nil -- the lock is gone; nothing may save this profile again (a second release would race a new server)
	end
	return ok
end

local function loadProfile(player: Player)
	while releasing[player.UserId] do
		task.wait(dataConfig.ReleaseWaitSeconds) -- they just left this server and the save that lets go of the lock is still running
	end
	local status, saved = ProfileStore.load(player.UserId)
	if not player.Parent then
		if status == "Loaded" then
			ProfileStore.save(player.UserId, saved, true) -- they left while it loaded: hand the lock back, data untouched
		end
		return
	end
	if status == "Locked" or (status == "Unavailable" and not ProfileStore.isOff()) then
		if RunService:IsStudio() then
			-- A force-stopped test leaves its lock behind; a Studio session just plays unsaved rather than being kicked.
			warn(`[MetaProgression] {player.Name}: profile {status}; this Studio session will not save`)
			status, saved = "Unavailable", nil
		else
			player:Kick(
				if status == "Locked"
					then "Your profile is open on another server. Please try again in a moment."
					else "Your profile could not be loaded. Please rejoin in a moment."
			)
			return
		end
	end
	local profile = reconcile(if saved then saved.Profile else nil)
	profiles[player] = profile
	if saved then
		local loadout = MetaProgressionService.validateLoadout(player, saved.Loadout)
		if loadout then
			loadouts[player] = table.freeze(table.clone(loadout))
		end
	end
	persistent[player] = status == "Loaded"
	dirty[player] = false
	push(player)
end

local function autosave()
	-- Every profile, dirty or not: the save also renews the session lock, which would otherwise go stale on an idle player.
	for player in persistent do
		if not saving[player] then
			task.spawn(saveProfile, player, false)
		end
	end
end

function MetaProgressionService.Init() end

function MetaProgressionService.Start()
	RemoteService.onInvoke("GetPlayerMetaProfile", function(player: Player)
		return MetaProgressionService.snapshot(player)
	end)
	RemoteService.onInvoke("RequestEquipLoadout", onEquip)
	RemoteService.onInvoke("RequestClaimStarterAgent", onClaimStarter)
	RemoteService.onInvoke("RequestBuyAgent", onBuyAgent)
	for _, name in NO_CATALOGUE do
		RemoteService.onInvoke(name, function()
			return false, "NoCatalogue"
		end)
	end

	Players.PlayerAdded:Connect(function(player)
		task.spawn(loadProfile, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(loadProfile, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		if persistent[player] then
			releasing[player.UserId] = true
			saveProfile(player, true)
			releasing[player.UserId] = nil
		end
		persistent[player] = nil
		dirty[player] = nil
		profiles[player] = nil
		loadouts[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(dataConfig.AutosaveSeconds)
			autosave()
		end
	end)
	-- The server closing: every player still here is saved and released before it goes (it waits for the saves).
	game:BindToClose(function()
		local pending = 0
		for player in persistent do
			pending += 1
			task.spawn(function()
				saveProfile(player, true)
				pending -= 1
			end)
		end
		while pending > 0 do
			task.wait(0.1)
		end
	end)
end

return MetaProgressionService
