--!strict
-- Client side of disguises and movement states (spec 6.3, 6.4, 6.8): the Scan, Disguise, Sprint and Crouch keys and
-- the small HUD for them.
--
--   Hold Scan while aiming at a character within range: the client names what it is aiming at and the server does the
--   scanning (range, sight and timing are all checked there). A ring around the centre dot fills while it runs.
--   Disguise asks the server to put on the stored disguise, or the insertion one, or to re-cover when Exposed.
--   Hold Crouch to crouch: slower, lower camera, and a crouch pose everyone sees. The server sets the speed.
--   A badge shows the disguise being worn and the one stored (STYLE_QUESTIONS A1: first person, so you cannot see
--   yourself). Nothing here is sent to anyone else.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local InputHints = require(Shared.Util.InputHints)
local OutfitDefs = require(Shared:WaitForChild("Defs"):WaitForChild("OutfitDefs"))
local Types = require(Shared:WaitForChild("Types"))
local Aim = require(Shared:WaitForChild("Util"):WaitForChild("Aim"))
local HudKit = require(Shared:WaitForChild("Util"):WaitForChild("HudKit"))
local HudTheme = require(Shared:WaitForChild("Util"):WaitForChild("HudTheme"))
local Janitor = require(Shared:WaitForChild("Util"):WaitForChild("Janitor"))
local PoseAnimation = require(Shared:WaitForChild("Util"):WaitForChild("PoseAnimation"))
local RemoteController = require(script.Parent.RemoteController)
local WeaponController = require(script.Parent.WeaponController)
local HeldItemController = require(script.Parent.HeldItemController)
local HudLayout = require(script.Parent.Parent.Combat.HudLayout)
local HudScale = require(Shared.Util.HudScale)

local DisguiseController = {}
local janitor = Janitor.new()

local ui = GameConfig.UI
local graphics = HudTheme.get()
local floating = GameConfig.UI.FloatingHud
local layout = HudLayout.regions(graphics)
local controls = GameConfig.Controls
local localPlayer = Players.LocalPlayer

local scanHeld = false
local scanSentTarget: string? = nil
local scanStartedAt: number? = nil
local scanSeconds = 0

local ringSegments: { Frame } = {}
local centerDot: Frame? = nil
local badge: TextLabel? = nil
local storedBadges: { TextLabel } = {}
local storedIcons: { Frame } = {}
local badgePanel: Frame? = nil
local tierPips: { Frame } = {}
local toast: TextLabel? = nil
local toastToken = 0
local crouchTrack: AnimationTrack? = nil
local sprintHeld = false
local crouchHeld = false
local latestDisguise: Types.DisguiseUpdate? = nil
local hintUntil = 0
local disguiseKey = ""

local function buildHud()
	local gui = HudKit.screen("DisguiseHud")
	janitor:Add(gui)

	local dot = Instance.new("Frame")
	dot.Name = "Dot"
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromScale(0.5, 0.5)
	dot.Size = UDim2.fromOffset(ui.CrosshairPixels, ui.CrosshairPixels)
	dot.BackgroundColor3 = graphics.TextColor
	dot.BorderSizePixel = 0
	dot.Parent = gui
	centerDot = dot

	-- A thin ring made of small ticks, lit from the top as the scan progresses.
	for index = 1, ui.ScanRingSegments do
		local angle = (index - 1) / ui.ScanRingSegments * 2 * math.pi
		local tick = Instance.new("Frame")
		tick.Name = `Tick{index}`
		tick.AnchorPoint = Vector2.new(0.5, 0.5)
		tick.Position = UDim2.new(0.5, math.sin(angle) * ui.ScanRingRadius, 0.5, -math.cos(angle) * ui.ScanRingRadius)
		tick.Size = UDim2.fromOffset(2, 6)
		tick.Rotation = math.deg(angle)
		tick.BackgroundColor3 = ui.ScanRingDimColor
		tick.BorderSizePixel = 0
		tick.Visible = false
		tick.Parent = gui
		table.insert(ringSegments, tick)
	end

	local disguisePanel = HudKit.panel(
		gui,
		"Disguise",
		UDim2.new(0, graphics.MarginPixels + floating.BracketGapPixels, 1, -graphics.MarginPixels),
		Vector2.new(0, 1),
		UDim2.fromOffset(floating.DisguiseWidthPixels, graphics.PaddingPixels * 4)
	)
	badgePanel = disguisePanel
	HudKit.icon(
		disguisePanel,
		"Badge",
		UDim2.fromOffset(graphics.PaddingPixels, graphics.PaddingPixels),
		graphics.IconPixels,
		graphics.TextColor
	)
	local badgeText = HudKit.text(
		disguisePanel,
		"Badge",
		UDim2.fromOffset(graphics.PaddingPixels * 2 + graphics.IconPixels, graphics.PaddingPixels / 2),
		Vector2.zero,
		UDim2.new(1, -graphics.PaddingPixels * 3 - graphics.IconPixels, 0, graphics.IconPixels)
	)
	badgeText.TextXAlignment = Enum.TextXAlignment.Left
	badgeText.TextSize = graphics.CaptionSize
	badge = badgeText
	for index = 1, #GameConfig.Zones.TierPips do
		local pip = Instance.new("Frame")
		pip.BorderSizePixel = 0
		pip.Size = UDim2.fromOffset(graphics.ReloadBarPixels, graphics.PaddingPixels)
		pip.Position = UDim2.new(1, -graphics.PaddingPixels * index, 0, graphics.PaddingPixels / 2)
		pip.Parent = disguisePanel
		tierPips[index] = pip
	end

	local toastText = HudKit.text(
		gui,
		"Toast",
		HudLayout.position(layout.Toast),
		HudLayout.anchor(layout.Toast),
		UDim2.fromOffset(layout.Toast.Width, layout.Toast.Height)
	)
	toastText.Visible = false
	toastText.TextWrapped = true
	toastText.TextColor3 = graphics.TextColor
	toastText.BackgroundColor3 = graphics.PanelColor
	toastText.BackgroundTransparency = graphics.PanelTransparency
	HudScale.bind(toastText)
	toastText.TextTransparency = 1
	toastText.TextStrokeTransparency = floating.TextShadowTransparency
	toast = toastText
end

local function showToast(text: string)
	local toastText = toast
	if not toastText then
		return
	end
	toastToken += 1
	local token = toastToken
	toastText.Text = text
	toastText.Visible = true
	toastText.TextTransparency = 0
	toastText.TextStrokeTransparency = floating.TextShadowTransparency
	task.delay(ui.ToastSeconds, function()
		if token == toastToken and toastText.Parent then
			toastText.Visible = false
			toastText.TextTransparency = 1
			toastText.TextStrokeTransparency = floating.TextShadowTransparency
		end
	end)
end

local function roleOf(outfitId: string): string
	local outfit = OutfitDefs.byId[outfitId]
	return if outfit then string.upper(outfit.Role) else "?"
end

local function showDisguise(update: Types.DisguiseUpdate)
	local slots = {}
	for _, slot in update.Slots do
		table.insert(slots, tostring(slot))
	end
	local key = update.Worn .. tostring(update.Exposed) .. table.concat(slots, ":")
	if key ~= disguiseKey then
		disguiseKey = key
		hintUntil = os.clock() + floating.HintSeconds
	end
	latestDisguise = update
	local text = badge
	if not text then
		return
	end
	local wornLine = if update.Exposed then "TRUE FORM" else roleOf(update.Worn)
	text.Text = wornLine
	local outfit = OutfitDefs.byId[update.Worn]
	local tier = if outfit and not update.Exposed then outfit.Tier else 0
	text.TextColor3 = if update.Exposed then ui.CoverColors.Exposed else graphics.TextColor
	for index, pip in tierPips do
		pip.BackgroundColor3 = if index <= tier then GameConfig.Zones.TierColors[tier] else ui.ScanRingDimColor
	end
	local panel = badgePanel
	if panel then
		local count = math.max(1, #update.Slots)
		local root = panel.Parent :: Frame
		root.Size =
			UDim2.fromOffset(floating.DisguiseWidthPixels, graphics.PaddingPixels * 3 + graphics.CaptionSize * count)
		for index = #storedBadges, count + 1, -1 do
			storedBadges[index]:Destroy()
			storedIcons[index]:Destroy()
			table.remove(storedIcons, index)
			table.remove(storedBadges, index)
		end
		for index = 1, count do
			local storedText = storedBadges[index]
			if not storedText then
				storedText = HudKit.text(
					panel,
					`Stored{index}`,
					UDim2.fromOffset(
						graphics.PaddingPixels * 2 + graphics.IconPixels,
						graphics.PaddingPixels * 2 + (index - 1) * graphics.CaptionSize
					),
					Vector2.zero,
					UDim2.new(1, -graphics.PaddingPixels * 3 - graphics.IconPixels, 0, graphics.CaptionSize)
				)
				storedText.TextSize = graphics.CaptionSize
				storedText.TextColor3 = graphics.DimTextColor
				storedText.TextXAlignment = Enum.TextXAlignment.Left
				storedBadges[index] = storedText
				storedIcons[index] = HudKit.icon(
					panel,
					"Badge",
					UDim2.fromOffset(
						graphics.PaddingPixels,
						graphics.PaddingPixels * 2 + (index - 1) * graphics.CaptionSize
					),
					graphics.CaptionSize,
					graphics.TextColor
				)
			end
			local stored = update.Slots[index]
			local storedLine = if type(stored) == "string" then roleOf(stored) else "EMPTY"
			for _, line in storedIcons[index]:GetChildren() do
				if line:IsA("Frame") then
					line.BackgroundTransparency = if type(stored) == "string" then 0 else floating.InactiveTransparency
				end
			end
			storedText.Text =
				InputHints.bracket(controls.Disguise, controls.DisguisePad, `SLOT {index} · {storedLine}`)
		end
	end
end

local function setRing(progress: number?)
	for index, tick in ringSegments do
		tick.Visible = progress ~= nil
		if progress then
			tick.BackgroundColor3 = if index / #ringSegments <= progress then ui.ScanRingColor else ui.ScanRingDimColor
		end
	end
end

local function cancelScan()
	scanHeld = false
	scanStartedAt = nil
	setRing(nil)
	if scanSentTarget then
		scanSentTarget = nil
		RemoteController.fire("RequestScan", nil)
	end
end

local function onScan(_: string, state: Enum.UserInputState)
	if state == Enum.UserInputState.Begin then
		scanHeld = HeldItemController.canAct()
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		cancelScan()
	end
	return Enum.ContextActionResult.Pass
end

local function onDisguise(_: string, state: Enum.UserInputState)
	if state == Enum.UserInputState.Begin and HeldItemController.canAct() then
		RemoteController.fire("RequestDisguise")
	end
	return Enum.ContextActionResult.Pass
end

local function onSprint(_: string, state: Enum.UserInputState)
	if state == Enum.UserInputState.Begin and HeldItemController.canAct() and not sprintHeld then
		sprintHeld = true
		RemoteController.fire("RequestSprint", true)
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		if sprintHeld then
			sprintHeld = false
			RemoteController.fire("RequestSprint", false)
		end
	end
	return Enum.ContextActionResult.Pass
end

-- The crouch pose goes on our own character, so it replicates to everyone like any animation we play.
local function setCrouch(on: boolean)
	if crouchHeld == on then
		return
	end
	crouchHeld = on
	RemoteController.fire("RequestCrouch", on)
	if not on and crouchTrack then
		crouchTrack:Stop(GameConfig.NPC.AnimationFadeSeconds)
		crouchTrack:Destroy()
		crouchTrack = nil
	end
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	humanoid.CameraOffset = if on then Vector3.new(0, -GameConfig.Cover.CrouchCameraDrop, 0) else Vector3.zero
	if on then
		local animator = humanoid:FindFirstChildOfClass("Animator")
		local animation = PoseAnimation.registerAll().Crouch
		if animator and animation and not crouchTrack then
			crouchTrack = animator:LoadAnimation(animation)
			crouchTrack:Play(GameConfig.NPC.AnimationFadeSeconds)
		end
	end
end

local function onCrouch(_: string, state: Enum.UserInputState)
	if state == Enum.UserInputState.Begin and HeldItemController.canAct() then
		setCrouch(true)
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		setCrouch(false)
	end
	return Enum.ContextActionResult.Pass
end

local function cancelMovementInputs()
	cancelScan()
	if sprintHeld then
		sprintHeld = false
		RemoteController.fire("RequestSprint", false)
	end
	setCrouch(false)
end

function DisguiseController.Init() end

function DisguiseController.Start()
	buildHud()

	ContextActionService:BindAction("Scan", onScan, false, controls.Scan, controls.ScanPad)
	ContextActionService:BindAction("Disguise", onDisguise, false, controls.Disguise, controls.DisguisePad)
	ContextActionService:BindAction("Sprint", onSprint, false, controls.Sprint)
	ContextActionService:BindAction("Crouch", onCrouch, false, controls.Crouch)
	janitor:Add(function()
		cancelMovementInputs()
		for _, action in { "Scan", "Disguise", "Sprint", "Crouch" } do
			ContextActionService:UnbindAction(action)
		end
		if crouchTrack then
			crouchTrack:Stop()
			crouchTrack:Destroy()
			crouchTrack = nil
		end
		toastToken += 1
	end)

	-- A new body starts standing.
	janitor:Add(localPlayer.CharacterAdded:Connect(function()
		cancelMovementInputs()
		if crouchTrack then
			crouchTrack:Destroy()
		end
		crouchTrack = nil
	end))
	janitor:Add(localPlayer.CharacterRemoving:Connect(cancelMovementInputs))
	janitor:Add(UserInputService.WindowFocusReleased:Connect(cancelMovementInputs))
	janitor:Add(UserInputService.TextBoxFocused:Connect(cancelMovementInputs))
	janitor:Add(GuiService.MenuOpened:Connect(cancelMovementInputs))

	janitor:Add(RemoteController.connect("DisguiseUpdate", function(update: Types.DisguiseUpdate)
		showDisguise(update)
	end))
	janitor:Add(InputHints.onChange(function()
		hintUntil = os.clock() + floating.HintSeconds
		if latestDisguise then
			showDisguise(latestDisguise)
		end
	end))
	janitor:Add(RemoteController.connect("Notification", function(text: string)
		showToast(text)
	end))
	janitor:Add(RemoteController.connect("ScanState", function(info: { State: string, Seconds: number? })
		if info.State == "Started" and scanHeld and HeldItemController.canAct() then
			scanStartedAt = os.clock()
			scanSeconds = info.Seconds or GameConfig.Cover.ScanSeconds
		else
			-- Hold or re-aim to try again; the same aim is not sent twice, so a finished scan does not repeat.
			scanStartedAt = nil
			setRing(nil)
			if info.State == "Done" then
				showToast("Disguise stored")
			end
		end
	end))

	janitor:Add(RunService.RenderStepped:Connect(function()
		local hintVisible = os.clock() < hintUntil
		if badge then
			badge.Visible = hintVisible or (latestDisguise ~= nil and latestDisguise.Exposed)
		end
		for _, text in storedBadges do
			text.Visible = hintVisible
		end
		local canAct = HeldItemController.canAct()
		if not canAct and (scanHeld or sprintHeld or crouchHeld or scanStartedAt ~= nil) then
			cancelMovementInputs()
		end
		if centerDot then
			local status = WeaponController.getStatus()
			centerDot.Visible = canAct and status.active and not status.attackBlocked
		end
		if scanHeld then
			-- Tell the server what we are aiming at whenever it changes; it does the rest.
			local target = Aim.characterName(GameConfig.Cover.ScanRange)
			if target ~= scanSentTarget then
				scanSentTarget = target
				RemoteController.fire("RequestScan", target)
			end
		end
		if scanStartedAt then
			setRing(math.clamp((os.clock() - scanStartedAt) / scanSeconds, 0, 1))
		end
	end))
	janitor:Add(script.Destroying:Connect(function()
		janitor:Destroy()
	end))
end

return DisguiseController
