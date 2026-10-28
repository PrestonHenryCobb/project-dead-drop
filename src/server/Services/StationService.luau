--!strict
-- Ticket 18b: the wall stations (SPEC_CHANGES: intel is the only currency; no passive healing except an agent's own kit).
--
--   * Health Station (tag HealthStation, in restrooms): hold Interact Economy.Stations.HealthStation.Seconds, the team pays Cost
--     intel, and the user is healed to full. Refused at full health. Reusable.
--   * Ammo Cache (AmmoCache): the same for a full magazine and reserve for the weapon in hand. Refused when already full.
--   * Food Spot (FoodSpot): free; heals Heal HP; refused at full health; empty for PickupRespawnSeconds after (its Taken
--     attribute says so). Reset at the start of a match.
-- Using one is Discreet (a Security NPC or camera that sees it breaks Cover). The user must be near it and in sight of it for
-- the whole hold; a drone or the Long Lens does not reach for a body's needs. Each station has a StationId ("H1", "A1", "F1", ...).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local AssetService = require(script.Parent.AssetService)
local CombatService = require(script.Parent.CombatService)
local CoverService = require(script.Parent.CoverService)
local DownedService = require(script.Parent.DownedService)
local IntelService = require(script.Parent.IntelService)
local InteractService = require(script.Parent.InteractService)
local MatchService = require(script.Parent.MatchService)
local RemoteService = require(script.Parent.RemoteService)
local TeamService = require(script.Parent.TeamService)

type Kind = {
	tag: string,
	kind: string, -- the InteractService kind
	prefix: string, -- the StationId letter
	label: string,
	cost: number,
	seconds: number,
	needs: (Player) -> string?, -- why the user has no use for it right now, if so
	apply: (Player) -> (),
}

type Station = { part: BasePart, kind: Kind, takenUntil: number }

local StationService = {}

local config = GameConfig.Economy.Stations
local stations: { [string]: Station } = {}

local mapParams = RaycastParams.new()
mapParams.CollisionGroup = GameConfig.Rig.CollisionGroup
mapParams.RespectCanCollide = true

local KINDS: { Kind } = {
	{
		tag = Enums.Tag.HealthStation,
		kind = "HealthStation",
		prefix = "H",
		label = "Heal",
		cost = config.HealthStation.Cost,
		seconds = config.HealthStation.Seconds,
		needs = function(player)
			return if CombatService.isHurt(player) then nil else "Already at full health"
		end,
		apply = function(player)
			CombatService.heal(player, GameConfig.Combat.MaxHP)
		end,
	},
	{
		tag = Enums.Tag.AmmoCache,
		kind = "AmmoCache",
		prefix = "A",
		label = "Refill ammo",
		cost = config.AmmoCache.Cost,
		seconds = config.AmmoCache.Seconds,
		needs = function(player)
			return if CombatService.canRefillAmmo(player) then nil else "Ammo is full"
		end,
		apply = CombatService.refillAmmo,
	},
	{
		tag = Enums.Tag.FoodSpot,
		kind = "FoodSpot",
		prefix = "F",
		label = "Eat",
		cost = config.FoodSpot.Cost,
		seconds = config.FoodSpot.Seconds,
		needs = function(player)
			return if CombatService.isHurt(player) then nil else "Already at full health"
		end,
		apply = function(player)
			CombatService.heal(player, config.FoodSpot.Heal * (1 + AssetService.value(player, "FieldMedic"))) -- Field Medic
		end,
	},
}

local function show(station: Station)
	station.part:SetAttribute("Taken", os.clock() < station.takenUntil)
end

local function begin(kind: Kind, player: Player, stationId: string): InteractService.Interaction?
	local station = stations[stationId]
	local teamId = TeamService.teamOf(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if
		not (station and station.kind == kind and teamId and root and root:IsA("BasePart"))
		or not MatchService.isInMatch()
		or MatchService.phase() == "Insertion"
		or DownedService.isOut(player)
		or os.clock() < station.takenUntil
	then
		return nil
	end
	local function inReach(): boolean
		-- Reach and sight go to the face of the station nearest the user: a wall station sits in its wall, and the line stops
		-- WallSlackStuds short of that face.
		local offset = station.part:GetClosestPointOnSurface(root.Position) - root.Position
		if offset.Magnitude > config.InteractStuds then
			return false
		end
		local seen = offset - offset.Unit * math.min(config.WallSlackStuds, offset.Magnitude)
		local hit = workspace:Raycast(root.Position, seen, mapParams)
		return hit == nil or hit.Instance == station.part or hit.Instance.Parent == station.part.Parent
	end
	if not inReach() then
		return nil
	end
	local reason = kind.needs(player)
	if reason then
		RemoteService.fireClient("Notification", player, reason)
		return nil
	end
	local cost = AssetService.discounted(player, kind.cost) -- Deep Pockets
	if IntelService.balance(teamId) < cost then
		RemoteService.fireClient("Notification", player, `Needs {cost} intel`)
		return nil
	end
	CoverService.useDiscreetly(player, kind.kind)
	return {
		label = kind.label,
		seconds = kind.seconds,
		stillValid = function()
			return not DownedService.isOut(player)
				and inReach()
				and os.clock() >= station.takenUntil
				and IntelService.balance(teamId) >= cost
				and kind.needs(player) == nil
		end,
		complete = function()
			if cost > 0 and not IntelService.spend(teamId, cost) then
				return
			end
			kind.apply(player)
			if kind.kind == "FoodSpot" then
				station.takenUntil = os.clock() + GameConfig.Economy.PickupRespawnSeconds
				show(station)
				task.delay(GameConfig.Economy.PickupRespawnSeconds, function()
					show(station)
				end)
			end
		end,
	}
end

function StationService.Init() end

function StationService.Start()
	for _, kind in KINDS do
		local parts: { BasePart } = {}
		for _, instance in CollectionService:GetTagged(kind.tag) do
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
			local id = `{kind.prefix}{index}`
			part:SetAttribute("StationId", id)
			stations[id] = { part = part, kind = kind, takenUntil = 0 }
			show(stations[id])
		end
		InteractService.register(kind.kind, function(player, target)
			return begin(kind, player, target)
		end)
	end
	-- A new match: every Food Spot is full again.
	MatchService.onPhaseChanged(function(phase)
		if phase == "Insertion" then
			for _, station in stations do
				station.takenUntil = 0
				show(station)
			end
		end
	end)
end

return StationService
