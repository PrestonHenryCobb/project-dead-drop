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
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local InputHints = require(Shared:WaitForChild("Util"):WaitForChild("InputHints"))

-- The footer legend names the buttons of the device in use only (owner request 2026-11-20).
local function menuLegend(): string
	return InputHints.text(
		"[ENTER] SELECT     [BACKSPACE] BACK     [Q / E] SECTION",
		"[A] SELECT     [B] BACK     [LB / RB] SECTION"
	)
end
local Janitor = require(Shared:WaitForChild("Util"):WaitForChild("Janitor"))
local Types = require(Shared:WaitForChild("Types"))
local RemoteController = require(script.Parent:WaitForChild("RemoteController"))
local Menu = script.Parent.Parent:WaitForChild("Menu")
local LobbyState = require(Menu:WaitForChild("LobbyState"))
local MenuStage = require(Menu:WaitForChild("MenuStage"))
local MenuTheme = require(Menu:WaitForChild("MenuTheme"))
local SettingsPanel = require(Menu.Components.SettingsPanel)
local UiAccessibility = require(Shared.Util.UiAccessibility)

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
local FRAMINGS: { [string]: MenuStage.Framing } = { Agents = "Agents", Hardware = "Hardware", PreDeploy = "PreDeploy" }

local MenuController = {}

local janitor = Janitor.new() -- everything that lives while the menu is open
local views: { [string]: MenuView } = {}
local preDeployView: MenuView? = nil
local tabButtons: { [string]: MenuTheme.Button } = {}
local listeners: { [number]: (Types.MetaSnapshot) -> () } = {}
local nextListener = 0
local snapshot: Types.MetaSnapshot? = nil
local stage: MenuStage.MenuStage? = nil
local screenTransitions = Janitor.new()
local activeGroup: CanvasGroup? = nil
local screen: Frame? = nil -- where the open view is mounted
local header: Frame? = nil
local footerLabel: TextLabel? = nil
local footerHints: TextLabel? = nil
local noticeToken = 0
local stocksText: TextLabel? = nil
local creditsText: TextLabel? = nil
local current: { tab: string, view: MenuView }? = nil
local history: { { tab: MenuTab, context: { [string]: any }? } } = {}
local inPreDeploy = false
local open = false
local spectating = false
local menuGeneration = 0
local profileGeneration = 0
local profileFetching = false
local snapshotRevision = 0
local profileRetry: MenuTheme.Button? = nil
local fetchProfile: () -> ()
local selectFirstButton: () -> ()

local navigator: Types.MenuNavigator

-- Gameplay HUDs are hidden behind the menu, so their Notification toast cannot explain a refused Deploy here.
local function showNotice(text: string)
	local hints = footerHints
	if not open or not hints then
		return
	end
	noticeToken += 1
	local token = noticeToken
	hints.Text = text
	hints.TextColor3 = colors.BrassBright
	task.delay(GameConfig.UI.ToastSeconds, function()
		if token == noticeToken and footerHints == hints and hints.Parent then
			hints.Text = menuLegend()
			hints.TextColor3 = colors.TextDim
		end
	end)
end

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
	snapshotRevision += 1
	if profileRetry then
		local selected = GuiService.SelectedObject == profileRetry.Instance
		profileRetry.Instance.Visible = false
		if selected then
			task.defer(selectFirstButton)
		end
	end
	if footerLabel then
		footerLabel.Visible = true
	end
	refreshBalances()
	for _, listener in listeners do
		task.spawn(listener, value)
	end
end

local function unmountCurrent()
	screenTransitions:Cleanup()
	activeGroup = nil
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
function selectFirstButton()
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
	local outgoing = if activeGroup and not UiAccessibility.reducedMotion() then activeGroup:Clone() else nil
	unmountCurrent()
	local target = screen :: Frame
	if outgoing then
		-- Only a visual snapshot survives: old requests and subscriptions are already unmounted.
		for _, item in outgoing:GetDescendants() do
			if item:IsA("GuiObject") then
				item.Active = false
				item.Selectable = false
			end
			if item:IsA("ScrollingFrame") then
				item.ScrollingEnabled = false
			end
			if item:IsA("TextBox") then
				item.TextEditable = false
			end
			if item:IsA("Script") or item:IsA("LocalScript") then
				item:Destroy()
			end
		end
		outgoing.Name = "OutgoingScreen"
		outgoing.Active = false
		outgoing.Parent = target
		screenTransitions:Add(outgoing)
		local fade = TweenService:Create(outgoing, MenuTheme.ScreenFadeInfo, { GroupTransparency = 1 })
		screenTransitions:Add(function()
			fade:Cancel()
		end)
		screenTransitions:Add(fade.Completed:Connect(function(status)
			if status == Enum.PlaybackState.Completed then
				outgoing:Destroy()
			end
		end))
		fade:Play()
	end
	local group = Instance.new("CanvasGroup")
	group.Name = "CurrentScreen"
	group.BackgroundTransparency = 1
	group.Size = UDim2.fromScale(1, 1)
	group.GroupTransparency = if UiAccessibility.reducedMotion() then 0 else 1
	group.Parent = target
	activeGroup = group
	local content = Instance.new("Frame")
	content.Name = "ViewContent"
	content.BackgroundTransparency = 1
	content.Size = UDim2.fromScale(1, 1)
	content.Parent = group
	current = { tab = tab, view = view }
	if stage then
		if tab ~= "Play" and tab ~= "Agents" and tab ~= "Hardware" and tab ~= "PreDeploy" then
			stage:hideOperative()
		end
		stage:frame(FRAMINGS[tab] or "Play")
	end
	view.Mount(content, navigator, context)
	if not UiAccessibility.reducedMotion() then
		local fade = TweenService:Create(group, MenuTheme.ScreenFadeInfo, { GroupTransparency = 0 })
		screenTransitions:Add(function()
			fade:Cancel()
		end)
		fade:Play()
	end
	for name, button in tabButtons do
		button.SetSelected(name == tab)
	end
	if footerLabel then
		footerLabel.Text = string.upper(tab)
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
	if SettingsPanel.isOpen() then
		SettingsPanel.close()
		return
	end
	if inPreDeploy then
		return
	end
	local previous = table.remove(history)
	if previous and views[previous.tab] then
		mount(previous.tab, views[previous.tab], previous.context)
	end
end

local function cycleTab(step: number)
	if inPreDeploy or SettingsPanel.isOpen() then
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
		mount("PreDeploy", preDeployView :: MenuView, nil)
		if footerLabel then
			footerLabel.Text = "AGENT SELECT"
		end
		selectFirstButton()
	end
end

local function pill(parent: Instance, name: string, order: number, accent: Color3): TextLabel
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundColor3 = colors.Surface
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromOffset(0, config.ChipHeightPixels)
	frame.AutomaticSize = Enum.AutomaticSize.X
	frame.LayoutOrder = order
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, config.CornerPixels)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = accent
	stroke.Thickness = config.StrokePixels
	stroke.Transparency = 1
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
	text.TextSize = config.Cinematic.NavigationTextPixels
	frame.Parent = parent
	return text
end

local function buildHeader(parent: Frame): Frame
	local bar = Instance.new("Frame")
	bar.Name = "Header"
	bar.BackgroundColor3 = colors.Canvas
	bar.BackgroundTransparency = 1
	bar.BorderSizePixel = 0
	bar.Size = UDim2.new(1, 0, 0, config.HeaderPixels)
	bar.Parent = parent
	local trim = Instance.new("Frame")
	trim.Name = "Trim"
	trim.BackgroundColor3 = colors.Brass
	trim.BorderSizePixel = 0
	trim.Size = UDim2.new(1, -config.PaddingPixels * 4, 0, config.StrokePixels)
	trim.Position = UDim2.new(0, config.PaddingPixels * 2, 1, 0)
	trim.BackgroundTransparency = config.Cinematic.PanelStrokeTransparency
	trim.Parent = bar

	-- Left: an outline emblem and compact ivory wordmark.
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
	diamond.BackgroundTransparency = 1
	diamond.Rotation = 45
	diamond.Size = UDim2.fromOffset(config.ChipHeightPixels + 6, config.ChipHeightPixels + 6)
	diamond.Parent = brand
	local diamondStroke = Instance.new("UIStroke")
	diamondStroke.Color = colors.Brass
	diamondStroke.Thickness = config.TrimPixels
	diamondStroke.Parent = diamond
	local title = MenuTheme.label({
		Name = "Title",
		Text = "DEAD DROP",
		Style = "Display",
		Parent = brand,
		Size = UDim2.fromScale(0, 1),
		LayoutOrder = 1,
	})
	title.TextSize = config.Cinematic.HeaderTitlePixels
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
	local bumpers: { GuiObject } = {}
	local function bumper(name: string, order: number, step: number)
		local item = MenuTheme.navigationButton({
			Name = name,
			Text = name,
			Parent = tabs,
			Size = UDim2.fromOffset(config.BumperWidthPixels, config.ChipHeightPixels + 8),
			LayoutOrder = order,
			OnActivated = function()
				cycleTab(step)
			end,
		}).Instance
		item.Font = config.Fonts.Mono
		item.Visible = InputHints.isGamepad() -- the bumper buttons are for a gamepad; the keyboard uses Q and E
		table.insert(bumpers, item)
	end
	bumper("LB", 0, -1)
	for index, entry in MAIN_TABS do
		local button = MenuTheme.navigationButton({
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
		button.Instance.TextSize = config.Cinematic.NavigationTextPixels
		tabButtons[entry.Tab] = button
	end
	bumper("RB", #MAIN_TABS + 1, 1)
	janitor:Add(InputHints.onChange(function(pad)
		for _, item in bumpers do
			item.Visible = pad
		end
	end))

	-- Right: the two balances. Stocks opens the Mint once the Mint screen exists.
	local purse = Instance.new("Frame")
	purse.Name = "Balances"
	purse.BackgroundTransparency = 1
	purse.AnchorPoint = Vector2.new(1, 0.5)
	purse.Position = UDim2.new(1, -config.PaddingPixels * 2, 0.5, 0)
	purse.Size = UDim2.fromOffset(0, config.ChipHeightPixels * 2)
	purse.AutomaticSize = Enum.AutomaticSize.X
	purse.Parent = bar
	local purseLayout = MenuTheme.stack(purse)
	purseLayout.Padding = UDim.new(0, 0)
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
	bar.BackgroundTransparency = 1
	bar.BorderSizePixel = 0
	bar.AnchorPoint = Vector2.new(0, 1)
	bar.Position = UDim2.fromScale(0, 1)
	bar.Size = UDim2.new(1, 0, 0, config.FooterPixels)
	bar.Parent = parent
	local hints = MenuTheme.label({
		Name = "Hints",
		Text = menuLegend(),
		Style = "Mono",
		Color = colors.TextDim,
		Parent = bar,
		Position = UDim2.fromOffset(config.PaddingPixels * 2, 0),
		Size = UDim2.new(0.7, 0, 1, 0),
	})
	hints.TextSize = config.TextSizes.Small
	hints.RichText = false
	hints.TextWrapped = true
	footerHints = hints
	janitor:Add(InputHints.onChange(function()
		if hints.Parent and hints.TextColor3 == colors.TextDim then
			hints.Text = menuLegend() -- a notice in the footer keeps its own text
		end
	end))
	footerLabel = MenuTheme.label({
		Name = "Screen",
		Text = "",
		Style = "Kicker",
		Parent = bar,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -config.PaddingPixels * 2 - config.TabWidthPixels - config.GapPixels, 0, 0),
		Size = UDim2.new(0.15, 0, 1, 0),
		Alignment = Enum.TextXAlignment.Right,
	})
	local retry = MenuTheme.secondaryButton({
		Name = "RetryProfile",
		Text = "RETRY PROFILE",
		Parent = bar,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -config.PaddingPixels * 2 - config.TabWidthPixels - config.GapPixels, 0.5, 0),
		Size = UDim2.new(0.15, 0, 1, -config.GapPixels),
		OnActivated = function()
			task.spawn(fetchProfile)
		end,
	})
	retry.Instance.TextSize = config.TextSizes.Small
	retry.Instance.Visible = false
	profileRetry = retry
	MenuTheme.secondaryButton({
		Name = "OpenSettings",
		Text = "SETTINGS",
		Parent = bar,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -config.PaddingPixels * 2, 0.5, 0),
		Size = UDim2.new(0, config.TabWidthPixels, 1, -config.GapPixels),
		OnActivated = function()
			SettingsPanel.open(parent)
		end,
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
	menuGeneration += 1
	profileGeneration += 1
	profileFetching = false
	inPreDeploy = false
	table.clear(history)
	noticeToken += 1
	footerHints = nil
	SettingsPanel.close()
	unmountCurrent()
	if stage then
		stage:destroy()
		stage = nil
	end
	janitor:Cleanup()
	screen, header, footerLabel, stocksText, creditsText = nil, nil, nil, nil, nil
	profileRetry = nil
	table.clear(tabButtons)
	GuiService.SelectedObject = nil
end

function fetchProfile()
	if not open or spectating or profileFetching then
		return
	end
	profileFetching = true
	profileGeneration += 1
	local generation = profileGeneration
	local function active(): boolean
		return open and not spectating and generation == profileGeneration
	end
	local function finish(success: boolean)
		if not active() then
			return
		end
		profileFetching = false
		local retry = profileRetry
		if retry then
			retry.SetText("RETRY PROFILE")
			retry.SetEnabled(true)
			retry.Instance.Visible = not success
			if
				not success
				and not GuiService.SelectedObject
				and string.find(UserInputService:GetLastInputType().Name, "Gamepad")
			then
				GuiService.SelectedObject = retry.Instance
			end
		end
		if footerLabel then
			footerLabel.Visible = success
		end
	end
	if profileRetry then
		profileRetry.SetEnabled(false)
		profileRetry.SetText("CONNECTING…")
	end
	local initialRevision = snapshotRevision
	for _ = 1, config.ProfileAttempts do
		if not active() then
			return
		end
		if snapshotRevision ~= initialRevision then
			finish(true)
			return
		end
		local revision = snapshotRevision
		local ok, result = pcall(RemoteController.invoke, "GetPlayerMetaProfile")
		if not active() then
			return
		end
		if snapshotRevision ~= revision then
			finish(true) -- a fresh server push arrived while this older snapshot was in flight
			return
		end
		if ok and type(result) == "table" then
			setSnapshot(result :: Types.MetaSnapshot)
			finish(true)
			return
		end
		task.wait(config.ProfileRetrySeconds)
	end
	if not active() then
		return
	end
	if snapshotRevision ~= initialRevision then
		finish(true)
		return
	end
	finish(false)
	warn("[Menu] The server did not send a profile")
	showNotice("Profile unavailable. Choose RETRY PROFILE to try again.")
end

local function openMenu()
	if open or spectating then
		return
	end
	SettingsPanel.close() -- release an in-match modal before the lobby hides its host GUI
	open = true
	menuGeneration += 1
	local generation = menuGeneration
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
	local function veil(name: string, position: UDim2, size: UDim2, rotation: number)
		local edge = Instance.new("Frame")
		edge.Name = name
		edge.BorderSizePixel = 0
		edge.BackgroundColor3 = colors.Canvas
		edge.Position, edge.Size = position, size
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = rotation
		gradient.Transparency = NumberSequence.new(config.Cinematic.EdgeTransparency, 1)
		gradient.Parent = edge
		edge.Parent = root
	end
	veil("LeftVeil", UDim2.new(), UDim2.fromScale(config.Cinematic.EdgeWidthFraction, 1), 0)
	veil(
		"RightVeil",
		UDim2.new(1 - config.Cinematic.EdgeWidthFraction, 0, 0, 0),
		UDim2.fromScale(config.Cinematic.EdgeWidthFraction, 1),
		180
	)
	veil("TopVeil", UDim2.new(), UDim2.new(1, 0, 0, config.Cinematic.VerticalVeilPixels), 90)
	veil(
		"BottomVeil",
		UDim2.new(0, 0, 1, -config.Cinematic.VerticalVeilPixels),
		UDim2.new(1, 0, 0, config.Cinematic.VerticalVeilPixels),
		270
	)
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
	if not open or spectating or generation ~= menuGeneration then
		return -- a spectate packet may have closed the menu while PlayerGui was arriving
	end
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
	local player = Players.LocalPlayer
	local phase: Types.Phase? = nil
	local removing: Model? = nil
	local ready = false
	local returningFromSpectate = false
	local function reopenLobby()
		if not ready or spectating or open or (phase ~= "Lobby" and not returningFromSpectate) then
			return
		end
		local character = player.Character
		if character and character ~= removing then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if not humanoid or humanoid.Health > 0 then
				if humanoid and humanoid.Health > 0 then
					returningFromSpectate = false
				end
				return
			end
		end
		openMenu()
		returningFromSpectate = false
		task.spawn(fetchProfile)
	end
	player.CharacterAdded:Connect(function()
		removing = nil
		returningFromSpectate = false
		close()
	end)
	player.CharacterRemoving:Connect(function(character)
		removing = character
		task.defer(reopenLobby)
	end)
	player:GetPropertyChangedSignal("Character"):Connect(reopenLobby)
	-- Phase remotes and character destruction can replicate in either order. Neither order may strand the player.
	RemoteController.connect("PhaseChanged", function(value: Types.Phase)
		phase = value
		if value == "Lobby" then
			spectating = false
		elseif value == "Insertion" then
			spectating = false
			returningFromSpectate = false
		end
		reopenLobby()
	end)
	-- Subscribe before loading views so a mid-match join cannot open a stage after its spectator state arrives.
	RemoteController.connect("SpectateState", function(info: Types.SpectateStateInfo)
		if info.Mode ~= "None" then
			if phase == "Lobby" or phase == "Insertion" or phase == "Results" then
				return -- these phases end spectating; do not let a delayed prior-round packet hide the lobby
			end
			spectating = true
			returningFromSpectate = false
			close() -- releases the stage, menu bindings and the saved HUD visibility (including SpectateHud)
		elseif spectating then
			spectating = false
			returningFromSpectate = true
			task.defer(reopenLobby) -- a rescued player's CharacterAdded can arrive in the same batch
		end
	end)
	loadViews(Menu:FindFirstChild("LobbyViews"))
	loadViews(Menu:FindFirstChild("Views"))
	LobbyState.start()
	RemoteController.connect("ProfileStateUpdated", setSnapshot)
	RemoteController.connect("Notification", showNotice)
	ready = true
	if spectating then
		return
	end
	reopenLobby()
	if open or player.Character then
		return -- already in the match (the menu opens only before the first spawn)
	end
	openMenu()
	task.spawn(fetchProfile)
end

return MenuController
