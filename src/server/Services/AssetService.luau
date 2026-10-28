--!strict
-- Ticket 18e: Assets, per-match perks (docs/ASSETS_DESIGN.md).
--
--   * Every player brings four different Assets, one for each rarity slot (PlayerLoadout.AssetIds, or Assets.DefaultPicks).
--   * Each AssetSafe on the map holds the rarity of the room it stands in (Assets.RarityByTier). The first agent to finish
--     Assets.SafeSeconds of holding Interact (kind "AssetSafe") on it takes it, the team pays the rarity's intel price
--     (Assets.SafeCost, less Deep Pockets), and the safe is empty for the rest of the match (its Opened attribute says so).
--     The opener gets their own loadout's Asset for that rarity, at that rarity's strength. Nobody opens a safe of a rarity they
--     already hold.
--   * Downed keeps Assets; elimination loses them, so a rescued agent returns with none. A new match starts with none.
--   * The systems an Asset changes ask value(): Cover (Light Feet, Steady Nerves), hack times (Quick Hands, via AbilityService),
--     prices (Deep Pockets: discounted), Food Spots (Field Medic) and vents (Duct Rat).
--
--   AssetService.value(player, assetId) -> number     the fraction the player's found Asset has (0 if not found)
--   AssetService.rarityOf(player, assetId) -> AssetRarity?
--   AssetService.discounted(player, price) -> number  Deep Pockets applied (a price of 0 stays 0, anything else at least 1)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local AssetDefs = require(Shared:WaitForChild("Defs"):WaitForChild("AssetDefs"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Types = require(Shared:WaitForChild("Types"))
local CoverService = require(script.Parent.CoverService)
local DownedService = require(script.Parent.DownedService)
local IntelService = require(script.Parent.IntelService)
local InteractService = require(script.Parent.InteractService)
local MatchService = require(script.Parent.MatchService)
local MetaProgressionService = require(script.Parent.MetaProgressionService)
local RemoteService = require(script.Parent.RemoteService)
local TeamService = require(script.Parent.TeamService)
local VentService = require(script.Parent.VentService)

type AssetRarity = Types.AssetRarity
type Safe = { part: BasePart, id: string, rarity: AssetRarity, opened: boolean }

local AssetService = {}

local config = GameConfig.Assets
local safes: { [string]: Safe } = {}
local found: { [Player]: { [AssetRarity]: string } } = {} -- the Assets each player has found, by rarity

local mapParams = RaycastParams.new()
mapParams.CollisionGroup = GameConfig.Rig.CollisionGroup
mapParams.RespectCanCollide = true

-- The four Assets a player brought, in rarity order.
local function loadoutOf(player: Player): { string }
	local loadout = MetaProgressionService.getLoadout(player)
	return (loadout and loadout.AssetIds) or config.DefaultPicks
end

function AssetService.rarityOf(player: Player, assetId: string): AssetRarity?
	for rarity, id in found[player] or {} do
		if id == assetId then
			return rarity
		end
	end
	return nil
end

function AssetService.value(player: Player, assetId: string): number
	local rarity = AssetService.rarityOf(player, assetId)
	return if rarity then AssetDefs.valueOf(assetId, rarity) else 0
end

function AssetService.discounted(player: Player, price: number): number
	if price <= 0 then
		return price
	end
	return math.max(1, math.floor(price * (1 + AssetService.value(player, "DeepPockets")) + 0.5))
end

local function send(player: Player)
	local info: Types.AssetStateInfo = { Slots = {} }
	local brought = loadoutOf(player)
	for index, rarity in AssetDefs.rarities do
		table.insert(
			info.Slots,
			{ Rarity = rarity, AssetId = brought[index], Found = (found[player] or {})[rarity] ~= nil }
		)
	end
	RemoteService.fireClient("AssetState", player, info)
end

local function rarityForTier(tier: number): AssetRarity
	return (config.RarityByTier :: { [number]: AssetRarity })[math.min(tier, #AssetDefs.rarities - 1)]
end

local function slotOf(rarity: AssetRarity): number
	return table.find(AssetDefs.rarities, rarity) :: number
end

local function begin(player: Player, safeId: string): InteractService.Interaction?
	local safe = safes[safeId]
	local teamId = TeamService.teamOf(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if
		not (safe and teamId and root and root:IsA("BasePart"))
		or safe.opened
		or not MatchService.isInMatch()
		or MatchService.phase() == "Insertion"
		or DownedService.isOut(player)
	then
		return nil
	end
	local function inReach(): boolean
		local offset = safe.part:GetClosestPointOnSurface(root.Position) - root.Position
		if offset.Magnitude > config.SafeStuds then
			return false
		end
		local hit = workspace:Raycast(
			root.Position,
			offset - offset.Unit * math.min(config.WallSlackStuds, offset.Magnitude),
			mapParams
		)
		return hit == nil or hit.Instance == safe.part or hit.Instance.Parent == safe.part.Parent
	end
	if not inReach() then
		return nil
	end
	if (found[player] or {})[safe.rarity] ~= nil then
		RemoteService.fireClient("Notification", player, "You already hold this rarity of Asset")
		return nil
	end
	local price = AssetService.discounted(player, config.SafeCost[safe.rarity])
	if IntelService.balance(teamId) < price then
		RemoteService.fireClient("Notification", player, `Needs {price} intel`)
		return nil
	end
	CoverService.noteHacking(player) -- cracking a safe looks like hacking
	return {
		label = "Open safe",
		seconds = config.SafeSeconds,
		stillValid = function()
			CoverService.noteHacking(player)
			return not DownedService.isOut(player)
				and inReach()
				and not safe.opened
				and IntelService.balance(teamId) >= price
		end,
		complete = function()
			if safe.opened or not IntelService.spend(teamId, price) then
				return
			end
			safe.opened = true
			safe.part:SetAttribute("Opened", true)
			found[player] = found[player] or {}
			found[player][safe.rarity] = loadoutOf(player)[slotOf(safe.rarity)]
			send(player)
		end,
	}
end

-- A new match: every safe is full again and nobody has found anything.
local function reset()
	table.clear(found)
	for _, safe in safes do
		safe.opened = false
		safe.part:SetAttribute("Opened", false)
	end
	for _, player in Players:GetPlayers() do
		send(player)
	end
end

function AssetService.Init() end

function AssetService.Start()
	local parts: { BasePart } = {}
	for _, instance in CollectionService:GetTagged(Enums.Tag.AssetSafe) do
		if instance:IsA("BasePart") then
			table.insert(parts, instance)
		end
	end
	-- A fixed order, so an id means the same safe on every server.
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
		local tier = part:GetAttribute("Tier")
		local id = `V{index}`
		local rarity = rarityForTier(if type(tier) == "number" then tier else 0)
		part:SetAttribute("SafeId", id)
		part:SetAttribute("Rarity", rarity)
		part:SetAttribute("Opened", false)
		safes[id] = { part = part, id = id, rarity = rarity, opened = false }
	end
	InteractService.register("AssetSafe", begin)
	CoverService.setAssetLookup(AssetService.value)
	VentService.setAssets({ value = AssetService.value, rarityOf = AssetService.rarityOf })
	MatchService.onPhaseChanged(function(phase)
		if phase == "Insertion" then
			reset()
		end
	end)
	-- Elimination loses them; a rescue then returns the agent with none.
	DownedService.onEliminated(function(player)
		if found[player] then
			found[player] = nil
			send(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		found[player] = nil
	end)
end

return AssetService
