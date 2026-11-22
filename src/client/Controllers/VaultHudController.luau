--!strict
-- Ticket 12b. Only the server's revealed terminal snapshots may populate these bars/markers.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)
local Janitor = require(Shared.Util.Janitor)
local HudKit = require(Shared.Util.HudKit)
local HudTheme = require(Shared.Util.HudTheme)
local Graphic = require(script.Parent.Parent.Combat.VaultProgressGraphic)
local Presentation = require(script.Parent.Parent.Combat.ObjectivePresentation)
local RemoteController = require(script.Parent.RemoteController)
local Floors = require(script.Parent.FloorMarkerController)
local VaultHudController = {}
local janitor = Janitor.new()
local state = Presentation.new()
local config = GameConfig.MatchHud
local theme = HudTheme.get()
type Slot = { graphic: Graphic.View, point: BasePart, marker: BillboardGui, caption: TextLabel }
local slots: { Slot } = {}

function VaultHudController.Init() end

function VaultHudController.Start()
	local gui = HudKit.screen("VaultHud")
	janitor:Add(gui)
	local graphic = GameConfig.UI.VaultGraphic
	local panel = HudKit.panel(
		gui,
		"VaultProgress",
		UDim2.new(0.5, 0, 0, config.TimerTopPixels + GameConfig.UI.FloatingHud.WatchPixels + graphic.TopGapPixels),
		Vector2.new(0.5, 0),
		UDim2.fromOffset(GameConfig.Vault.ActiveVaults * graphic.CellWidthPixels, graphic.HeightPixels)
	)
	local panelRoot = panel.Parent :: Frame
	panelRoot.Visible = false
	local folder = Instance.new("Folder")
	folder.Name = "RevealedVaultMarkers"
	folder.Parent = workspace
	janitor:Add(folder)
	for index = 1, GameConfig.Vault.ActiveVaults do
		local dial = Graphic.new(panel, index, GameConfig.Vault.ActiveVaults)
		local point = Instance.new("Part")
		point.Name = "RevealedTerminal"
		point.Anchored = true
		point.CanCollide, point.CanTouch, point.CanQuery = false, false, false
		point.Transparency = 1
		point.Parent = folder
		local marker = Instance.new("BillboardGui")
		marker.Name = "VaultMarker"
		marker.Adornee = point
		marker.Enabled = false
		marker.AlwaysOnTop = true
		marker.Size = UDim2.fromOffset(config.TimerWidthPixels, config.TimerHeightPixels)
		marker.StudsOffsetWorldSpace = Vector3.new(0, config.MarkerHeightStuds, 0)
		marker.Parent = folder
		local caption = HudKit.text(marker, "Vault", UDim2.fromScale(0, 0), Vector2.zero, UDim2.fromScale(1, 1))
		caption.TextSize = config.BodySize
		caption.RichText = false
		table.insert(slots, { graphic = dial, point = point, marker = marker, caption = caption })
	end
	janitor:Add(RemoteController.connect("PhaseChanged", state.phase))
	janitor:Add(RemoteController.connect("VaultProgress", state.vault))
	janitor:Add(RunService.RenderStepped:Connect(function()
		local view = state.view(workspace:GetServerTimeNow(), os.clock())
		panelRoot.Visible = view.showVaultBars
		for index, slot in slots do
			local terminal = view.terminals[index]
			slot.graphic.update(terminal)
			slot.marker.Enabled = terminal ~= nil and not terminal.Hacked
			if terminal then
				local color = if terminal.Contested then GameConfig.UI.WarningColor else theme.AccentColor
				slot.point.Position = terminal.Position
				local floor = Floors.hint(terminal.Position)
				slot.caption.Text = `◇ VAULT {terminal.VaultId}{if floor ~= "" then "\n" .. floor else ""}`
				slot.caption.TextColor3 = color
			end
		end
	end))
	janitor:Add(function()
		table.clear(slots)
	end)
	janitor:Add(script.Destroying:Connect(function()
		janitor:Destroy()
	end))
end

return VaultHudController
