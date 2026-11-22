--!strict
-- Ticket 12a: the vault terminals and the Sanctum unlock (spec 10, SPEC_CHANGES 2026-10-25).
--
--   * At the start of a match Vault.ActiveVaults of the five vaults are chosen at random. Each gets a terminal on its dais
--     (the VaultTerminalSpot part); the other vaults stay empty. From the start of Infiltration every client is told where the
--     active terminals are (VaultProgress), so they are easy to find (owner test 2026-11-21).
--   * A terminal is hacked by holding Interact at it (owner decision 2026-11-21: no capture point). InteractService runs the
--     hold ("Vault", the vault id; label "Hack vault"); while at least one living holder (or bot on the dais) is at it, its
--     progress rises Vault.BaseRate percent a second, Vault.BonusMult times that for a team with Intel.Thresholds.HackBonusAt
--     Intel. Holders do not stack, rivals holding at once do not pause it (Contested only tells the HUD), and progress is global
--     and never decays, so an interrupted hold is resumed by anyone. A holder is Exposed at once (spec 7.2 #8).
--   * The first progress on any terminal begins the Vault Breach if the 6:00 timer has not (MatchService).
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
local InteractService = require(script.Parent.InteractService)
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
	holders: { [Player]: boolean }, -- players holding Interact at it now
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
		prop:SetAttribute("VaultId", tostring(dais:GetAttribute("VaultId")))
		CollectionService:AddTag(prop, Enums.Tag.VaultTerminal)
		table.insert(terminals, {
			vaultId = tostring(dais:GetAttribute("VaultId")),
			dais = dais,
			radius = dais.Size.Z / 2, -- a cylinder lying on its side: its length is X, its diameter Y and Z
			prop = prop,
			progress = 0,
			contested = false,
			hacked = false,
			holders = {},
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

-- The teams at a terminal: players holding Interact at it, and (ticket 13B-a) bots on its dais, which count for their team.
local function presence(terminal: Terminal): ({ [number]: boolean }, { Player })
	local teams: { [number]: boolean } = {}
	local present: { Player } = {}
	for player in terminal.holders do
		local teamId = TeamService.teamOf(player)
		if teamId and player.Parent and not DownedService.isOut(player) then
			teams[teamId] = true
			table.insert(present, player)
		end
	end
	local center = terminal.dais.Position
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

-- The faster rate applies when a team at the terminal has enough Intel (the best-off team there, so a rival cannot slow the hack).
local function bonusFor(_: Terminal, teams: { [number]: boolean }): boolean
	for teamId in teams do
		if IntelService.balance(teamId) >= GameConfig.Intel.Thresholds.HackBonusAt then
			return true
		end
	end
	return false
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
			if count >= 1 then
				local rate = config.BaseRate
				if bonusFor(terminal, teams) then
					rate *= config.BonusMult
				end
				terminal.progress = math.min(100, terminal.progress + rate * dt)
				dirty = true
				if MatchService.phase() == "Infiltration" then
					MatchService.advance("VaultBreach") -- the first hack shows every team where the terminals are
				end
				if terminal.progress >= 100 then
					terminal.hacked = true
					if terminal.prop then
						CollectionService:RemoveTag(terminal.prop, Enums.Tag.VaultTerminal)
					end
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

-- The terminal a "Vault" hold names (its vault id), if it can be hacked now.
local function terminalNamed(vaultId: string): Terminal?
	for _, terminal in terminals do
		if terminal.vaultId == vaultId and not terminal.hacked then
			return terminal
		end
	end
	return nil
end

local function inReach(player: Player, terminal: Terminal, slack: number): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return false
	end
	local offset = root.Position - terminal.dais.Position
	return Vector3.new(offset.X, 0, offset.Z).Magnitude <= config.InteractStuds + slack
		and math.abs(offset.Y) <= config.TerminalHeightStuds
end

local function beginHack(player: Player, vaultId: string): InteractService.Interaction?
	local terminal = terminalNamed(vaultId)
	if not terminal or not active() or not TeamService.teamOf(player) or DownedService.isOut(player) then
		return nil
	end
	if not inReach(player, terminal, 0) then
		return nil
	end
	local rate = config.BaseRate
	if IntelService.balance(TeamService.teamOf(player) :: number) >= GameConfig.Intel.Thresholds.HackBonusAt then
		rate *= config.BonusMult
	end
	return {
		label = config.HoldLabel,
		seconds = (100 - terminal.progress) / rate + config.HackBufferSeconds,
		stillValid = function()
			return not terminal.hacked
				and not DownedService.isOut(player)
				and active()
				and inReach(player, terminal, config.InteractSlackStuds)
		end,
		complete = function() end, -- progress is added by check while the hold runs
	}
end

function VaultService.Init() end

function VaultService.Start()
	InteractService.register("Vault", beginHack)
	-- Who is holding at which terminal: a hold beginning or ending, whatever ended it.
	InteractService.onHold(function(player, label, isActive, _seconds)
		if label ~= config.HoldLabel then
			return
		end
		for _, terminal in terminals do
			terminal.holders[player] = nil
		end
		if not isActive then
			return
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not (root and root:IsA("BasePart")) then
			return
		end
		local best: Terminal? = nil
		local bestDistance = math.huge
		for _, terminal in terminals do
			local distance = (root.Position - terminal.dais.Position).Magnitude
			if not terminal.hacked and distance < bestDistance then
				best, bestDistance = terminal, distance
			end
		end
		if best then
			best.holders[player] = true
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		for _, terminal in terminals do
			terminal.holders[player] = nil
		end
	end)
	MatchService.onPhaseChanged(function(phase)
		if phase == "Insertion" then
			setup()
		elseif phase == "Infiltration" or phase == "VaultBreach" or phase == "PackageHeist" then
			broadcast() -- everyone learns where the terminals are, from the start of Infiltration
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
		if dirty and sinceBroadcast >= config.BroadcastSeconds then
			broadcast()
		end
	end)
end

return VaultService
