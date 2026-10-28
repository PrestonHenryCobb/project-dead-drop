--!strict
-- Ticket 16: agent abilities (spec 15, key Q). The client asks (RequestAbility); the server checks that the player is alive
-- and in a match, that the cooldown has run out, and then lets the agent's ability decide whether it can be used right now
-- (src/server/Abilities). A used ability starts its cooldown (AgentDefs Talent.CooldownSeconds), sent to the owner only
-- as CooldownUpdate; cooldowns reset when a match begins.
--
--   AbilityService.agentOf(player) -> AgentId?    the agent the player picked for this match

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AgentDefs = require(Shared:WaitForChild("Defs"):WaitForChild("AgentDefs"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Types = require(Shared:WaitForChild("Types"))
local Ability = require(script.Parent.Parent.Abilities.Ability)
local AssetService = require(script.Parent.AssetService)
local CombatService = require(script.Parent.CombatService)
local CoverService = require(script.Parent.CoverService)
local DisguiseService = require(script.Parent.DisguiseService)
local DownedService = require(script.Parent.DownedService)
local InteractService = require(script.Parent.InteractService)
local MatchService = require(script.Parent.MatchService)
local MetaProgressionService = require(script.Parent.MetaProgressionService)
local ReachService = require(script.Parent.ReachService)
local RemoteService = require(script.Parent.RemoteService)

local AbilityService = {}

-- Agents with an ability built so far (an agent is added here as its step lands).
local abilities: { [string]: Ability.Ability } = {
	Guise = require(script.Parent.Parent.Abilities.Guise),
	Parapet = require(script.Parent.Parent.Abilities.Parapet),
	Lattice = require(script.Parent.Parent.Abilities.Lattice),
	Reticle = require(script.Parent.Parent.Abilities.Reticle),
	Suture = require(script.Parent.Parent.Abilities.Suture),
	Feint = require(script.Parent.Parent.Abilities.Feint),
}

local readyAt: { [Player]: number } = {} -- os.clock() when the ability can next be used

function AbilityService.agentOf(player: Player): Types.AgentId?
	local loadout = MetaProgressionService.getLoadout(player)
	return if loadout then loadout.AgentId else nil
end

local NO_RULES: { [string]: any } = {}

-- The GameConfig.Agents numbers of the player's agent (empty for an agent with none).
function AbilityService.rulesOf(player: Player): { [string]: any }
	local agentId = AbilityService.agentOf(player)
	return if agentId then (GameConfig.Agents :: { [string]: any })[agentId] or NO_RULES else NO_RULES
end

local function talentOf(player: Player): (Types.AgentKitItem?, Ability.Ability?)
	local agentId = AbilityService.agentOf(player)
	local def = if agentId then AgentDefs.get(agentId) else nil
	return def and def.Talents[1], if agentId then abilities[agentId] else nil
end

local function sendCooldown(player: Player, name: string, seconds: number, remaining: number)
	local info: Types.AbilityCooldownInfo = {
		Name = name,
		Seconds = seconds,
		ReadyAt = workspace:GetServerTimeNow() + remaining,
	}
	RemoteService.fireClient("CooldownUpdate", player, info)
end

local function onRequestAbility(player: Player)
	if not MatchService.isInMatch() or DownedService.isOut(player) then
		return
	end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local talent, ability = talentOf(player)
	local now = os.clock()
	if not (humanoid and humanoid.Health > 0 and talent and ability) or now < (readyAt[player] or 0) then
		return
	end
	local used, reason = ability.activate(player)
	if not used then
		if reason then
			RemoteService.fireClient("Notification", player, reason)
		end
		return
	end
	local seconds = talent.CooldownSeconds or 0
	readyAt[player] = now + seconds
	sendCooldown(player, talent.Name, seconds, seconds)
end

-- Ticket 18c (Supply Cache): is the player's ability still cooling down?
function AbilityService.onCooldown(player: Player): boolean
	return os.clock() < (readyAt[player] or 0)
end

-- Ready at once; the player is told.
function AbilityService.resetCooldown(player: Player)
	local talent = talentOf(player)
	if talent and AbilityService.onCooldown(player) then
		readyAt[player] = nil
		sendCooldown(player, talent.Name, talent.CooldownSeconds or 0, 0)
	end
end

-- Ticket 18d: a rescued agent's ability comes back on a cooldown of `fraction` of its length.
function AbilityService.setCooldownFraction(player: Player, fraction: number)
	local talent = talentOf(player)
	if talent then
		local seconds = (talent.CooldownSeconds or 0) * fraction
		readyAt[player] = os.clock() + seconds
		sendCooldown(player, talent.Name, talent.CooldownSeconds or 0, seconds)
	end
end

-- A new match: every ability is ready, and each player is told what theirs is.
local function resetAll()
	table.clear(readyAt)
	for _, player in Players:GetPlayers() do
		local talent = talentOf(player)
		if talent then
			sendCooldown(player, talent.Name, talent.CooldownSeconds or 0, 0)
		end
	end
end

function AbilityService.Init() end

function AbilityService.Start()
	for _, ability in abilities do
		if ability.start then
			ability.start(AbilityService.agentOf)
		end
	end
	DisguiseService.setAgentLookup(AbilityService.agentOf)
	InteractService.setSecondsMult(function(player, kind, label)
		local rules = AbilityService.rulesOf(player)
		local mult = if rules.HackKinds and rules.HackKinds[kind] then rules.HackMult else 1 -- Lattice's Wired
		if label == "Revive" and rules.ReviveMult then
			mult *= rules.ReviveMult -- Suture's Triage
		end
		if GameConfig.Assets.QuickHandsKinds[kind] then
			mult /= 1 + AssetService.value(player, "QuickHands") -- the Quick Hands Asset
		end
		if GameConfig.Assets.FieldMedicKinds[kind] then
			mult /= 1 + AssetService.value(player, "FieldMedic") -- the Field Medic Asset: a quicker Health Station
		end
		if ReachService.lensActive(player) then
			mult *= GameConfig.Gadgets.LongLens.TimeMult -- the Long Lens hacks from afar, more slowly
		end
		return mult
	end)
	CombatService.setAgentRules(AbilityService.rulesOf)
	CoverService.setAgentRules(AbilityService.rulesOf)
	RemoteService.onRequest("RequestAbility", onRequestAbility)
	MatchService.onPhaseChanged(function(phase)
		if phase == "Insertion" then
			resetAll()
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		readyAt[player] = nil
	end)
end

return AbilityService
