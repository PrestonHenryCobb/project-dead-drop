--!strict
-- Ticket menu-shell: the main menu. Opens on join (GameConfig.Debug.MenuOnJoin), over the 3D stage (Menu/MenuStage),
-- and closes when the player's character spawns at the end of agent select.
--
-- The frame: a header (emblem and title, the six section tabs between LB and RB, the Stocks and Credits balances), a
-- stage area where the open screen is mounted, and a footer of input hints. Screens are Types.MenuView modules found
-- in Menu/LobbyViews (Claude Code's) and Menu/Views (Codex's); a tab with no screen yet is shown disabled. Agent
-- select (PreDeployView) takes over the whole frame while it runs.
--
-- Input: mouse, keyboard (Q / E switch section, Backspace goes back) and gamepad (LB / RB, B, and Roblox's own
-- selection for A and the d-pad). Bindings exist only while the menu is open.

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Janitor = require(Shared:WaitForChild("Util"):WaitForChild("Janitor"))
local Types = require(Shared:WaitForChild("Types"))
local RemoteController = require(script.Parent:WaitForChild("RemoteController"))
local Menu = script.Parent.Parent:WaitForChild("Menu")
local LobbyState = require(Menu:WaitForChild("LobbyState"))
local MenuStage = require(Menu:WaitForChild("MenuStage"))
local MenuTheme = require(Menu:WaitForChild("MenuTheme"))

type MenuTab = Types.MenuTab
type MenuView = Types.MenuView

local config = GameConfig.Menu
local colors = MenuTheme.Colors

local MAIN_TABS: { { Tab: MenuTab, Label: string } } = {
	{ Tab = "Play", Label = "PLAY" },
	{ Tab = "Agents", Label = "AGENTS" },
	{ Tab = "Assets", Label = "ASSETS" },
	{ Tab = "Dossiers", Label = "DOSSIERS" },
	{ Tab = "BlackMarket", Label = "BLACK MARKET" },
	{ Tab = "Profile", Label = "PROFILE" },
}

-- Which camera framing each screen uses; screens not listed use Play's.
local FRAMINGS: { [string]: MenuStage.Framing } = { Agents = "Agents", Hardware = "Agents" }

local MenuController = {}

local janitor = Janitor.new() -- everything that lives while the menu is open
local views: { [string]: MenuView } = {}
local preDeployView: MenuView? = nil
local tabButtons: { [string]: MenuTheme.Button } = {}
local listeners: { [number]: (Types.MetaSnapshot) -> () } = {}
local nextListener = 0
local snapshot: Types.MetaSnapshot? = nil
local stage: MenuStage.MenuStage? = nil
local screen: Frame? = nil -- where the open view is mounted
local header: Frame? = nil
local footerLabel: TextLabel? = nil
local stocksText: TextLabel? = nil
local creditsText: TextLabel? = nil
local current: { tab: string, view: MenuView }? = nil
local history: { { tab: MenuTab, context: { [string]: any }? } } = {}
local inPreDeploy = false
local open = false

local navigator: Types.MenuNavigator

-- Loads every screen module in a folder. A broken or unfinished screen is skipped with a warning, so one bad view
-- never takes the whole menu down.
local function loadViews(folder: Instance?)
	if not folder then
		return
	end
	for _, child in folder:GetChildren() do
		if child:IsA("ModuleScript") then
			local ok, result = pcall(require, child)
			local view = if ok then result :: any else nil
			if
				type(view) == "table"
				and type(view.Tab) == "string"
				and type(view.Mount) == "function"
				and type(view.Unmount) == "function"
			then
				if child.Name == "PreDeployView" then
					preDeployView = view
				else
					views[view.Tab] = view
				end
			else
				warn(`[Menu] Skipped screen {child:GetFullName()}: {if ok then "not a MenuView" else result}`)
			end
		end
	end
end

local function formatNumber(value: number): string
	local text = tostring(math.floor(value))
	return (text:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

local function refreshBalances()
	local profile = snapshot and snapshot.Profile
	if stocksText then
		stocksText.Text = `STOCKS  {if profile then formatNumber(profile.Stocks) else "-"}`
	end
	if creditsText then
		creditsText.Text = `CREDITS  {if profile then formatNumber(profile.Credits) else "-"}`
	end
end

local function setSnapshot(value: Types.MetaSnapshot)
	snapshot = value
	refreshBalances()
	for _, listener in listeners do
		task.spawn(listener, value)
	end
end

local function unmountCurrent()
	if current then
		current.view.Unmount()
		current = nil
	end
	if screen then
		screen:ClearAllChildren() -- a view that forgot something cannot leak it into the next screen
	end
end

-- With a gamepad, start each screen with its first button selected so A works at once. Mouse and keyboard users
-- keep whatever they had.
local function selectFirstButton()
	local target = screen
	if not target or not string.find(UserInputService:GetLastInputType().Name, "Gamepad") then
		return
	end
	for _, descendant in target:GetDescendants() do
		if descendant:IsA("GuiButton") and descendant.Selectable and descendant.Visible then
			GuiService.SelectedObject = descendant
			return
		end
	end
end

local function mount(tab: string, view: MenuView, context: { [string]: any }?)
	unmountCurrent()
	if stage then
		stage:hideOperative() -- shown again only if this screen calls focusAgent
	end
	local target = screen :: Frame
	current = { tab = tab, view = view }
	view.Mount(target, navigator, context)
	for name, button in tabButtons do
		button.SetSelected(name == tab)
	end
	if footerLabel then
		footerLabel.Text = string.upper(tab)
	end
	if stage then
		stage:frame(FRAMINGS[tab] or "Play")
	end
	selectFirstButton()
end

local function navigateTo(tab: MenuTab, context: { [string]: any }?)
	local view = views[tab]
	if not view or inPreDeploy then
		return
	end
	if current and current.tab ~= tab then
		table.insert(history, { tab = current.tab :: MenuTab, context = nil })
	end
	mount(tab, view, context)
end

local function back()
	if inPreDeploy then
		return
	end
	local previous = table.remove(history)
	if previous and views[previous.tab] then
		mount(previous.tab, views[previous.tab], previous.context)
	end
end

local function cycleTab(step: number)
	if inPreDeploy then
		return
	end
	local index = 1
	for i, entry in MAIN_TABS do
		if current and entry.Tab == current.tab then
			index = i
		end
	end
	for offset = 1, #MAIN_TABS do
		local entry = MAIN_TABS[(index - 1 + step * offset) % #MAIN_TABS + 1]
		if views[entry.Tab] then
			history = {}
			navigateTo(entry.Tab)
			return
		end
	end
end

navigator = {
	navigateTo = navigateTo,
	back = back,
	canOpen = function(tab: MenuTab)
		return views[tab] ~= nil and not inPreDeploy
	end,
	focusAgent = function(agentId: Types.AgentId, hardwareId: string?)
		if not stage then
			return
		end
		local chosen = hardwareId
		if not chosen then
			local loadout = snapshot and snapshot.Loadout
			chosen = if loadout and loadout.AgentId == agentId then loadout.HardwareId else nil
		end
		stage:show(agentId, chosen)
	end,
	snapshot = function()
		return snapshot
	end,
	onSnapshot = function(listener: (Types.MetaSnapshot) -> ())
		nextListener += 1
		local id = nextListener
		listeners[id] = listener
		return function()
			listeners[id] = nil
		end
	end,
}

-- Agent select takes the whole frame while it runs; when it ends the player is spawning, so nothing else opens.
local function syncPreDeploy()
	local state = LobbyState.preDeploy()
	local active = state ~= nil and state.Active
	if active == inPreDeploy or not preDeployView or not screen then
		return
	end
	inPreDeploy = active
	if header then
		header.Visible = not active
	end
	if active then
		unmountCurrent()
		current = { tab = "PreDeploy", view = preDeployView :: MenuView };
		(preDeployView :: MenuView).Mount(screen :: Frame, navigator, nil)
		if footerLabel then
			footerLabel.Text = "AGENT SELECT"
		end
		if stage then
			stage:frame("PreDeploy")
		end
		selectFirstButton()
	end
end

local function pill(parent: Instance, name: string, order: number, accent: Color3): TextLabel
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundColor3 = colors.Surface
	frame.BackgroundTransparency = config.SurfaceTransparency
	frame.Size = UDim2.fromOffset(0, config.ChipHeightPixels + config.ChipPaddingPixels)
	frame.AutomaticSize = Enum.AutomaticSize.X
	frame.LayoutOrder = order
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, config.CornerPixels)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = accent
	stroke.Thickness = config.StrokePixels
	stroke.Parent = frame
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, config.PaddingPixels)
	padding.PaddingRight = UDim.new(0, config.PaddingPixels)
	padding.Parent = frame
	local text = MenuTheme.label({
		Name = "Amount",
		Text = "",
		Style = "Mono",
		Color = accent,
		Parent = frame,
		Size = UDim2.fromScale(0, 1),
	})
	text.AutomaticSize = Enum.AutomaticSize.X
	text.TextWrapped = false
	frame.Parent = parent
	return text
end

local function buildHeader(parent: Frame): Frame
	local bar = Instance.new("Frame")
	bar.Name = "Header"
	bar.BackgroundColor3 = colors.Canvas
	bar.BackgroundTransparency = config.SurfaceTransparency
	bar.BorderSizePixel = 0
	bar.Size = UDim2.new(1, 0, 0, config.HeaderPixels)
	bar.Parent = parent
	local trim = Instance.new("Frame")
	trim.Name = "Trim"
	trim.BackgroundColor3 = colors.Brass
	trim.BorderSizePixel = 0
	trim.Position = UDim2.fromScale(0, 1)
	trim.Size = UDim2.new(1, 0, 0, config.TrimPixels)
	trim.Parent = bar

	-- Left: a brass-framed burgundy diamond and the title.
	local brand = Instance.new("Frame")
	brand.Name = "Brand"
	brand.BackgroundTransparency = 1
	brand.Position = UDim2.fromOffset(config.PaddingPixels * 2, 0)
	brand.Size = UDim2.new(0, 0, 1, 0)
	brand.AutomaticSize = Enum.AutomaticSize.X
	brand.Parent = bar
	local brandLayout = MenuTheme.stack(brand, true)
	brandLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	local diamond = Instance.new("Frame")
	diamond.Name = "Emblem"
	diamond.BackgroundColor3 = colors.Burgundy
	diamond.Rotation = 45
	diamond.Size = UDim2.fromOffset(config.ChipHeightPixels + 6, config.ChipHeightPixels + 6)
	diamond.Parent = brand
	local diamondStroke = Instance.new("UIStroke")
	diamondStroke.Color = colors.Brass
	diamondStroke.Thickness = config.TrimPixels
	diamondStroke.Parent = diamond
	local title = MenuTheme.label({
		Name = "Title",
		Text = "COVER STORY",
		Style = "Display",
		Parent = brand,
		Size = UDim2.fromScale(0, 1),
		LayoutOrder = 1,
	})
	title.AutomaticSize = Enum.AutomaticSize.X
	title.TextWrapped = false

	-- Centre: LB, the six tabs, RB.
	local tabs = Instance.new("Frame")
	tabs.Name = "Tabs"
	tabs.BackgroundTransparency = 1
	tabs.AnchorPoint = Vector2.new(0.5, 0.5)
	tabs.Position = UDim2.fromScale(0.5, 0.5)
	tabs.Size = UDim2.fromOffset(0, config.SecondaryHeightPixels)
	tabs.AutomaticSize = Enum.AutomaticSize.X
	tabs.Parent = bar
	local tabLayout = MenuTheme.stack(tabs, true)
	tabLayout.Padding = UDim.new(0, config.TabGapPixels)
	tabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	local function bumper(name: string, order: number, step: number)
		MenuTheme.secondaryButton({
			Name = name,
			Text = name,
			Parent = tabs,
			Size = UDim2.fromOffset(config.BumperWidthPixels, config.ChipHeightPixels + 8),
			LayoutOrder = order,
			OnActivated = function()
				cycleTab(step)
			end,
		}).Instance.Font =
			config.Fonts.Mono
	end
	bumper("LB", 0, -1)
	for index, entry in MAIN_TABS do
		local button = MenuTheme.secondaryButton({
			Name = entry.Tab,
			Text = entry.Label,
			Parent = tabs,
			Size = UDim2.fromOffset(config.TabWidthPixels, config.SecondaryHeightPixels - 8),
			LayoutOrder = index,
			Enabled = views[entry.Tab] ~= nil,
			OnActivated = function()
				history = {}
				navigateTo(entry.Tab)
			end,
		})
		button.Instance.TextSize = config.TextSizes.Small
		tabButtons[entry.Tab] = button
	end
	bumper("RB", #MAIN_TABS + 1, 1)

	-- Right: the two balances. Stocks opens the Mint once the Mint screen exists.
	local purse = Instance.new("Frame")
	purse.Name = "Balances"
	purse.BackgroundTransparency = 1
	purse.AnchorPoint = Vector2.new(1, 0.5)
	purse.Position = UDim2.new(1, -config.PaddingPixels * 2, 0.5, 0)
	purse.Size = UDim2.fromOffset(0, config.ChipHeightPixels + config.ChipPaddingPixels)
	purse.AutomaticSize = Enum.AutomaticSize.X
	purse.Parent = bar
	local purseLayout = MenuTheme.stack(purse, true)
	purseLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	stocksText = pill(purse, "Stocks", 1, colors.EmeraldBright)
	creditsText = pill(purse, "Credits", 2, colors.Brass)
	if views.Mint then
		local stocksFrame = (stocksText :: TextLabel).Parent :: Frame
		local openMint = Instance.new("TextButton")
		openMint.Name = "OpenMint"
		openMint.Text = ""
		openMint.BackgroundTransparency = 1
		openMint.Size = UDim2.fromScale(1, 1)
		openMint.Parent = stocksFrame
		openMint.Activated:Connect(function()
			navigateTo("Mint")
		end)
	end
	refreshBalances()
	return bar
end

local function buildFooter(parent: Frame)
	local bar = Instance.new("Frame")
	bar.Name = "Footer"
	bar.BackgroundColor3 = colors.Canvas
	bar.BackgroundTransparency = config.SurfaceTransparency
	bar.BorderSizePixel = 0
	bar.AnchorPoint = Vector2.new(0, 1)
	bar.Position = UDim2.fromScale(0, 1)
	bar.Size = UDim2.new(1, 0, 0, config.FooterPixels)
	bar.Parent = parent
	local hints = MenuTheme.label({
		Name = "Hints",
		Text = "[A / ENTER] SELECT     [B / BACKSPACE] BACK     [LB / RB · Q / E] SECTION",
		Style = "Mono",
		Color = colors.TextDim,
		Parent = bar,
		Position = UDim2.fromOffset(config.PaddingPixels * 2, 0),
		Size = UDim2.new(0.7, 0, 1, 0),
	})
	hints.TextSize = config.TextSizes.Small
	footerLabel = MenuTheme.label({
		Name = "Screen",
		Text = "",
		Style = "Kicker",
		Parent = bar,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -config.PaddingPixels * 2, 0, 0),
		Size = UDim2.new(0.3, 0, 1, 0),
		Alignment = Enum.TextXAlignment.Right,
	})
end

local function bindInput()
	local function onAction(name: string, inputState: Enum.UserInputState): Enum.ContextActionResult
		if inputState ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		if name == "MenuPrevTab" then
			cycleTab(-1)
		elseif name == "MenuNextTab" then
			cycleTab(1)
		else
			back()
		end
		return Enum.ContextActionResult.Sink
	end
	ContextActionService:BindAction("MenuPrevTab", onAction, false, Enum.KeyCode.ButtonL1, Enum.KeyCode.Q)
	ContextActionService:BindAction("MenuNextTab", onAction, false, Enum.KeyCode.ButtonR1, Enum.KeyCode.E)
	ContextActionService:BindAction("MenuBack", onAction, false, Enum.KeyCode.ButtonB, Enum.KeyCode.Backspace)
	janitor:Add(function()
		ContextActionService:UnbindAction("MenuPrevTab")
		ContextActionService:UnbindAction("MenuNextTab")
		ContextActionService:UnbindAction("MenuBack")
	end)
end

-- Keeps the frame at the 1280 x 720 reference size scaled to the screen: the UIScale grows (or, on a smaller window,
-- shrinks) everything, and the root is sized 1 / scale so it still exactly covers the screen.
local function bindScale(gui: ScreenGui, root: Frame)
	local scaler = Instance.new("UIScale")
	scaler.Parent = root
	local reference = GameConfig.UI.PanelScale
	local function refresh()
		local size = gui.AbsoluteSize
		local factor = math.clamp(
			math.min(size.X / reference.ReferenceWidthPixels, size.Y / reference.ReferenceHeightPixels),
			config.MinScale,
			reference.Maximum
		)
		scaler.Scale = factor
		root.Size = UDim2.fromScale(1 / factor, 1 / factor)
	end
	janitor:Add(gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(refresh))
	refresh()
end

-- The in-match HUD has nothing to show before the player spawns, and must not draw over the menu: every other
-- ScreenGui is switched off while the menu is open and put back as it was when it closes.
local function hideOtherGuis(playerGui: Instance, menuGui: ScreenGui)
	local hidden: { [ScreenGui]: boolean } = {}
	local function hide(child: Instance)
		if child:IsA("ScreenGui") and child ~= menuGui and hidden[child] == nil then
			hidden[child] = child.Enabled
			child.Enabled = false
		end
	end
	for _, child in playerGui:GetChildren() do
		hide(child)
	end
	janitor:Add(playerGui.ChildAdded:Connect(hide))
	janitor:Add(function()
		for gui, enabled in hidden do
			if gui.Parent then
				gui.Enabled = enabled
			end
		end
	end)
end

local function close()
	if not open then
		return
	end
	open = false
	unmountCurrent()
	if stage then
		stage:destroy()
		stage = nil
	end
	janitor:Cleanup()
	screen, header, footerLabel, stocksText, creditsText = nil, nil, nil, nil, nil
	table.clear(tabButtons)
	GuiService.SelectedObject = nil
end

local function fetchProfile()
	for _ = 1, config.ProfileAttempts do
		local ok, result = pcall(RemoteController.invoke, "GetPlayerMetaProfile")
		if ok and type(result) == "table" then
			setSnapshot(result :: Types.MetaSnapshot)
			return
		end
		task.wait(config.ProfileRetrySeconds)
	end
	warn("[Menu] The server did not send a profile")
end

local function openMenu()
	open = true
	local gui = Instance.new("ScreenGui")
	gui.Name = "CoverStoryMenuGui"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = config.DisplayOrder
	janitor:Add(gui)

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.BackgroundTransparency = 1
	root.Parent = gui
	header = buildHeader(root)
	buildFooter(root)
	local area = Instance.new("Frame")
	area.Name = "Screen"
	area.BackgroundTransparency = 1
	area.Position = UDim2.fromOffset(0, config.HeaderPixels)
	area.Size = UDim2.new(1, 0, 1, -(config.HeaderPixels + config.FooterPixels))
	area.ClipsDescendants = true
	area.Parent = root
	screen = area
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui.Parent = playerGui
	hideOtherGuis(playerGui, gui)
	bindScale(gui, root)
	bindInput()

	stage = MenuStage.new()
	janitor:Add(LobbyState.onChanged(syncPreDeploy))
	if views.Play then
		navigateTo("Play")
	elseif stage then
		stage:frame("Play")
	end
	syncPreDeploy()
end

function MenuController.Init() end

function MenuController.Start()
	if not GameConfig.Debug.MenuOnJoin then
		return
	end
	loadViews(Menu:FindFirstChild("LobbyViews"))
	loadViews(Menu:FindFirstChild("Views"))
	LobbyState.start()
	RemoteController.connect("ProfileStateUpdated", setSnapshot)
	local player = Players.LocalPlayer
	player.CharacterAdded:Connect(close)
	if player.Character then
		return -- already in the match (the menu opens only before the first spawn)
	end
	openMenu()
	task.spawn(fetchProfile)
end

return MenuController
