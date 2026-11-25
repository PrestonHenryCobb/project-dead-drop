--!strict
-- Makes Intel stations unmistakable (owner 2026-11-25): a gold diamond marker floats over every station that can still be taken, with the points it is
-- worth, and the station's pad and screens pulse. Once your team has taken it the pulse stops and the glow stays on, steady. The marker is an ordinary billboard, so walls hide it: it shows what line of sight already shows. It
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
local glows: { [BasePart]: { base: number, group: number? } } = {} -- each glowing part, the transparency it was built with and its station's GlowGroup
local stationByGroup: { [number]: BasePart } = {}

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
			local group = instance:GetAttribute("GlowGroup")
			if type(group) == "number" then
				stationByGroup[group] = instance
			end
		end
	end
	local function untrackStation(instance: Instance)
		local marker = markers[instance :: BasePart]
		if marker then
			marker.gui:Destroy()
			markers[instance :: BasePart] = nil
		end
		local group = instance:GetAttribute("GlowGroup")
		if type(group) == "number" and stationByGroup[group] == instance then
			stationByGroup[group] = nil
		end
	end
	janitor:Add(CollectionService:GetInstanceAddedSignal(Enums.Tag.IntelSpawn):Connect(trackStation))
	janitor:Add(CollectionService:GetInstanceRemovedSignal(Enums.Tag.IntelSpawn):Connect(untrackStation))
	for _, instance in CollectionService:GetTagged(Enums.Tag.IntelSpawn) do
		trackStation(instance)
	end
	local function trackGlow(instance: Instance)
		if instance:IsA("BasePart") then
			local group = instance:GetAttribute("GlowGroup")
			glows[instance] = { base = instance.Transparency, group = if type(group) == "number" then group else nil }
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
		-- The pad and screens of a station that can still be taken pulse together; once it has been taken they stop and glow steadily.
		local wave = (math.sin(now * math.pi * 2 / config.PulseSeconds) + 1) / 2
		for part, info in glows do
			local station = if info.group then stationByGroup[info.group] else nil
			local live = station ~= nil and IntelController.stationLive(station)
			local offset = if live then wave * config.PulseDepth else config.CollectedGlowTransparency
			part.Transparency = math.clamp(info.base + offset, 0, 1)
		end
	end))
	janitor:Add(function()
		for _, marker in markers do
			marker.gui:Destroy()
		end
		table.clear(markers)
		for part, info in glows do
			part.Transparency = info.base
		end
		table.clear(glows)
		table.clear(stationByGroup)
	end)
	janitor:Add(script.Destroying:Connect(function()
		janitor:Destroy()
	end))
end

return IntelMarkerController
