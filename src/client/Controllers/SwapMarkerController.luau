--!strict
-- Disguise-swap markers this player has been told about (brief Q6): a diamond floating where a rival changed disguise,
-- fading out as it runs down. The server sends one only when this player comes within range, and the marker is drawn
-- in the world (walls hide it), so it is seen only from nearby. Placeholder look until the art pass (Step 19).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Types = require(Shared:WaitForChild("Types"))
local RemoteController = require(script.Parent.RemoteController)

type Shown = { anchor: Part, diamond: Frame, startsAt: number, expiresAt: number }

local SwapMarkerController = {}

local ui = GameConfig.UI
local DIAMOND_FILL = 0.7 -- of the billboard, so the square still fits once turned 45 degrees

local folder: Folder? = nil
local shown: { Shown } = {}

local function show(info: Types.SwapMarkerInfo)
	local parent = folder
	if not parent then
		return
	end
	local anchor = Instance.new("Part")
	anchor.Name = "SwapMarker"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Position = info.Position + Vector3.new(0, ui.SwapMarkerHeightStuds, 0)

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromScale(ui.SwapMarkerSizeStuds, ui.SwapMarkerSizeStuds)
	billboard.LightInfluence = 0
	billboard.AlwaysOnTop = false -- hidden by walls: a marker is only seen from where the swap could be seen
	billboard.Parent = anchor

	local diamond = Instance.new("Frame")
	diamond.AnchorPoint = Vector2.new(0.5, 0.5)
	diamond.Position = UDim2.fromScale(0.5, 0.5)
	diamond.Size = UDim2.fromScale(DIAMOND_FILL, DIAMOND_FILL)
	diamond.Rotation = 45
	diamond.BorderSizePixel = 0
	diamond.BackgroundColor3 = ui.SwapMarkerColor
	diamond.Parent = billboard

	anchor.Parent = parent
	table.insert(shown, {
		anchor = anchor,
		diamond = diamond,
		startsAt = workspace:GetServerTimeNow(),
		expiresAt = info.ExpiresAt,
	})
end

local function update()
	local now = workspace:GetServerTimeNow()
	for index = #shown, 1, -1 do
		local marker = shown[index]
		if now >= marker.expiresAt then
			marker.anchor:Destroy()
			table.remove(shown, index)
		else
			local left = (marker.expiresAt - now) / math.max(marker.expiresAt - marker.startsAt, 1e-3)
			marker.diamond.BackgroundTransparency = 1 - left
		end
	end
end

function SwapMarkerController.Init() end

function SwapMarkerController.Start()
	local created = Instance.new("Folder")
	created.Name = "SwapMarkers"
	created.Parent = workspace
	folder = created
	RemoteController.connect("SwapMarker", show)
	RunService.RenderStepped:Connect(update)
end

return SwapMarkerController
