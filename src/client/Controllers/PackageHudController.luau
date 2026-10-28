--!strict
-- Tickets 13b/c: draw per-player PackageState; never infer a carrier from other characters or hold a pulse open.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)
local Janitor = require(Shared.Util.Janitor)
local HudKit = require(Shared.Util.HudKit)
local HudTheme = require(Shared.Util.HudTheme)
local Accessibility = require(Shared.Util.UiAccessibility)
local Presentation = require(script.Parent.Parent.Combat.PackagePresentation)
local Aircraft = require(script.Parent.Parent.Combat.ExtractionAircraft)
local Clock = require(script.Parent.Parent.Combat.MatchPresentation)
local RemoteController = require(script.Parent.RemoteController)
local Floors = require(script.Parent.FloorMarkerController)
local PackageHudController = {}
local janitor = Janitor.new()
local state = Presentation.new()
local theme = HudTheme.get()
local config = GameConfig.MatchHud
local visual = GameConfig.ExtractionVisuals

function PackageHudController.Init() end

function PackageHudController.Start()
	local gui = HudKit.screen("PackageHud")
	gui.DisplayOrder = visual.DisplayOrder
	janitor:Add(gui)
	local function text(parent: Instance, name: string, y: number, height: number, size: number)
		local label = HudKit.text(
			parent,
			name,
			UDim2.fromOffset(theme.PaddingPixels, y),
			Vector2.zero,
			UDim2.new(1, -theme.PaddingPixels * 2, 0, height)
		)
		label.TextSize = size
		label.RichText = false
		return label
	end
	local panel = HudKit.panel(
		gui,
		"PackageStatus",
		UDim2.new(1, -theme.MarginPixels, 0, theme.MarginPixels),
		Vector2.new(1, 0),
		UDim2.fromOffset(theme.CoverWidthPixels, theme.CoverHeightPixels)
	)
	local panelRoot = panel.Parent :: Frame
	panelRoot.Visible = false
	local status = text(panel, "Status", theme.PaddingPixels, config.BodySize, config.BodySize)
	local hint = text(
		panel,
		"Hint",
		theme.CoverHeightPixels - theme.PaddingPixels - theme.CaptionSize,
		theme.CaptionSize,
		theme.CaptionSize
	)
	local extractionPanel = HudKit.panel(
		gui,
		"ExtractionStatus",
		UDim2.new(1, -theme.MarginPixels, 0, theme.MarginPixels + theme.CoverHeightPixels + theme.PaddingPixels),
		Vector2.new(1, 0),
		UDim2.fromOffset(theme.CoverWidthPixels, theme.CoverHeightPixels)
	)
	local extractionRoot = extractionPanel.Parent :: Frame
	extractionRoot.Visible = false
	local extractionText =
		text(extractionPanel, "ExtractionCountdown", theme.PaddingPixels, config.BodySize, config.BodySize)
	local extractionHint = text(
		extractionPanel,
		"Team",
		theme.CoverHeightPixels - theme.PaddingPixels - theme.CaptionSize,
		theme.CaptionSize,
		theme.CaptionSize
	)
	local hold = HudKit.panel(
		gui,
		"ObjectiveHold",
		UDim2.new(0.5, 0, 0.5, theme.ActionOffsetPixels),
		Vector2.new(0.5, 0),
		UDim2.fromOffset(theme.ActionWidthPixels, theme.ActionHeightPixels)
	)
	local holdRoot = hold.Parent :: Frame
	holdRoot.Visible = false
	local holdText = text(hold, "Action", theme.PaddingPixels, config.BodySize, config.BodySize)
	local fill = Instance.new("Frame")
	fill.BorderSizePixel = 0
	fill.BackgroundColor3 = theme.AccentColor
	fill.Position = UDim2.new(0, theme.PaddingPixels, 1, -theme.PaddingPixels)
	fill.Parent = hold
	local folder = Instance.new("Folder")
	folder.Name = "PackagePresentation"
	folder.Parent = workspace
	janitor:Add(folder)
	local function marker(name: string)
		local point = Instance.new("Part")
		point.Name = name
		point.Anchored = true
		point.CanCollide, point.CanQuery, point.CanTouch = false, false, false
		point.Transparency = 1
		point.Parent = folder
		local billboard = Instance.new("BillboardGui")
		billboard.Name = name .. "Marker"
		billboard.Adornee = point
		billboard.AlwaysOnTop = true
		billboard.Enabled = false
		billboard.Size = UDim2.fromOffset(config.TimerWidthPixels, config.TimerHeightPixels)
		billboard.StudsOffsetWorldSpace = Vector3.new(0, config.MarkerHeightStuds, 0)
		billboard.Parent = folder
		local caption = HudKit.text(billboard, "Caption", UDim2.new(), Vector2.zero, UDim2.fromScale(1, 1))
		caption.TextSize = config.BodySize
		caption.TextColor3 = theme.AccentColor
		caption.Text = name
		return { point = point, gui = billboard, caption = caption }
	end
	local packageMarker = marker("Package")
	local extractionMarker = marker("Extraction")
	local aircraft = Aircraft.new(folder)
	local shade = Instance.new("Frame")
	shade.Name = "ExtractionFade"
	shade.Size = UDim2.fromScale(1, 1)
	shade.BackgroundColor3 = Color3.new(0, 0, 0)
	shade.BorderSizePixel = 0
	shade.Visible = false
	shade.ZIndex = 3
	shade.Parent = gui
	local cinemaText = HudKit.text(
		shade,
		"ExtractionResult",
		UDim2.fromScale(0.5, 0.5),
		Vector2.new(0.5, 0.5),
		UDim2.fromOffset(config.PanelWidthPixels, config.TitleSize * 3)
	)
	cinemaText.TextSize = config.TitleSize
	cinemaText.TextWrapped = true
	cinemaText.RichText = false
	for _, bottom in { false, true } do
		local bar = Instance.new("Frame")
		bar.Size = UDim2.fromScale(1, visual.LetterboxFraction)
		bar.AnchorPoint = Vector2.new(0, if bottom then 1 else 0)
		bar.Position = UDim2.fromScale(0, if bottom then 1 else 0)
		bar.BackgroundColor3 = Color3.new(0, 0, 0)
		bar.BorderSizePixel = 0
		bar.Parent = shade
	end
	janitor:Add(RemoteController.connect("PhaseChanged", state.phase))
	janitor:Add(RemoteController.connect("PackageState", state.package))
	janitor:Add(RemoteController.connect("ExtractionState", function(info)
		state.extraction(info, workspace:GetServerTimeNow())
	end))
	janitor:Add(RemoteController.connect("InteractState", function(info)
		state.interaction(info, os.clock())
	end))
	janitor:Add(RunService.RenderStepped:Connect(function()
		local now = workspace:GetServerTimeNow()
		local view = state.view(now, os.clock())
		local package = view.package
		panelRoot.Visible = package ~= nil and package.State ~= "Hidden"
		status.Text = if package and package.YouCarry
			then "YOU HAVE THE PACKAGE"
			elseif package and package.TeamCarries then "TEAM HAS THE PACKAGE"
			elseif package and package.State == "Carried" then "RIVAL HAS THE PACKAGE"
			elseif package and package.State == "Dropped" then "PACKAGE DROPPED"
			else "PACKAGE AVAILABLE"
		hint.Text = if package and package.YouCarry
			then `[ {GameConfig.Controls.DropPackage.Name} ] DROP PACKAGE`
			elseif package and package.ReturnsAt then `RETURNS IN {Clock.clock(package.ReturnsAt, now)}`
			else "TAKE THE PACKAGE AND EXTRACT"
		packageMarker.gui.Enabled = view.point ~= nil
		if view.point then
			packageMarker.point.Position = view.point
			packageMarker.caption.Text = if package and package.State == "Carried"
				then "◇ CARRIER PING"
				else "◇ PACKAGE"
			local floor = Floors.hint(view.point)
			if floor ~= "" then
				packageMarker.caption.Text ..= "\n" .. floor
			end
		end
		local extraction = view.extraction
		extractionRoot.Visible = extraction ~= nil and extraction.State ~= "Idle"
		extractionText.Text = if extraction
			then `{string.upper(extraction.State)} · {if extraction.State == "Extracted"
				then "COMPLETE"
				else Clock.clock(extraction.EndsAt, now)}`
			else ""
		extractionHint.Text = if extraction and extraction.ByYourTeam
			then "YOUR TEAM'S EXTRACTION"
			else "RIVAL EXTRACTION"
		extractionMarker.gui.Enabled = extraction ~= nil
			and extraction.Position ~= nil
			and extraction.State ~= "Idle"
			and extraction.State ~= "Extracted"
		if extraction and extraction.Position then
			extractionMarker.point.Position = extraction.Position
			local floor = Floors.hint(extraction.Position)
			extractionMarker.caption.Text = `◇ EXTRACTION{if floor ~= "" then "\n" .. floor else ""}`
		end
		holdRoot.Visible = view.holdLabel ~= nil
		holdText.Text = view.holdLabel or ""
		fill.Size = UDim2.new(view.holdProgress, -theme.PaddingPixels * 2 * view.holdProgress, 0, theme.ReloadBarPixels)
		aircraft.update(
			if extraction then extraction.Position else nil,
			if extraction then extraction.State else nil,
			now,
			view.cinematicProgress
		)
		shade.Visible = view.cinematic
		shade.BackgroundTransparency = if Accessibility.reducedMotion() then 1 else 1 - view.cinematicProgress
		cinemaText.Text = if extraction and extraction.ByYourTeam then "MISSION SUCCESS" else "EXTRACTION COMPLETE"
	end))
	janitor:Add(script.Destroying:Connect(function()
		janitor:Destroy()
	end))
end

return PackageHudController
