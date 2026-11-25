--!strict
-- Makes Intel stations unmistakable (owner 2026-11-25): a gold diamond marker floats over every station that can still be taken, with the points it is
-- worth, and the station's pad and screen pulse. The marker is an ordinary billboard, so walls hide it: it shows what line of sight already shows. It
-- marks map props only, never a character.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Janitor = require(Shared:WaitForChild("Util"):WaitForChild("Janitor"))
local IntelController = require(script.Parent.IntelController)

local IntelMarkerController = {}

local config = GameConfig.Intel
local janitor = Janitor.new()
local markers: { [BasePart]: { gui: BillboardGui, diamond: Frame, label: TextLabel } } = {}
local glows: { [BasePart]: number } = {} -- each pulsing part and the transparency it was built with

local function makeMarker(station: BasePart)
	local gui = Instance.new("BillboardGui")
	gui.Name = "IntelMarker"
	gui.Adornee = station
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.MaxDistance = config.MarkerRange
	gui.Size = UDim2.fromOffset(config.MarkerWidthPixels, config.MarkerHeightPixels)
	gui.StudsOffset = Vector3.new(0, config.MarkerLiftStuds, 0)
	gui.Enabled = false
	gui.Parent = station
	local diamond = Instance.new("Frame")
	diamond.Name = "Diamond"
	diamond.AnchorPoint = Vector2.new(0.5, 0.5)
	diamond.Position = UDim2.fromScale(0.5, 0.36)
	diamond.Size = UDim2.fromOffset(config.MarkerWidthPixels * 0.5, config.MarkerWidthPixels * 0.5)
	diamond.Rotation = 45
	diamond.BackgroundColor3 = config.MarkerColor
	diamond.BorderSizePixel = 0
	diamond.Parent = gui
	local ring = Instance.new("UIStroke")
	ring.Color = Color3.new(0, 0, 0)
	ring.Thickness = 2
	ring.Transparency = 0.35
	ring.Parent = diamond
	local label = Instance.new("TextLabel")
	label.Name = "Points"
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.fromScale(0.5, 1)
	label.Size = UDim2.fromScale(1, 0.34)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = config.MarkerColor
	label.TextStrokeTransparency = 0.3
	local points = station:GetAttribute("Points")
	label.Text = if type(points) == "number" then `INTEL +{points}` else "INTEL"
	label.Parent = gui
	markers[station] = { gui = gui, diamond = diamond, label = label }
end

function IntelMarkerController.Init() end

function IntelMarkerController.Start()
	local function trackStation(instance: Instance)
		if instance:IsA("BasePart") and instance:GetAttribute("Points") ~= nil then
			makeMarker(instance)
		end
	end
	local function untrackStation(instance: Instance)
		local marker = markers[instance :: BasePart]
		if marker then
			marker.gui:Destroy()
			markers[instance :: BasePart] = nil
		end
	end
	janitor:Add(CollectionService:GetInstanceAddedSignal(Enums.Tag.IntelSpawn):Connect(trackStation))
	janitor:Add(CollectionService:GetInstanceRemovedSignal(Enums.Tag.IntelSpawn):Connect(untrackStation))
	for _, instance in CollectionService:GetTagged(Enums.Tag.IntelSpawn) do
		trackStation(instance)
	end
	local function trackGlow(instance: Instance)
		if instance:IsA("BasePart") then
			glows[instance] = instance.Transparency
		end
	end
	janitor:Add(CollectionService:GetInstanceAddedSignal(Enums.Tag.IntelGlow):Connect(trackGlow))
	janitor:Add(CollectionService:GetInstanceRemovedSignal(Enums.Tag.IntelGlow):Connect(function(instance)
		glows[instance :: BasePart] = nil
	end))
	for _, instance in CollectionService:GetTagged(Enums.Tag.IntelGlow) do
		trackGlow(instance)
	end

	janitor:Add(RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local now = os.clock()
		local origin = camera.CFrame.Position
		for station, marker in markers do
			local live = station.Parent ~= nil and IntelController.stationLive(station)
			marker.gui.Enabled = live
			if live then
				local away = (station.Position - origin).Magnitude
				local fade = math.clamp(
					(away - config.MarkerFadeFromStuds) / math.max(1, config.MarkerRange - config.MarkerFadeFromStuds),
					0,
					1
				)
				marker.diamond.BackgroundTransparency = fade
				marker.label.TextTransparency = fade
				local bob = math.sin(now * math.pi * 2 / config.MarkerBobSeconds) * config.MarkerBobStuds
				marker.gui.StudsOffset = Vector3.new(0, config.MarkerLiftStuds + bob, 0)
			end
		end
		-- The pad and screen pulse together.
		local wave = (math.sin(now * math.pi * 2 / config.PulseSeconds) + 1) / 2
		for part, base in glows do
			part.Transparency = math.clamp(base + wave * config.PulseDepth, 0, 1)
		end
	end))
	janitor:Add(function()
		for _, marker in markers do
			marker.gui:Destroy()
		end
		table.clear(markers)
		for part, base in glows do
			part.Transparency = base
		end
		table.clear(glows)
	end)
	janitor:Add(script.Destroying:Connect(function()
		janitor:Destroy()
	end))
end

return IntelMarkerController
