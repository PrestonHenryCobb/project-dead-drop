--!strict
-- Spec 11 (map table): "Each team spawns at one InsertionPoint, players within 8 studs of each other." At Insertion MatchService asks for a spot for
-- every human, and this hands out one InsertionPoint per team in a shuffled order (so a team does not always start in the same place), with teammates
-- standing in a small ring around the point. With more teams than points the points are reused in turn. With no points on the map (nothing is tagged)
-- it returns no spots and the players keep the ordinary spawn.
--
--   SpawnService.assign(teams) -> { [Player]: CFrame }      teams is { [teamId]: { Player } }

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Enums = require(Shared:WaitForChild("Enums"))

local SpawnService = {}

local config = GameConfig.Match.TeamSpawn
local rng = Random.new()

function SpawnService.assign(teams: { [number]: { Player } }): { [Player]: CFrame }
	local points: { BasePart } = {}
	for _, instance in CollectionService:GetTagged(Enums.Tag.InsertionPoint) do
		if instance:IsA("BasePart") then
			table.insert(points, instance)
		end
	end
	local spots: { [Player]: CFrame } = {}
	if #points == 0 then
		return spots
	end
	for i = #points, 2, -1 do
		local j = rng:NextInteger(1, i)
		points[i], points[j] = points[j], points[i]
	end
	local teamIds: { number } = {}
	for teamId in teams do
		table.insert(teamIds, teamId)
	end
	table.sort(teamIds)
	for index, teamId in teamIds do
		local point = points[(index - 1) % #points + 1]
		local members = teams[teamId]
		for slot, member in members do
			local offset = Vector3.zero
			if #members > 1 then
				local angle = (slot - 1) / #members * 2 * math.pi
				offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * config.RingStuds
			end
			spots[member] = CFrame.new(point.Position + offset + Vector3.new(0, config.LiftStuds, 0))
		end
	end
	return spots
end

function SpawnService.Init() end

function SpawnService.Start() end

return SpawnService
