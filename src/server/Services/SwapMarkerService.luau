--!strict
-- Disguise-swap markers (brief Q6, SPEC_CHANGES 6.4). Where someone changes disguise, rival agents see a marker for
-- Cover.SwapMarkerSeconds by the tier put on (Guest 5 s up to Executive 20 s). It replaces the old puff.
--
-- The server keeps the markers and tells each rival about one only when they come within Cover.SwapMarkerRange of it,
-- checked SwapMarkerCheckHz times a second, so a client never learns of swaps across the map. Until teams exist
-- (Step 10), every other player is a rival.
--
--   SwapMarkerService.place(owner, position, tier)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Types = require(Shared:WaitForChild("Types"))
local RemoteService = require(script.Parent.RemoteService)

type Marker = {
	owner: Player,
	position: Vector3,
	expiresAt: number, -- server clock
	told: { [Player]: boolean },
}

local SwapMarkerService = {}

local config = GameConfig.Cover
local markers: { Marker } = {}

function SwapMarkerService.place(owner: Player, position: Vector3, tier: number)
	local seconds = config.SwapMarkerSeconds[tier]
	assert(seconds, `No swap marker time for tier {tier}`)
	table.insert(markers, {
		owner = owner,
		position = position,
		expiresAt = workspace:GetServerTimeNow() + seconds,
		told = {},
	})
end

local function check()
	local now = workspace:GetServerTimeNow()
	local rangeSquared = config.SwapMarkerRange * config.SwapMarkerRange
	for index = #markers, 1, -1 do
		local marker = markers[index]
		if now >= marker.expiresAt then
			table.remove(markers, index)
		else
			for _, player in Players:GetPlayers() do
				if player ~= marker.owner and not marker.told[player] then
					local character = player.Character
					local root = character and character:FindFirstChild("HumanoidRootPart")
					if root and root:IsA("BasePart") then
						local offset = root.Position - marker.position
						if offset:Dot(offset) <= rangeSquared then
							marker.told[player] = true
							local info: Types.SwapMarkerInfo =
								{ Position = marker.position, ExpiresAt = marker.expiresAt }
							RemoteService.fireClient("SwapMarker", player, info)
						end
					end
				end
			end
		end
	end
end

function SwapMarkerService.Init() end

function SwapMarkerService.Start()
	local interval = 1 / config.SwapMarkerCheckHz
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= interval then
			elapsed = 0
			check()
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		for _, marker in markers do
			marker.told[player] = nil
		end
	end)
end

return SwapMarkerService
