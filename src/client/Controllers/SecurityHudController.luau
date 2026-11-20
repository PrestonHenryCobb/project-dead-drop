--!strict
-- Ticket 14b: read-only security prompts and nearby Camera Room feeds. No gameplay requests or rig decoration.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)
local InputHints = require(Shared:WaitForChild("Util"):WaitForChild("InputHints"))
local Enums = require(Shared.Enums)
local Types = require(Shared.Types)
local Janitor = require(Shared.Util.Janitor)
local HudKit = require(Shared.Util.HudKit)
local HudTheme = require(Shared.Util.HudTheme)
local Accessibility = require(Shared.Util.UiAccessibility)
local Feeds = require(script.Parent.Parent.Combat.SecurityFeeds)
local Targets = require(script.Parent.SecurityInteractController)
local RemoteController = require(script.Parent.RemoteController)
local DroneController = require(script.Parent.DroneController)
local SecurityHudController = {}
local theme = HudTheme.get()
local config = GameConfig.SecurityHud
local player = Players.LocalPlayer
local labels = {
	SecretExit = "Pull the lever",
	Camera = "Hack camera",
	FuseBox = "Cut power",
	CameraTerminal = "Camera Room",
	Lockpick = "Pick lock",
	SupplyCache = "Open Supply Cache",
	DoorHack = "Hack door",
	HealthStation = "Heal",
	AmmoCache = "Refill ammo",
	FoodSpot = "Eat",
	AgentTag = "Take Agent Tag", -- generic: only the server knows whether this tag belongs to a teammate
	AssetSafe = "Open safe",
	ElevatorCall = "Call elevator",
	ElevatorHack = "Hack door",
	KeycardPrinter = "Print keycard",
}
local validLabels: { [string]: boolean } = {}
for _, label in labels do
	validLabels[label] = true
end
validLabels["Supply Cache"] = true -- the authoritative hold label differs from the contextual prompt
validLabels["Use keycard"] = true -- Supply Cache keycards change the acknowledged door hold
validLabels["SecretExit"] = true -- accept the action kind as well as the server's human-readable hold label

function SecurityHudController.Init() end

function SecurityHudController.Start()
	local janitor = Janitor.new()
	local phase: Types.Phase = "Lobby"
	local downed, eliminated, frozen = false, false, false
	local hold: Types.InteractStateInfo? = nil
	local busyElsewhere = false
	local heldAt = 0
	local page = 0
	local cycleAt = os.clock()
	local gui = HudKit.screen("SecurityHud")
	janitor:Add(gui)
	local prompt = HudKit.panel(
		gui,
		"SecurityAction",
		UDim2.new(0.5, 0, 0.5, theme.ActionOffsetPixels),
		Vector2.new(0.5, 0),
		UDim2.fromOffset(theme.ActionWidthPixels, theme.ActionHeightPixels)
	)
	local promptRoot = prompt.Parent :: Frame
	promptRoot.Visible = false
	local action = HudKit.text(
		prompt,
		"Action",
		UDim2.fromOffset(theme.PaddingPixels, theme.PaddingPixels),
		Vector2.zero,
		UDim2.new(1, -theme.PaddingPixels * 2, 0, theme.CaptionSize)
	)
	action.TextSize = theme.CaptionSize
	local bar = Instance.new("Frame")
	bar.Name = "SecurityHoldProgress"
	bar.BorderSizePixel = 0
	bar.BackgroundColor3 = theme.AccentColor
	bar.Position = UDim2.new(0, theme.PaddingPixels, 1, -theme.PaddingPixels)
	bar.Size = UDim2.fromOffset(0, theme.ReloadBarPixels)
	bar.Parent = prompt
	local panel = HudKit.panel(
		gui,
		"CameraRoomFeeds",
		UDim2.fromOffset(theme.MarginPixels, config.FeedTopPixels),
		Vector2.zero,
		UDim2.fromOffset(config.FeedWidthPixels, config.FeedHeightPixels)
	)
	local panelRoot = panel.Parent :: Frame
	panelRoot.Visible = false
	local title = HudKit.text(
		panel,
		"Title",
		UDim2.fromOffset(theme.PaddingPixels, theme.PaddingPixels),
		Vector2.zero,
		UDim2.new(1, -theme.PaddingPixels * 2, 0, theme.CaptionSize)
	)
	title.TextSize = theme.CaptionSize
	title.TextXAlignment = Enum.TextXAlignment.Left
	local nextPage = Instance.new("TextButton")
	nextPage.Name = "NextCameras"
	nextPage.Text = InputHints.bracket(config.NextFeedKey, config.NextFeedPad, "NEXT CAMERAS")
	nextPage.Font = theme.Font
	nextPage.TextSize = theme.CaptionSize
	nextPage.TextColor3 = theme.TextColor
	nextPage.BackgroundColor3 = theme.PanelColor
	nextPage.Size = UDim2.new(1, -theme.PaddingPixels * 2, 0, theme.CaptionSize + theme.PaddingPixels)
	nextPage.Position = UDim2.new(0, theme.PaddingPixels, 1, -theme.CaptionSize - theme.PaddingPixels * 2)
	nextPage.Selectable = true
	nextPage.Parent = panel
	janitor:Add(InputHints.onChange(function()
		nextPage.Text = InputHints.bracket(config.NextFeedKey, config.NextFeedPad, "NEXT CAMERAS")
	end))
	local function canPage(): boolean
		return gui.Enabled and panelRoot.Visible and nextPage.Visible and not DroneController.inputBlocked()
	end
	janitor:Add(nextPage.Activated:Connect(function()
		if canPage() then
			page += 1
			cycleAt = os.clock()
		end
	end))
	ContextActionService:BindAction("SecurityNextFeeds", function(_, inputState)
		if inputState == Enum.UserInputState.Begin and canPage() then
			page += 1
			cycleAt = os.clock()
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, config.NextFeedKey, config.NextFeedPad)
	janitor:Add(function()
		ContextActionService:UnbindAction("SecurityNextFeeds")
	end)
	local views = {}
	local width = (config.FeedWidthPixels - theme.PaddingPixels * 3) / 2
	local height = (config.FeedHeightPixels - theme.CaptionSize * 2 - theme.PaddingPixels * 6) / 2
	for index = 1, GameConfig.Security.CameraRoom.Feeds do
		local viewport = Instance.new("ViewportFrame")
		viewport.Name = `Feed{index}`
		viewport.BackgroundColor3 = theme.PanelColor
		viewport.BorderSizePixel = 0
		viewport.Size = UDim2.fromOffset(width, height)
		viewport.Position = UDim2.fromOffset(
			theme.PaddingPixels + ((index - 1) % 2) * (width + theme.PaddingPixels),
			theme.CaptionSize + theme.PaddingPixels * 2 + math.floor((index - 1) / 2) * (height + theme.PaddingPixels)
		)
		viewport.Parent = panel
		local caption = HudKit.text(
			viewport,
			"Status",
			UDim2.fromScale(0, 1),
			Vector2.new(0, 1),
			UDim2.new(1, 0, 0, theme.CaptionSize)
		)
		caption.TextSize = theme.CaptionSize
		caption.BackgroundColor3 = theme.PanelColor
		caption.BackgroundTransparency = theme.PanelTransparency
		local scene = Feeds.new(viewport)
		janitor:Add(scene)
		table.insert(views, { viewport = viewport, caption = caption, scene = scene })
	end
	local function active(): boolean
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		return gui.Enabled
			and (phase == "Infiltration" or phase == "VaultBreach" or phase == "PackageHeist" or phase == "Overtime")
			and not downed
			and not eliminated
			and not frozen
			and humanoid ~= nil
			and humanoid.Health > 0
	end
	local function reset()
		hold = nil
		busyElsewhere = false
		promptRoot.Visible = false
		panelRoot.Visible = false
		for _, view in views do
			view.scene.update(nil, 0)
		end
	end
	janitor:Add(RemoteController.connect("PhaseChanged", function(value: Types.Phase)
		phase = value
		if value == "Lobby" or value == "Insertion" then
			frozen = false
		end
		if not active() then
			reset()
		end
	end))
	janitor:Add(RemoteController.connect("InteractState", function(info: Types.InteractStateInfo)
		hold = if info.Active and validLabels[info.Kind] then info else nil
		busyElsewhere = info.Active and not validLabels[info.Kind]
		heldAt = os.clock()
	end))
	janitor:Add(RemoteController.connect("Downed", function()
		downed = true
		reset()
	end))
	janitor:Add(RemoteController.connect("Eliminated", function()
		eliminated = true
		reset()
	end))
	janitor:Add(RemoteController.connect("Revived", function()
		downed = false
	end))
	janitor:Add(RemoteController.connect("ExtractionState", function(info: Types.ExtractionStateInfo)
		frozen = info.State == "Extracted"
		if frozen then
			reset()
		end
	end))
	janitor:Add(player.CharacterAdded:Connect(function()
		downed, eliminated = false, false
		reset()
	end))
	local elapsed = 0
	janitor:Add(RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < config.RefreshSeconds then
			return
		end
		local delta = elapsed
		elapsed = 0
		if not active() then
			reset()
			return
		end
		local target, kind = Targets.currentTarget()
		local label = if kind then (labels :: { [string]: string })[kind] else nil
		promptRoot.Visible = not busyElsewhere and (hold ~= nil or (target ~= nil and label ~= nil))
		action.Text = if hold
			then string.upper(hold.Kind)
			else if label
				then InputHints.bracket(GameConfig.Controls.Interact, GameConfig.Controls.InteractPad, label)
				else ""
		local progress = if hold
			then math.clamp((os.clock() - heldAt) / math.max(hold.Seconds, config.RefreshSeconds), 0, 1)
			else 0
		bar.Size = UDim2.new(progress, -theme.PaddingPixels * 2 * progress, 0, theme.ReloadBarPixels)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local nearby = false
		if root and root:IsA("BasePart") then
			for _, terminal in CollectionService:GetTagged(Enums.Tag.CameraTerminal) do
				if
					terminal:IsA("BasePart")
					and terminal.Parent
					and (terminal.Position - root.Position).Magnitude
						<= GameConfig.Security.CameraRoom.InteractStuds
				then
					nearby = true
					break
				end
			end
		end
		panelRoot.Visible = nearby
		local cameras = if nearby then Feeds.cameras(CollectionService:GetTagged(Enums.Tag.SecurityCamera)) else {}
		local pages = math.max(1, math.ceil(#cameras / #views))
		if not nearby then
			page = 0
			cycleAt = os.clock()
		end
		-- Reduce Motion keeps live surveillance functional, but makes page changes manual and immediate.
		if not Accessibility.reducedMotion() and os.clock() - cycleAt >= config.CycleSeconds then
			page += 1
			cycleAt = os.clock()
		end
		page %= pages
		title.Text = if #cameras == 0 then "CAMERA ROOM · NO WORKING SIGNAL" else `CAMERA ROOM · {page + 1}/{pages}`
		nextPage.Visible = pages > 1
		for index, view in views do
			local camera = cameras[page * #views + index]
			view.viewport.Visible = camera ~= nil
			view.caption.Text = if camera
				then `{camera:GetAttribute("SecurityId")} · {camera:GetAttribute("CameraState")}`
				else ""
			view.scene.update(camera, delta)
		end
	end))
	janitor:Add(function()
		reset()
	end)
	janitor:Add(script.Destroying:Connect(function()
		janitor:Destroy()
	end))
end

return SecurityHudController
