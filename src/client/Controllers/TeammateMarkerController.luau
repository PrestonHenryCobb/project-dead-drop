--!strict
-- Ticket 10c: only the private TeamRoster authorizes a marker. No character is decorated or queried for identity.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)
local Types = require(Shared.Types)
local Janitor = require(Shared.Util.Janitor)
local RemoteController = require(script.Parent.RemoteController)
local Floors = require(script.Parent.FloorMarkerController)
local TeammateMarkerController = {}
local janitor = Janitor.new()
local config = GameConfig.MatchHud
type Marker = { diamond: Frame, gui: BillboardGui, outline: Highlight, floor: TextLabel }
local markers: { [Player]: Marker } = {}
local active = not GameConfig.Debug.MenuOnJoin

local function remove(player: Player)
	local marker = markers[player]
	if marker then
		marker.gui:Destroy()
		marker.outline:Destroy()
		markers[player] = nil
	end
end

function TeammateMarkerController.Init() end

function TeammateMarkerController.Start()
	local folder = Instance.new("Folder")
	folder.Name = "PrivateTeamMarkers"
	folder.Parent = workspace
	janitor:Add(folder)
	local function onRoster(info: Types.TeamRosterInfo)
		local permitted: { [Player]: boolean } = {}
		local teamColor = GameConfig.Lobby.TeamColors[info.TeamId]
		if teamColor then
			for _, member in info.Members do
				if member ~= Players.LocalPlayer then
					permitted[member] = true
				end
			end
		end
		for member in markers do
			if not permitted[member] then
				remove(member)
			end
		end
		if not teamColor then
			return
		end
		for member in permitted do
			local marker = markers[member]
			if not marker then
				local gui = Instance.new("BillboardGui")
				gui.Name = "Teammate"
				gui.AlwaysOnTop = true
				gui.Enabled = false
				gui.Size = UDim2.fromOffset(config.MarkerSizePixels * 4, config.MarkerSizePixels * 3)
				gui.StudsOffsetWorldSpace = Vector3.new(0, config.MarkerHeightStuds, 0)
				gui.Parent = folder
				local diamond = Instance.new("Frame")
				diamond.AnchorPoint = Vector2.new(0.5, 0.5)
				diamond.Position = UDim2.fromScale(0.5, 1 / 3)
				diamond.Size = UDim2.fromOffset(config.MarkerSizePixels, config.MarkerSizePixels)
				diamond.Rotation = 45
				diamond.BorderSizePixel = 0
				diamond.Parent = gui
				local floor = Instance.new("TextLabel")
				floor.Name = "FloorHint"
				floor.AnchorPoint = Vector2.new(0.5, 1)
				floor.Position = UDim2.fromScale(0.5, 1)
				floor.Size = UDim2.new(1, 0, 0, config.BodySize)
				floor.BackgroundTransparency = 1
				floor.Font = GameConfig.UI.Font
				floor.TextSize = config.BodySize
				floor.TextStrokeTransparency = 0.5
				floor.Visible = false
				floor.Parent = gui
				local outline = Instance.new("Highlight")
				outline.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				outline.Enabled = false
				outline.FillTransparency = config.MarkerFillTransparency
				outline.OutlineTransparency = config.MarkerOutlineTransparency
				outline.Parent = folder
				marker = { diamond = diamond, gui = gui, outline = outline, floor = floor }
				markers[member] = marker
			end
			marker.diamond.BackgroundColor3 = teamColor.Color
			marker.floor.TextColor3 = teamColor.Color
			marker.outline.FillColor, marker.outline.OutlineColor = teamColor.Color, teamColor.Color
		end
	end
	janitor:Add(RemoteController.connect("TeamRoster", onRoster))
	janitor:Add(RemoteController.connect("PhaseChanged", function(phase: Types.Phase)
		active = phase ~= "Lobby" and phase ~= "Results"
	end))
	janitor:Add(Players.PlayerRemoving:Connect(remove))
	janitor:Add(RunService.RenderStepped:Connect(function()
		for member, marker in markers do
			local character = member.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local visible = active and humanoid ~= nil and humanoid.Health > 0 and root ~= nil and root:IsA("BasePart")
			marker.gui.Enabled, marker.outline.Enabled = visible, visible
			marker.gui.Adornee = if visible then root :: BasePart else nil
			marker.outline.Adornee = if visible then character else nil
			local hint = if visible then Floors.hint((root :: BasePart).Position) else ""
			marker.floor.Text = hint
			marker.floor.Visible = hint ~= ""
		end
	end))
	janitor:Add(function()
		table.clear(markers)
	end)
	janitor:Add(script.Destroying:Connect(function()
		janitor:Destroy()
	end))
end

return TeammateMarkerController
