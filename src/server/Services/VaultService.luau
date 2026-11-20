--!strict
-- Ticket 12a: the vault terminals and the Sanctum unlock (spec 10, SPEC_CHANGES 2026-10-25).
--
--   * At the start of a match Vault.ActiveVaults of the five vaults are chosen at random. Each gets a terminal on its dais
--     (the VaultTerminalSpot part); the other vaults stay empty. Nothing marks which vaults are active until the Vault Breach.
--   * Standing on a terminal's dais hacks it (spec 10.2, per terminal): Vault.BaseRate percent a second if one team is
--     there, however many agents; Vault.BonusMult times that if the team has Intel.Thresholds.HackBonusAt Intel; paused
--     (contested) while agents of two or more teams stand on it. Progress is global and never decays. An agent on the dais
--     is Exposed at once (spec 7.2 #8).
--   * The first progress on any terminal begins the Vault Breach if the 6:00 timer has not (MatchService), and from then
--     VaultProgress tells every client where the terminals are and how far along.
--   * When every active terminal is hacked the Sanctum elevator unlocks and the Package Heist begins.
--
-- SPEC-QUESTION: the re-layout replaced the Intel unlock but not the Phase 2 to 3 rule. Phase 3 here begins at the earlier
-- of the forced unlock (6:00) and the first hack, so a team that finds a terminal early shows its hand to everyone.
-- The gold Asset a hack awards (MAP_BRIEF_RELAYOUT) waits for the Assets system (Steps 18 and 21).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Types = require(Shared:WaitForChild("Types"))
local BotRegistry = require(script.Parent.Parent.Bots.BotRegistry)
local CoverService = require(script.Parent.CoverService)
local DownedService = require(script.Parent.DownedService)
local ElevatorService = require(script.Parent.ElevatorService)
local IntelService = require(script.Parent.IntelService)
local MatchService = require(script.Parent.MatchService)
local RemoteService = require(script.Parent.RemoteService)
local RewardService = require(script.Parent.RewardService)
local TeamService = require(script.Parent.TeamService)

type Terminal = {
	vaultId: string,
	dais: BasePart,
	radius: number,
	prop: BasePart?,
	progress: number, -- percent, 0 to 100
	contested: boolean,
	hacked: boolean,
}

local VaultService = {}

local config = GameConfig.Vault
local rng = Random.new()
local terminals: { Terminal } = {}
local folder: Folder? = nil
local dirty = false
local sinceBroadcast = 0
local sinceCheck = 0

local function active(): boolean
	local phase = MatchService.phase()
	return phase == "Infiltration" or phase == "VaultBreach"
end

local function broadcast()
	dirty = false
	sinceBroadcast = 0
	local list: { Types.VaultTerminalInfo } = {}
	for _, terminal in terminals do
		table.insert(list, {
			VaultId = terminal.vaultId,
			Position = terminal.dais.Position,
			Progress = terminal.progress / 100,
			Contested = terminal.contested,
			Hacked = terminal.hacked,
		})
	end
	RemoteService.fireAllClients("VaultProgress", { Terminals = list } :: Types.VaultProgressInfo)
end

local function clear()
	for _, terminal in terminals do
		if terminal.prop then
			terminal.prop:Destroy()
		end
	end
	table.clear(terminals)
	if folder then
		folder:Destroy()
		folder = nil
	end
	ElevatorService.setLocked(config.SanctumShaftId, true)
end

-- Picks the match's vaults and puts a terminal on each dais.
local function setup()
	clear()
	local daises: { BasePart } = {}
	for _, instance in CollectionService:GetTagged(Enums.Tag.VaultTerminalSpot) do
		if instance:IsA("BasePart") then
			table.insert(daises, instance)
		end
	end
	table.sort(daises, function(a, b)
		return tostring(a:GetAttribute("VaultId")) < tostring(b:GetAttribute("VaultId"))
	end)
	local holder = Instance.new("Folder")
	holder.Name = "VaultTerminals"
	holder.Parent = workspace
	folder = holder
	for _ = 1, math.min(config.ActiveVaults, #daises) do
		local dais = table.remove(daises, rng:NextInteger(1, #daises)) :: BasePart
		local prop = Instance.new("Part")
		prop.Name = "VaultTerminal"
		prop.Anchored = true
		prop.Size = config.TerminalSize
		prop.Color = config.TerminalColor
		prop.Material = Enum.Material.Neon
		prop.CFrame = CFrame.new(dais.Position + Vector3.new(0, dais.Size.X / 2 + config.TerminalSize.Y / 2, 0))
		prop.Parent = holder
		table.insert(terminals, {
			vaultId = tostring(dais:GetAttribute("VaultId")),
			dais = dais,
			radius = dais.Size.Z / 2, -- a cylinder lying on its side: its length is X, its diameter Y and Z
			prop = prop,
			progress = 0,
			contested = false,
			hacked = false,
		})
	end
	if GameConfig.Debug.PrintEvents then
		local names: { string } = {}
		for _, terminal in terminals do
			table.insert(names, terminal.vaultId)
		end
		print(`[Vault] active vaults: {table.concat(names, ", ")}`)
	end
end

-- The teams with a living agent on a terminal's dais, and those agents.
local function presence(terminal: Terminal): ({ [number]: boolean }, { Player })
	local teams: { [number]: boolean } = {}
	local present: { Player } = {}
	local center = terminal.dais.Position
	for _, player in Players:GetPlayers() do
		local teamId = TeamService.teamOf(player)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if teamId and root and root:IsA("BasePart") and not DownedService.isOut(player) then
			local offset = root.Position - center
			if
				Vector3.new(offset.X, 0, offset.Z).Magnitude <= terminal.radius
				and math.abs(offset.Y) <= config.TerminalHeightStuds
			then
				teams[teamId] = true
				table.insert(present, player)
			end
		end
	end
	-- Ticket 13B-a: a bot on its feet counts for its team like an agent does.
	for _, bot in BotRegistry.list() do
		if BotRegistry.alive(bot) then
			local offset = bot.npc.ground - center
			if
				Vector3.new(offset.X, 0, offset.Z).Magnitude <= terminal.radius
				and math.abs(offset.Y) <= config.TerminalHeightStuds
			then
				teams[bot.teamId] = true
			end
		end
	end
	return teams, present
end

local function allHacked(): boolean
	for _, terminal in terminals do
		if not terminal.hacked then
			return false
		end
	end
	return #terminals > 0
end

local function check(dt: number)
	for _, terminal in terminals do
		if not terminal.hacked then
			local teams, present = presence(terminal)
			RewardService.vaultPresence(present, dt)
			for _, player in present do
				if not CoverService.isExposed(player) then
					CoverService.expose(player, "Vault terminal") -- spec 7.2 #8
				end
			end
			local count = 0
			local lone = 0
			for teamId in teams do
				count += 1
				lone = teamId
			end
			local contested = count >= 2
			if contested ~= terminal.contested then
				terminal.contested = contested
				dirty = true
			end
			if count == 1 then
				local rate = config.BaseRate
				if IntelService.balance(lone) >= GameConfig.Intel.Thresholds.HackBonusAt then
					rate *= config.BonusMult
				end
				terminal.progress = math.min(100, terminal.progress + rate * dt)
				dirty = true
				if MatchService.phase() == "Infiltration" then
					MatchService.advance("VaultBreach") -- the first hack shows every team where the terminals are
				end
				if terminal.progress >= 100 then
					terminal.hacked = true
					if GameConfig.Debug.PrintEvents then
						print(`[Vault] terminal {terminal.vaultId} hacked by team {lone}`)
					end
				end
			end
		end
	end
	if allHacked() then
		ElevatorService.setLocked(config.SanctumShaftId, false)
		MatchService.advance("PackageHeist")
	end
end

-- Ticket 13B-a: where the terminals not yet hacked stand (floor level), for a bot to walk to.
function VaultService.openTerminals(): { Vector3 }
	local list: { Vector3 } = {}
	for _, terminal in terminals do
		if not terminal.hacked then
			table.insert(list, terminal.dais.Position)
		end
	end
	return list
end

function VaultService.Init() end

function VaultService.Start()
	MatchService.onPhaseChanged(function(phase)
		if phase == "Insertion" then
			setup()
		elseif phase == "VaultBreach" or phase == "PackageHeist" then
			broadcast() -- everyone learns where the terminals are
		elseif phase == "Lobby" then
			clear()
		end
	end)
	RunService.Heartbeat:Connect(function(dt)
		sinceCheck += dt
		sinceBroadcast += dt
		if sinceCheck >= 1 / config.CheckHz then
			local step = sinceCheck
			sinceCheck = 0
			if active() and #terminals > 0 then
				check(step)
			end
		end
		if dirty and sinceBroadcast >= config.BroadcastSeconds and MatchService.phase() ~= "Infiltration" then
			broadcast()
		end
	end)
end

return VaultService
