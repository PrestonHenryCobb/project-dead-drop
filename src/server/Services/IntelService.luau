--!strict
-- Ticket 11a: Intel (spec 9, SPEC_CHANGES "intel amounts" and "Intel is the only currency").
--
--   * Stations are the map's IntelSpawn-tagged parts (tablet 2, laptop 4, server rack 6, wall safe 10 intel). Each is
--     given an id ("I1", "I2", ... in a fixed order) in the IntelId attribute when the server starts. Every station is
--     live (ActiveSpawns, spec 9.2, was dropped when the map grew to 36), and each can be taken once per team.
--   * Hold Interact on a station (InteractService kind "Intel") for its HackSeconds. Progress is kept per team for
--     Intel.TerminalProgressKeepSeconds if the hold is broken. You must be close and in sight of it, and your disguise
--     must clear the room's tier. The hold is Suspicious if witnessed (CoverService.noteHacking).
--   * Intel belongs to the team. It is also the currency (doors, healing and ammo spend it in Step 18): spending lowers
--     the team's balance and so the unlock progress. The match-wide total is the sum of the balances.
--   * When the total reaches min(Cap, Base + teams * PerTeam) during Infiltration the Vault Breach begins.
--
-- A team's balance goes to that team alone (IntelUpdate); the total and its threshold go to everyone (GlobalIntelUpdate).
--
--   IntelService.balance(teamId) -> number
--   IntelService.spend(teamId, amount) -> boolean   false when the team cannot afford it
--   IntelService.globalTotal() -> number
--   IntelService.threshold() -> number

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Types = require(Shared:WaitForChild("Types"))
local CoverService = require(script.Parent.CoverService)
local DisguiseService = require(script.Parent.DisguiseService)
local DownedService = require(script.Parent.DownedService)
local InteractService = require(script.Parent.InteractService)
local MatchService = require(script.Parent.MatchService)
local RemoteService = require(script.Parent.RemoteService)
local TeamService = require(script.Parent.TeamService)
local ZoneService = require(script.Parent.ZoneService)

type Station = { id: string, part: BasePart, points: number, seconds: number, tier: number }
type Saved = { elapsed: number, at: number } -- seconds of a broken hold, and when it broke (os.clock)

local IntelService = {}

local config = GameConfig.Intel
local stations: { [string]: Station } = {}
local balances: { [number]: number } = {}
local used: { [number]: { [string]: boolean } } = {}
local saved: { [number]: { [string]: Saved } } = {}

local mapParams = RaycastParams.new()
mapParams.CollisionGroup = GameConfig.Rig.CollisionGroup
mapParams.RespectCanCollide = true

function IntelService.balance(teamId: number): number
	return balances[teamId] or 0
end

function IntelService.globalTotal(): number
	local total = 0
	for _, balance in balances do
		total += balance
	end
	return total
end

function IntelService.threshold(): number
	local unlock = config.Unlock
	return math.min(unlock.Cap, unlock.Base + MatchService.teamCount() * unlock.PerTeam)
end

local function sendTeam(teamId: number)
	local ids: { string } = {}
	for id in used[teamId] or {} do
		table.insert(ids, id)
	end
	table.sort(ids)
	local info: Types.IntelUpdateInfo = { Balance = IntelService.balance(teamId), Used = ids }
	RemoteService.fireClients("IntelUpdate", TeamService.members(teamId), info)
end

local function sendGlobal()
	local info: Types.GlobalIntelInfo = { Current = IntelService.globalTotal(), Threshold = IntelService.threshold() }
	RemoteService.fireAllClients("GlobalIntelUpdate", info)
end

local function checkUnlock()
	if MatchService.phase() == "Infiltration" and IntelService.globalTotal() >= IntelService.threshold() then
		MatchService.advance("VaultBreach")
	end
end

local function changed(teamId: number)
	sendTeam(teamId)
	sendGlobal()
	checkUnlock()
end

function IntelService.spend(teamId: number, amount: number): boolean
	if amount <= 0 or IntelService.balance(teamId) < amount then
		return false
	end
	balances[teamId] = IntelService.balance(teamId) - amount
	changed(teamId)
	return true
end

local function take(teamId: number, station: Station)
	used[teamId] = used[teamId] or {}
	used[teamId][station.id] = true
	if saved[teamId] then
		saved[teamId][station.id] = nil
	end
	balances[teamId] = IntelService.balance(teamId) + station.points
	if GameConfig.Debug.PrintEvents then
		print(`[Intel] team {teamId} took {station.id} (+{station.points}): {balances[teamId]}`)
	end
	changed(teamId)
end

local function beginStation(player: Player, targetName: string): InteractService.Interaction?
	local station = stations[targetName]
	local teamId = TeamService.teamOf(player)
	local phase = MatchService.phase()
	if not station or not teamId or not MatchService.isInMatch() or phase == "Insertion" then
		return nil
	end
	if (used[teamId] and used[teamId][station.id]) or DownedService.isOut(player) then
		return nil
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) or DisguiseService.getClearance(player) < station.tier then
		return nil
	end
	local function inReach(slack: number): boolean
		local offset = station.part.Position - root.Position
		if offset.Magnitude > config.InteractStuds + slack then
			return false
		end
		local hit = workspace:Raycast(root.Position, offset, mapParams)
		-- The station's own stand, cart or rack sits in the same folder, so those do not count as in the way.
		return hit == nil or hit.Instance.Parent == station.part.Parent
	end
	if not inReach(0) then
		return nil
	end

	-- A broken hold keeps its progress for a while, so the team resumes where it stopped.
	local clock = os.clock()
	local previous = saved[teamId] and saved[teamId][station.id]
	local already = 0
	if previous and clock - previous.at <= config.TerminalProgressKeepSeconds then
		already = math.min(previous.elapsed, station.seconds - 1 / GameConfig.Interact.CheckHz)
	end
	local startedAt = clock - already
	CoverService.noteHacking(player)
	return {
		label = "Hack",
		seconds = station.seconds - already,
		stillValid = function()
			local taken = used[teamId] and used[teamId][station.id]
			if DownedService.isOut(player) or taken or not inReach(config.InteractSlackStuds) then
				return false
			end
			saved[teamId] = saved[teamId] or {}
			saved[teamId][station.id] = { elapsed = os.clock() - startedAt, at = os.clock() }
			CoverService.noteHacking(player)
			return true
		end,
		complete = function()
			if not (used[teamId] and used[teamId][station.id]) then
				take(teamId, station)
			end
		end,
	}
end

-- New match: nothing is taken and nobody has any Intel.
local function reset()
	table.clear(balances)
	table.clear(used)
	table.clear(saved)
	sendGlobal()
end

function IntelService.Init() end

function IntelService.Start()
	local parts: { BasePart } = {}
	for _, instance in CollectionService:GetTagged(Enums.Tag.IntelSpawn) do
		if instance:IsA("BasePart") then
			table.insert(parts, instance)
		end
	end
	-- A fixed order, so an id means the same station on every server.
	table.sort(parts, function(a, b)
		local pa, pb = a.Position, b.Position
		if pa.Y ~= pb.Y then
			return pa.Y < pb.Y
		elseif pa.X ~= pb.X then
			return pa.X < pb.X
		end
		return pa.Z < pb.Z
	end)
	for index, part in parts do
		local id = `I{index}`
		part:SetAttribute("IntelId", id)
		local kind = config.Stations[part:GetAttribute("Type") :: number]
		assert(kind, `Intel station at {part.Position} has no valid Type attribute`)
		stations[id] = {
			id = id,
			part = part,
			points = kind.Points,
			seconds = kind.HackSeconds,
			tier = ZoneService.tierAt(part.Position),
		}
	end
	InteractService.register("Intel", beginStation)
	MatchService.onPhaseChanged(function(phase)
		if phase == "Insertion" then
			reset()
			local sent: { [number]: boolean } = {}
			for _, player in Players:GetPlayers() do
				local teamId = TeamService.teamOf(player)
				if teamId and not sent[teamId] then
					sent[teamId] = true
					sendTeam(teamId)
				end
			end
		end
	end)
end

return IntelService
