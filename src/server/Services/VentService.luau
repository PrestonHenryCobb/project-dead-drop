--!strict
-- Vents (spec 4.3, BUILD_ORDER Step 7B pass 2b): low ducts behind grates that bypass a guarded door. Entering one
-- breaks Cover (spec 7.2). Players fit through a grate; NPCs never path through one (it is narrower than they need).
--
-- The map tags the inside of each duct VentDuct. At GameConfig.Traversal.Vent.CheckHz this service looks for players
-- inside one and exposes each on the way in.
-- SPEC-QUESTION: the Package carrier may not enter vents (spec 11.2); that check joins when the Package exists (Step 13).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local CoverService = require(script.Parent.CoverService)

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
			if now and not inside[player] then
				CoverService.expose(player, "Vent")
			end
			inside[player] = now or nil
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		inside[player] = nil
	end)
end

return VentService
