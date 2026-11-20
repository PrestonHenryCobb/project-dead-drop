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
local Effects = require(script.Parent.Parent.Combat.Effects)
local KitRules = require(script.Parent.Parent.Combat.KitRules)
local Lockout = require(script.Parent.Parent.Combat.Lockout)
local AssetService = require(script.Parent.AssetService)
local CombatService = require(script.Parent.CombatService)
local CoverService = require(script.Parent.CoverService)
local DownedService = require(script.Parent.DownedService)
local InteractService = require(script.Parent.InteractService)
local MatchService = require(script.Parent.MatchService)
local MetaProgressionService = require(script.Parent.MetaProgressionService)
local ReachService = require(script.Parent.ReachService)
local RemoteService = require(script.Parent.RemoteService)
local RunService = game:GetService("RunService")

local AbilityService = {}

-- Every Talent, by Talent id (AgentDefs). The first of each agent came first (steps 16a to 16f); the other twelve are ticket kits-24.
local modules = script.Parent.Parent.Abilities
local abilities: { [string]: Ability.Ability } = {
	QuickChange = require(modules.Guise),
	FaceValue = require(modules.FaceValue),
	ColdRead = require(modules.ColdRead),
	RiotWall = require(modules.Parapet),
	Brace = require(modules.Brace),
	PlateSlam = require(modules.PlateSlam),
	SparrowDrone = require(modules.Lattice),
	Overclock = require(modules.Overclock),
	SignalJam = require(modules.SignalJam),
	TracerGlass = require(modules.Reticle),
	Focus = require(modules.Focus),
	MarkedMan = require(modules.MarkedMan),
	MendField = require(modules.Suture),
	Adrenaline = require(modules.Adrenaline),
	Screen = require(modules.Screen),
	Double = require(modules.Feint),
	Lure = require(modules.Lure),
	TwinDouble = require(modules.TwinDouble),
}

local readyAt: { [Player]: number } = {} -- os.clock() when the ability can next be used

function AbilityService.agentOf(player: Player): Types.AgentId?
	local loadout = MetaProgressionService.getLoadout(player)
	return if loadout then loadout.AgentId else nil
end

local NO_RULES: { [string]: any } = {}

-- The kit item the player selected (their loadout's TalentId or InstinctId), or the agent's first of that kind.
local function selected(list: { Types.AgentKitItem }, id: string?): Types.AgentKitItem?
	if id then
		for _, item in list do
			if item.Id == id then
				return item
			end
		end
	end
	return list[1]
end

function AbilityService.instinctOf(player: Player): string?
	local loadout = MetaProgressionService.getLoadout(player)
	if not loadout then
		return nil
	end
	local def = AgentDefs.get(loadout.AgentId)
	local item = if def then selected(def.Instincts, loadout.InstinctId) else nil
	return if item then item.Id else nil
end

-- The GameConfig.Instincts numbers of the player's selected Instinct (empty for none).
function AbilityService.rulesOf(player: Player): { [string]: any }
	local id = AbilityService.instinctOf(player)
	return if id then (GameConfig.Instincts :: { [string]: any })[id] or NO_RULES else NO_RULES
end

local function talentOf(player: Player): (Types.AgentKitItem?, Ability.Ability?)
	local loadout = MetaProgressionService.getLoadout(player)
	if not loadout then
		return nil, nil
	end
	local def = AgentDefs.get(loadout.AgentId)
	local talent = if def then selected(def.Talents, loadout.TalentId) else nil
	return talent, if talent then abilities[talent.Id] else nil
end

-- The talent's cooldown for this player: Cheap Tricks (an Instinct) shortens it.
local function cooldownOf(player: Player, talent: Types.AgentKitItem): number
	return (talent.CooldownSeconds or 0) * (AbilityService.rulesOf(player).CooldownMult or 1)
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
	-- Spec 27 #13: nothing is used during Insertion (everyone is frozen behind the briefing).
	if
		not MatchService.isInMatch()
		or MatchService.phase() == "Insertion"
		or DownedService.isOut(player)
		or Lockout.isLocked(player)
	then
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
	local seconds = cooldownOf(player, talent)
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
		sendCooldown(player, talent.Name, cooldownOf(player, talent), 0)
	end
end

-- Ticket 18d: a rescued agent's ability comes back on a cooldown of `fraction` of its length.
function AbilityService.setCooldownFraction(player: Player, fraction: number)
	local talent = talentOf(player)
	if talent then
		local full = cooldownOf(player, talent)
		local seconds = full * fraction
		readyAt[player] = os.clock() + seconds
		sendCooldown(player, talent.Name, full, seconds)
	end
end

-- A new match: every ability is ready, and each player is told what theirs is.
local function resetAll()
	table.clear(readyAt)
	Effects.clearAll()
	for _, player in Players:GetPlayers() do
		local talent = talentOf(player)
		if talent then
			sendCooldown(player, talent.Name, cooldownOf(player, talent), 0)
		end
	end
end

function AbilityService.Init() end

function AbilityService.Start()
	for _, ability in abilities do
		if ability.start then
			ability.start(AbilityService.agentOf, AbilityService.instinctOf)
		end
	end
	KitRules.set(AbilityService.rulesOf)
	InteractService.setSecondsMult(function(player, kind, label)
		local rules = AbilityService.rulesOf(player)
		local mult = if rules.HackKinds and rules.HackKinds[kind] then rules.HackMult else 1 -- Lattice's Wired
		if GameConfig.Instincts.Wired.HackKinds[kind] then
			mult *= Effects.get(player, "HackTime", 1) -- Lattice's Overclock
		end
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
		Effects.clear(player)
	end)
	-- Self-Care (an Instinct): health comes back once the player has been out of combat for a while.
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		local interval = 1 / GameConfig.Instincts.SelfCare.SelfRegen.TickHz
		if elapsed < interval then
			return
		end
		elapsed = 0
		if not MatchService.isInMatch() then
			return
		end
		for _, player in Players:GetPlayers() do
			local regen = AbilityService.rulesOf(player).SelfRegen
			if regen and CombatService.secondsSinceDamaged(player) >= regen.OutOfCombatSeconds then
				CombatService.heal(player, regen.PerSecond * interval)
			end
		end
	end)
end

return AbilityService
