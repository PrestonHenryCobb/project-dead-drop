--!strict
-- GPS routes and private carrier marks consume server data; never decorate or identify actors.
local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
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
local HeldItemController = require(script.Parent.HeldItemController)
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
	local zoneWatches: { [BasePart]: Janitor.Janitor } = {}
	local zonesVersion = 0
	local mode = "Clean"
	local phase: Types.Phase = "Lobby"
	local unavailable = false
	local view = "Mini" -- "Mini" (a small corner plan, the default), "Full" (the whole GPS panel) or "Off"
	local circle = false -- the minimap is round instead of square
	local planPixels = config.MapPixels -- the side of the plan the renderer draws into; the minimap draws a bigger one
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
		janitor:Add(item.Activated:Connect(function()
			if gui.Enabled and not HeldItemController.isInputBlocked() then
				callback()
			end
		end))
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
	local canvas = Instance.new("Frame") -- the plan itself; the minimap slides it inside the clipped window so you stay centred
	canvas.Name = "Plan"
	canvas.BackgroundTransparency = 1
	canvas.BorderSizePixel = 0
	canvas.Size = UDim2.fromOffset(config.MapPixels, config.MapPixels)
	canvas.Parent = map
	local renderer = RouteMap.new(canvas, function()
		return planPixels
	end)
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
		`[ {config.MapKey.Name} / {config.MapPad.Name} ] Map size · [ {config.ShapeKey.Name} ] Round or square · [ {config.FloorUpKey.Name} / {config.FloorDownKey.Name} ] Floor`
	local detail: { GuiObject } = { title, target, choice, floorLabel, summary, steps, footer }
	local fullMapPosition = map.Position
	local backdropCorner = panel:FindFirstChildOfClass("UICorner")
	local shadow = panelRoot:FindFirstChild("Shadow")
	local shadowCorner = if shadow then shadow:FindFirstChildOfClass("UICorner") else nil
	local squareRadius = if backdropCorner then backdropCorner.CornerRadius else UDim.new(0, 0)
	local miniInner = config.MiniPixels
	local drawnLayout = "" -- which view and shape the plan on screen was drawn for
	local function setRadius(radius: UDim)
		if backdropCorner then
			backdropCorner.CornerRadius = radius
		end
		if shadowCorner then
			shadowCorner.CornerRadius = radius
		end
	end
	-- Lays the panel out for the current view: the small plan alone (a circle shows the square plan inscribed in it, so nothing
	-- pokes out of the corners), the whole GPS panel, or nothing (Visible is set where the route is refreshed).
	local function applyView()
		local full = view == "Full"
		for _, item in detail do
			item.Visible = full
		end
		if full then
			panelRoot.Size = UDim2.fromOffset(config.WidthPixels, height)
			map.Position = fullMapPosition
			map.Size = UDim2.fromOffset(config.MapPixels, config.MapPixels)
			planPixels = config.MapPixels
			canvas.Position = UDim2.new()
			setRadius(squareRadius)
		else
			local box = config.MiniPixels
			local pad = theme.PaddingPixels
			panelRoot.Size = UDim2.fromOffset(box + pad * 2, box + pad * 2)
			miniInner = if circle then math.floor(box / math.sqrt(2)) else box
			local inset = pad + (box - miniInner) / 2
			map.Position = UDim2.fromOffset(inset, inset)
			map.Size = UDim2.fromOffset(miniInner, miniInner)
			planPixels = config.MiniZoomPixels
			setRadius(if circle then UDim.new(0.5, 0) else squareRadius)
		end
		canvas.Size = UDim2.fromOffset(planPixels, planPixels)
	end
	applyView()
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
			if zones[instance] then
				return
			end
			zones[instance] = true
			bands.add(instance)
			zonesVersion += 1
			local watch = Janitor.new()
			zoneWatches[instance] = watch
			local function geometryChanged()
				bands.add(instance)
				zonesVersion += 1
			end
			for _, property in { "CFrame", "Size", "Name" } do
				watch:Add(instance:GetPropertyChangedSignal(property):Connect(geometryChanged))
			end
			watch:Add(instance:GetAttributeChangedSignal("Tier"):Connect(function()
				zonesVersion += 1
			end))
		end
	end
	local function remove(instance: Instance)
		if instance:IsA("BasePart") then
			zones[instance] = nil
			local watch = zoneWatches[instance]
			if watch then
				watch:Destroy()
				zoneWatches[instance] = nil
			end
			zonesVersion += 1
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
			if input ~= Enum.UserInputState.Begin or not active() or HeldItemController.isInputBlocked() then
				return Enum.ContextActionResult.Pass
			end
			callback()
			return Enum.ContextActionResult.Sink
		end, false, key)
		janitor:Add(function()
			ContextActionService:UnbindAction(name)
		end)
	end
	local function cycleView()
		view = if view == "Mini" then "Full" elseif view == "Full" then "Off" else "Mini"
		applyView()
	end
	bind("RouteToggleMap", config.MapKey, cycleView)
	bind("RouteToggleShape", config.ShapeKey, function()
		circle = not circle
		applyView()
	end)
	bind("RouteNextTarget", config.TargetKey, cycle)
	bind("RouteSwitchMode", config.ModeKey, switch)
	bind("RouteFloorUp", config.FloorUpKey, function()
		changeFloor(1)
	end)
	bind("RouteFloorDown", config.FloorDownKey, function()
		changeFloor(-1)
	end)
	bind("RouteToggleMapPad", config.MapPad, cycleView)
	bind("RouteNextTargetPad", config.TargetPad, function()
		if view == "Full" then
			cycle()
		end
	end)
	bind("RouteSwitchModePad", config.ModePad, function()
		if view == "Full" then
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
	local drawnZones = -1
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
		local drawnModeNow, route = Presentation.effective(result, mode)
		local fallback = drawnModeNow ~= mode
		choice.Text = `[ {config.ModeKey.Name} / RB ] {string.upper(drawnModeNow)}{if fallback
			then ` · {string.upper(mode)} unavailable`
			else " ROUTE · switch"}`
		choice.TextColor3 = if drawnModeNow == "Clean" then config.CleanColor else config.FastColor
		floorLabel.Text = `FLOOR · {floor or "Unknown"}{if browsing then " · browsing" else " · current"}`
		local displayStatus = if route
			then `SHOWN · {string.upper(drawnModeNow)}{if fallback then " (fallback)" else ""}`
			else "NO ROUTE AVAILABLE"
		summary.Text = if result
			then `{displayStatus}\n{Presentation.summary("Clean", result.Clean)}\n{Presentation.summary(
				"Fast",
				result.Fast
			)}\nTEAM INTEL · {result.Intel}`
			else "Waiting for route data"
		local descriptions = {}
		if route then
			for index, step in route.Steps do
				table.insert(descriptions, `{index}. {Presentation.step(step)}`)
			end
		end
		flags.Text = if #descriptions > 0 then table.concat(descriptions, "\n") else "No flagged steps"
		panelRoot.Visible = view ~= "Off"
		local layout = `{view}{circle}`
		if
			view ~= "Off"
			and (
				not Presentation.sameMap(drawnResult, result)
				or drawnFloor ~= floor
				or drawnMode ~= drawnModeNow
				or drawnZones ~= zonesVersion
				or drawnLayout ~= layout
			)
		then
			local visibleZones = {}
			for zone in zones do
				table.insert(visibleZones, zone)
			end
			renderer.draw(visibleZones, floor, bands.nameAt, result, drawnModeNow, root.Position)
			drawnResult, drawnFloor, drawnMode, drawnZones = result, floor, drawnModeNow, zonesVersion
			drawnLayout = layout
			drawnMarks = -1
		end
		local trackedMarks, marksRevision = CarrierTrack.marks()
		if view ~= "Off" and drawnMarks ~= marksRevision then
			renderer.marks(trackedMarks)
			drawnMarks = marksRevision
		end
		arrows.update(
			route,
			root.Position,
			here,
			bands.nameAt,
			if drawnModeNow == "Clean" then config.CleanColor else config.FastColor
		)
	end))
	-- Every frame: the "you" marker follows the player, and in the minimap the plan slides so they stay in the middle.
	janitor:Add(RunService.RenderStepped:Connect(function()
		if view == "Off" or not panelRoot.Visible then
			return
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then
			return
		end
		local point = renderer.follow(root.Position)
		if point and view == "Mini" then
			canvas.Position = UDim2.fromOffset(miniInner / 2 - point.X, miniInner / 2 - point.Y)
		end
	end))
	janitor:Add(function()
		alive = false
		state.clear()
		bands.clear()
		for _, watch in zoneWatches do
			watch:Destroy()
		end
		table.clear(zoneWatches)
	end)
	janitor:Add(script.Destroying:Connect(function()
		janitor:Destroy()
	end))
end

return RouteHudController
