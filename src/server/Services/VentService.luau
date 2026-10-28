--!strict
-- Vents (spec 4.3, BUILD_ORDER Step 7B pass 2b): low ducts behind grates that bypass a guarded door. Entering one
-- breaks Cover (spec 7.2). Players fit through a grate; NPCs never path through one (it is narrower than they need).
--
-- The map tags the inside of each duct VentDuct. At GameConfig.Traversal.Vent.CheckHz this service looks for players
-- inside one and exposes each on the way in.
-- SPEC-QUESTION: the Package carrier may not enter vents (spec 11.2). A duct cannot refuse a body, and the carrier is
-- Exposed anyway (PackageService), so nothing is blocked here.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local AssetDefs = require(Shared:WaitForChild("Defs"):WaitForChild("AssetDefs"))
local Types = require(Shared:WaitForChild("Types"))
local CoverService = require(script.Parent.CoverService)
local DisguiseService = require(script.Parent.DisguiseService)

local VentService = {}

local ducts: { BasePart } = {}
local inside: { [Player]: boolean } = {}

local function inDuct(position: Vector3): boolean
	for _, duct in ducts do
		local localPoint = duct.CFrame:PointToObjectSpace(position)
		local half = duct.Size / 2
		if
			math.abs(localPoint.X) <= half.X
			and math.abs(localPoint.Y) <= half.Y
			and math.abs(localPoint.Z) <= half.Z
		then
			return true
		end
	end
	return false
end

-- Ticket 18e: AssetService says what Assets a player has found (it cannot be required here: Combat requires this module).
local assets: {
	value: (Player, string) -> number,
	rarityOf: (Player, string) -> Types.AssetRarity?,
}? = nil

function VentService.setAssets(lookup: {
	value: (Player, string) -> number,
	rarityOf: (Player, string) -> Types.AssetRarity?,
})
	assets = lookup
end

-- Duct Rat: from Assets.QuietVentFrom up, the Asset lets its holder into a vent without breaking Cover.
local function quietIn(player: Player): boolean
	local lookup = assets
	local rarity = if lookup then lookup.rarityOf(player, "DuctRat") else nil
	return rarity ~= nil
		and table.find(AssetDefs.rarities, rarity) :: number
			>= (table.find(AssetDefs.rarities, GameConfig.Assets.QuietVentFrom) :: number)
end

-- Is the player inside a duct (as of the last check)? Combat skips fall damage in there.
function VentService.isInside(player: Player): boolean
	return inside[player] == true
end

function VentService.Init()
	for _, duct in CollectionService:GetTagged(Enums.Tag.VentDuct) do
		if duct:IsA("BasePart") then
			table.insert(ducts, duct)
		end
	end
end

function VentService.Start()
	local interval = 1 / GameConfig.Traversal.Vent.CheckHz
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < interval then
			return
		end
		elapsed = 0
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local now = root ~= nil and root:IsA("BasePart") and inDuct(root.Position)
			if now and not inside[player] and not quietIn(player) then
				CoverService.expose(player, "Vent")
			end
			-- Duct Rat: faster through the duct (a speed-up that lapses just after they leave it).
			local lookup = assets
			local rat = if now and lookup then lookup.value(player, "DuctRat") else 0
			if rat > 0 then
				DisguiseService.applySlow(player, 1 + rat, interval * 2)
			end
			inside[player] = now or nil
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		inside[player] = nil
	end)
end

return VentService
