--!strict
-- Tracks which clearance tier each player is standing in (spec 4.2).
--
-- Zones are invisible parts tagged ZoneVolume with a Tier attribute (0 to 3). Every GameConfig.Zones.CheckInterval
-- seconds (4 Hz) the server tests each character's HumanoidRootPart against every volume. Where volumes overlap
-- the highest tier wins (spec 27 #18). A position inside no volume counts as Public (tier 0).
--
--   ZoneService.getTier(player) -> number
--   ZoneService.TierChanged:Connect(function(player, newTier, oldTier) ... end)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))

type Volume = {
	part: BasePart,
	tier: number,
}

local ZoneService = {}

local tierChanged = Instance.new("BindableEvent")
ZoneService.TierChanged = tierChanged.Event

local volumes: { Volume } = {}
local playerTiers: { [Player]: number } = {}

local function addVolume(instance: Instance)
	if not instance:IsA("BasePart") then
		warn(`[ZoneService] {instance:GetFullName()} is tagged ZoneVolume but is not a part`)
		return
	end
	local tier = instance:GetAttribute("Tier")
	if type(tier) ~= "number" then
		warn(`[ZoneService] {instance:GetFullName()} has no numeric Tier attribute`)
		return
	end
	table.insert(volumes, { part = instance, tier = tier })
end

local function removeVolume(instance: Instance)
	for index, volume in volumes do
		if volume.part == instance then
			table.remove(volumes, index)
			return
		end
	end
end

-- The highest tier of any volume that contains the position, or 0 if none do.
local function tierAt(position: Vector3): number
	local highest = 0
	for _, volume in volumes do
		if volume.tier > highest then
			local localPos = volume.part.CFrame:PointToObjectSpace(position)
			local half = volume.part.Size / 2
			if math.abs(localPos.X) <= half.X and math.abs(localPos.Y) <= half.Y and math.abs(localPos.Z) <= half.Z then
				highest = volume.tier
			end
		end
	end
	return highest
end

local function tierName(tier: number): string
	for name, id in Enums.Tier do
		if id == tier then
			return name
		end
	end
	return "Unknown"
end

local function setTier(player: Player, newTier: number)
	local oldTier = playerTiers[player]
	if oldTier == newTier then
		return
	end
	playerTiers[player] = newTier
	if GameConfig.Debug.PrintZoneChanges then
		print(`[ZoneService] {player.Name}: tier {newTier} ({tierName(newTier)})`)
	end
	tierChanged:Fire(player, newTier, oldTier)
end

local function check()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			setTier(player, tierAt(root.Position))
		end
	end
end

-- The tier the player stands in right now. 0 until their character exists.
function ZoneService.getTier(player: Player): number
	return playerTiers[player] or 0
end

function ZoneService.Init() end

function ZoneService.Start()
	for _, instance in CollectionService:GetTagged(Enums.Tag.ZoneVolume) do
		addVolume(instance)
	end
	CollectionService:GetInstanceAddedSignal(Enums.Tag.ZoneVolume):Connect(addVolume)
	CollectionService:GetInstanceRemovedSignal(Enums.Tag.ZoneVolume):Connect(removeVolume)

	Players.PlayerRemoving:Connect(function(player)
		playerTiers[player] = nil
	end)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < GameConfig.Zones.CheckInterval then
			return
		end
		elapsed %= GameConfig.Zones.CheckInterval
		check()
	end)
end

return ZoneService
