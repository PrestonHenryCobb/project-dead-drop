--!strict
-- GPS routes and private carrier marks consume server data; never decorate or identify actors.
local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)
local Enums = require(Shared.Enums)
local Types = require(Shared.Types)
local Janitor = require(Shared.Util.Janitor)
local HudKit = require(Shared.Util.HudKit)
local HudTheme = require(Shared.Util.HudTheme)
local Presentation = require(script.Parent.Parent.Combat.RoutePresentation)
local RouteMap = require(script.Parent.Parent.Combat.RouteMap)
local RouteArrows = require(script.Parent.Parent.Combat.RouteArrows)
local FloorBands = require(script.Parent.Parent.Combat.FloorBands)
local Remote = require(script.Parent.RemoteController)
local CarrierTrack = require(script.Parent.CarrierTrackController)
local RouteHudController = {}

function RouteHudController.Init() end

function RouteHudController.Start()
	local janitor = Janitor.new()
	local config = GameConfig.RouteHud
	local theme = HudTheme.get()
	local player = Players.LocalPlayer
	local bands = FloorBands.new()
	local state = Presentation.new()
	local zones: { [BasePart]: boolean } = {}
	local mode = "Clean"
	local phase: Types.Phase = "Lobby"
	local unavailable = false
	local shown = true
	local browsing: string? = nil
	local inFlight = false
	local alive = true
	local nextRequest = 0
	local gui = HudKit.screen("RouteHud")
	janitor:Add(gui)
	local rowHeight = theme.CaptionSize + theme.PaddingPixels * 2
	local height = config.MapPixels
		+ config.SummaryPixels
		+ config.StepsPixels
		+ rowHeight * 4
		+ theme.PaddingPixels * 4
	local panel = HudKit.panel(
		gui,
		"RoutePanel",
		UDim2.fromOffset(theme.MarginPixels, config.TopPixels),
		Vector2.zero,
		UDim2.fromOffset(config.WidthPixels, height)
	)
	local panelRoot = panel.Parent :: Frame
	panelRoot.Visible = false
	local function text(name: string, y: number, h: number): TextLabel
		local label = HudKit.text(
			panel,
			name,
			UDim2.fromOffset(theme.PaddingPixels, y),
			Vector2.zero,
			UDim2.new(1, -theme.PaddingPixels * 2, 0, h)
		)
		label.TextSize = theme.CaptionSize
		label.TextWrapped = true
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Top
		label.RichText = false
		return label
	end
	local title = text("RouteTitle", theme.PaddingPixels, theme.CaptionSize)
	title.Text = "GPS · NORTH UP"
	local function button(name: string, y: number, callback: () -> ()): TextButton
		local item = Instance.new("TextButton")
		item.Name = name
		item.Font = theme.Font
		item.TextSize = theme.CaptionSize
		item.TextColor3 = theme.TextColor
		item.BackgroundColor3 = theme.PanelColor
		item.BackgroundTransparency = theme.PanelTransparency
		item.TextWrapped = true
		item.Size = UDim2.new(1, -theme.PaddingPixels * 2, 0, rowHeight)
		item.Position = UDim2.fromOffset(theme.PaddingPixels, y)
		item.Parent = panel
		janitor:Add(item.Activated:Connect(callback))
		return item
	end
	local function cycle()
		state.cycle()
	end
	local target = button("NextRouteTarget", theme.PaddingPixels * 2 + theme.CaptionSize, cycle)
	local function switch()
		mode = if mode == "Clean" then "Fast" else "Clean"
	end
	local choice = button("RouteMode", theme.PaddingPixels * 2 + theme.CaptionSize + rowHeight, switch)
	local floorY = theme.PaddingPixels * 2 + theme.CaptionSize + rowHeight * 2
	local floorLabel = text("MapFloor", floorY, rowHeight)
	local map = Instance.new("Frame")
	map.Name = "FloorPlan"
	map.BorderSizePixel = 0
	map.BackgroundColor3 = theme.PanelColor
	map.BackgroundTransparency = theme.PanelTransparency
	map.ClipsDescendants = true
	map.Position = UDim2.fromOffset((config.WidthPixels - config.MapPixels) / 2, floorY + rowHeight)
	map.Size = UDim2.fromOffset(config.MapPixels, config.MapPixels)
	map.Parent = panel
	local renderer = RouteMap.new(map)
	local arrows = RouteArrows.new()
	janitor:Add(renderer)
	janitor:Add(arrows)
	local summaryY = floorY + rowHeight + config.MapPixels + theme.PaddingPixels
	local summary = text("RouteSummary", summaryY, config.SummaryPixels)
	local steps = Instance.new("ScrollingFrame")
	steps.Name = "RouteSteps"
	steps.BackgroundTransparency = 1
	steps.BorderSizePixel = 0
	steps.Position = UDim2.fromOffset(theme.PaddingPixels, summaryY + config.SummaryPixels)
	steps.Size = UDim2.new(1, -theme.PaddingPixels * 2, 0, config.StepsPixels)
	steps.CanvasSize = UDim2.new()
	steps.AutomaticCanvasSize = Enum.AutomaticSize.Y
	steps.ScrollBarThickness = theme.ReloadBarPixels
	steps.Parent = panel
	local flags = Instance.new("TextLabel")
	flags.Name = "StepDescriptions"
	flags.Size = UDim2.fromScale(1, 0)
	flags.AutomaticSize = Enum.AutomaticSize.Y
	flags.BackgroundTransparency = 1
	flags.Font = theme.Font
	flags.TextSize = theme.CaptionSize
	flags.TextColor3 = theme.TextColor
	flags.TextWrapped = true
	flags.RichText = false
	flags.TextXAlignment = Enum.TextXAlignment.Left
	flags.Parent = steps
	local footer = text("RouteHelp", summaryY + config.SummaryPixels + config.StepsPixels, rowHeight)
	footer.Text =
		`[ {config.MapKey.Name} / {config.MapPad.Name} ] Map · [ {config.FloorUpKey.Name} / {config.FloorDownKey.Name} ] Floor`
	local function active(): boolean
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		return alive
			and gui.Enabled
			and not unavailable
			and humanoid ~= nil
			and humanoid.Health > 0
			and (phase == "Infiltration" or phase == "VaultBreach" or phase == "PackageHeist" or phase == "Overtime")
	end
	local function clear()
		state.clear()
		browsing = nil
		panelRoot.Visible = false
		arrows.hide()
		nextRequest = 0
	end
	local function add(instance: Instance)
		if instance:IsA("BasePart") then
			zones[instance] = true
			bands.add(instance)
		end
	end
	local function remove(instance: Instance)
		if instance:IsA("BasePart") then
			zones[instance] = nil
		end
		bands.remove(instance)
	end
	for _, instance in CollectionService:GetTagged(Enums.Tag.ZoneVolume) do
		add(instance)
	end
	janitor:Add(CollectionService:GetInstanceAddedSignal(Enums.Tag.ZoneVolume):Connect(add))
	janitor:Add(CollectionService:GetInstanceRemovedSignal(Enums.Tag.ZoneVolume):Connect(remove))
	local function floors(): { { Name: string, Height: number } }
		local list = {}
		local seen: { [string]: boolean } = {}
		for zone in zones do
			local name = bands.nameAt(zone.Position.Y)
			if name and not seen[name] then
				seen[name] = true
				table.insert(list, { Name = name, Height = zone.Position.Y })
			end
		end
		table.sort(list, function(a, b)
			return a.Height < b.Height
		end)
		return list
	end
	local function changeFloor(direction: number)
		local list = floors()
		if #list == 0 then
			return
		end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local here = if root and root:IsA("BasePart") then bands.nameAt(root.Position.Y) else nil
		local index = 1
		for i, entry in list do
			if entry.Name == (browsing or here) then
				index = i
				break
			end
		end
		local selected = list[(index - 1 + direction) % #list + 1].Name
		browsing = if selected == here then nil else selected
	end
	local function bind(name: string, key: Enum.KeyCode, callback: () -> ())
		ContextActionService:BindAction(name, function(_, input)
			if input ~= Enum.UserInputState.Begin or not active() or UserInputService:GetFocusedTextBox() then
				return Enum.ContextActionResult.Pass
			end
			callback()
			return Enum.ContextActionResult.Sink
		end, false, key)
		janitor:Add(function()
			ContextActionService:UnbindAction(name)
		end)
	end
	bind("RouteToggleMap", config.MapKey, function()
		shown = not shown
	end)
	bind("RouteNextTarget", config.TargetKey, cycle)
	bind("RouteSwitchMode", config.ModeKey, switch)
	bind("RouteFloorUp", config.FloorUpKey, function()
		changeFloor(1)
	end)
	bind("RouteFloorDown", config.FloorDownKey, function()
		changeFloor(-1)
	end)
	bind("RouteToggleMapPad", config.MapPad, function()
		shown = not shown
	end)
	bind("RouteNextTargetPad", config.TargetPad, function()
		if shown then
			cycle()
		end
	end)
	bind("RouteSwitchModePad", config.ModePad, function()
		if shown then
			switch()
		end
	end)
	janitor:Add(Remote.connect("PhaseChanged", function(value: Types.Phase)
		phase = value
		clear()
		if value == "Lobby" or value == "Insertion" then
			unavailable = false
		end
	end))
	for _, name in { "Downed", "Eliminated" } do
		janitor:Add(Remote.connect(name, function()
			unavailable = true
			clear()
		end))
	end
	janitor:Add(Remote.connect("Revived", function()
		unavailable = false
	end))
	janitor:Add(Remote.connect("ExtractionState", function(info: Types.ExtractionStateInfo)
		if info.State == "Extracted" then
			unavailable = true
			clear()
		end
	end))
	janitor:Add(player.CharacterAdded:Connect(function()
		unavailable = false
		clear()
	end))
	local elapsed = 0
	local drawnResult: Types.RouteResult? = nil
	local drawnFloor: string? = nil
	local drawnMode = ""
	local drawnMarks = -1
	local zonesVersion, drawnZones = 0, -1
	janitor:Add(CollectionService:GetInstanceAddedSignal(Enums.Tag.ZoneVolume):Connect(function()
		zonesVersion += 1
	end))
	janitor:Add(CollectionService:GetInstanceRemovedSignal(Enums.Tag.ZoneVolume):Connect(function()
		zonesVersion += 1
	end))
	janitor:Add(RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < config.RefreshSeconds then
			return
		end
		elapsed = 0
		if not active() then
			if state.result() then
				clear()
			end
			panelRoot.Visible = false
			arrows.hide()
			renderer.marks({})
			drawnMarks = -1
			return
		end
		if not inFlight and os.clock() >= nextRequest then
			inFlight = true
			nextRequest = os.clock() + config.RequestSeconds
			local revision, selected = state.revision(), state.selected()
			task.spawn(function()
				local ok, value = pcall(Remote.invoke, "RequestRoute", selected)
				inFlight = false
				if not alive or not active() then
					return
				end
				state.apply(if ok and type(value) == "table" then value :: Types.RouteResult else nil, revision)
			end)
		end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then
			panelRoot.Visible = false
			arrows.hide()
			renderer.marks({})
			drawnMarks = -1
			return
		end
		local here = bands.nameAt(root.Position.Y)
		local floor = browsing or here
		local result = state.result()
		local selectedName = "No revealed target"
		if result then
			for _, entry in result.Targets do
				if entry.Id == state.selected() then
					selectedName = entry.Name
					break
				end
			end
		end
		target.Text = `[ {config.TargetKey.Name} / LB ] {selectedName}`
		choice.Text = `[ {config.ModeKey.Name} / RB ] {string.upper(mode)} ROUTE · switch`
		choice.TextColor3 = if mode == "Clean" then config.CleanColor else config.FastColor
		floorLabel.Text = `FLOOR · {floor or "Unknown"}{if browsing then " · browsing" else " · current"}`
		local route = if result then (if mode == "Clean" then result.Clean else result.Fast) else nil
		summary.Text = if result
			then `{Presentation.summary("Clean", result.Clean)}\n{Presentation.summary("Fast", result.Fast)}\nTEAM INTEL · {result.Intel}`
			else "Waiting for route data"
		local descriptions = {}
		if route then
			for index, step in route.Steps do
				table.insert(descriptions, `{index}. {Presentation.step(step)}`)
			end
		end
		flags.Text = if #descriptions > 0 then table.concat(descriptions, "\n") else "No flagged steps"
		panelRoot.Visible = shown
		if
			shown and (drawnResult ~= result or drawnFloor ~= floor or drawnMode ~= mode or drawnZones ~= zonesVersion)
		then
			local visibleZones = {}
			for zone in zones do
				table.insert(visibleZones, zone)
			end
			renderer.draw(visibleZones, floor, bands.nameAt, result, mode, root.Position)
			drawnResult, drawnFloor, drawnMode, drawnZones = result, floor, mode, zonesVersion
			drawnMarks = -1
		end
		local trackedMarks, marksRevision = CarrierTrack.marks()
		if shown and drawnMarks ~= marksRevision then
			renderer.marks(trackedMarks)
			drawnMarks = marksRevision
		end
		arrows.update(
			route,
			root.Position,
			here,
			bands.nameAt,
			if mode == "Clean" then config.CleanColor else config.FastColor
		)
	end))
	janitor:Add(function()
		alive = false
		state.clear()
		bands.clear()
	end)
	janitor:Add(script.Destroying:Connect(function()
		janitor:Destroy()
	end))
end

return RouteHudController
