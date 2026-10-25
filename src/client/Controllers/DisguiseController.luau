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

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local OutfitDefs = require(Shared:WaitForChild("Defs"):WaitForChild("OutfitDefs"))
local Types = require(Shared:WaitForChild("Types"))
local Aim = require(Shared:WaitForChild("Util"):WaitForChild("Aim"))
local HudKit = require(Shared:WaitForChild("Util"):WaitForChild("HudKit"))
local HudTheme = require(Shared:WaitForChild("Util"):WaitForChild("HudTheme"))
local Janitor = require(Shared:WaitForChild("Util"):WaitForChild("Janitor"))
local PoseAnimation = require(Shared:WaitForChild("Util"):WaitForChild("PoseAnimation"))
local RemoteController = require(script.Parent.RemoteController)
local WeaponController = require(script.Parent.WeaponController)

local DisguiseController = {}
local janitor = Janitor.new()

local ui = GameConfig.UI
local graphics = HudTheme.get()
local controls = GameConfig.Controls
local localPlayer = Players.LocalPlayer

local scanHeld = false
local scanSentTarget: string? = nil
local scanStartedAt: number? = nil
local scanSeconds = 0

local ringSegments: { Frame } = {}
local centerDot: Frame? = nil
local badge: TextLabel? = nil
local storedBadge: TextLabel? = nil
local tierPips: { Frame } = {}
local toast: TextLabel? = nil
local toastToken = 0
local crouchTrack: AnimationTrack? = nil

local function buildHud()
	local gui = HudKit.screen("DisguiseHud")
	janitor:Add(gui)

	local dot = Instance.new("Frame")
	dot.Name = "Dot"
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromScale(0.5, 0.5)
	dot.Size = UDim2.fromOffset(ui.CrosshairPixels, ui.CrosshairPixels)
	dot.BackgroundColor3 = ui.TextColor
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

	local badgePanel = HudKit.panel(
		gui,
		"Disguise",
		UDim2.new(0, graphics.MarginPixels, 1, -graphics.CoverBottomPixels),
		Vector2.new(0, 1),
		UDim2.fromOffset(graphics.VitalsWidthPixels, graphics.PaddingPixels * 4)
	)
	HudKit.icon(
		badgePanel,
		"Badge",
		UDim2.fromOffset(graphics.PaddingPixels, graphics.PaddingPixels),
		graphics.IconPixels,
		ui.TextColor
	)
	local badgeText = HudKit.text(
		badgePanel,
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
		pip.Parent = badgePanel
		tierPips[index] = pip
	end
	storedBadge = HudKit.text(
		badgePanel,
		"Stored",
		UDim2.fromOffset(graphics.PaddingPixels * 2 + graphics.IconPixels, graphics.PaddingPixels * 2),
		Vector2.zero,
		UDim2.new(1, -graphics.PaddingPixels * 3 - graphics.IconPixels, 0, graphics.CaptionSize)
	)
	storedBadge.TextSize = graphics.CaptionSize
	storedBadge.TextColor3 = ui.DimTextColor
	storedBadge.TextXAlignment = Enum.TextXAlignment.Left

	local toastText =
		HudKit.text(gui, "Toast", UDim2.new(0.5, 0, 0, 80), Vector2.new(0.5, 0), UDim2.fromOffset(420, 24))
	toastText.TextTransparency = 1
	toastText.TextStrokeTransparency = 1
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
	toastText.TextTransparency = 0
	toastText.TextStrokeTransparency = 0.5
	task.delay(ui.ToastSeconds, function()
		if token == toastToken then
			toastText.TextTransparency = 1
			toastText.TextStrokeTransparency = 1
		end
	end)
end

local function roleOf(outfitId: string): string
	local outfit = OutfitDefs.byId[outfitId]
	return if outfit then string.upper(outfit.Role) else "?"
end

local function showDisguise(update: Types.DisguiseUpdate)
	local text = badge
	if not text then
		return
	end
	local stored = update.Slots[1]
	local storedLine = if type(stored) == "string" then roleOf(stored) else "EMPTY"
	local wornLine = if update.Exposed then "TRUE FORM" else roleOf(update.Worn)
	text.Text = wornLine
	local outfit = OutfitDefs.byId[update.Worn]
	local tier = if outfit and not update.Exposed then outfit.Tier else 0
	text.TextColor3 = if update.Exposed then ui.CoverColors.Exposed else GameConfig.Zones.TierColors[tier]
	for index, pip in tierPips do
		pip.BackgroundColor3 = if index <= tier then GameConfig.Zones.TierColors[tier] else ui.ScanRingDimColor
	end
	if storedBadge then
		storedBadge.Text = `{controls.Disguise.Name} / {storedLine}`
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

local function onScan(_: string, state: Enum.UserInputState)
	if state == Enum.UserInputState.Begin then
		scanHeld = true
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		scanHeld = false
		if scanSentTarget then
			scanSentTarget = nil
			RemoteController.fire("RequestScan", nil)
		end
	end
	return Enum.ContextActionResult.Pass
end

local function onDisguise(_: string, state: Enum.UserInputState)
	if state == Enum.UserInputState.Begin then
		RemoteController.fire("RequestDisguise")
	end
	return Enum.ContextActionResult.Pass
end

local function onSprint(_: string, state: Enum.UserInputState)
	if state == Enum.UserInputState.Begin then
		RemoteController.fire("RequestSprint", true)
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		RemoteController.fire("RequestSprint", false)
	end
	return Enum.ContextActionResult.Pass
end

-- The crouch pose goes on our own character, so it replicates to everyone like any animation we play.
local function setCrouch(on: boolean)
	RemoteController.fire("RequestCrouch", on)
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
	elseif crouchTrack then
		crouchTrack:Stop(GameConfig.NPC.AnimationFadeSeconds)
		crouchTrack = nil
	end
end

local function onCrouch(_: string, state: Enum.UserInputState)
	if state == Enum.UserInputState.Begin then
		setCrouch(true)
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		setCrouch(false)
	end
	return Enum.ContextActionResult.Pass
end

function DisguiseController.Init() end

function DisguiseController.Start()
	buildHud()

	ContextActionService:BindAction("Scan", onScan, false, controls.Scan, controls.ScanPad)
	ContextActionService:BindAction("Disguise", onDisguise, false, controls.Disguise, controls.DisguisePad)
	ContextActionService:BindAction("Sprint", onSprint, false, controls.Sprint)
	ContextActionService:BindAction("Crouch", onCrouch, false, controls.Crouch)
	janitor:Add(function()
		for _, action in { "Scan", "Disguise", "Sprint", "Crouch" } do
			ContextActionService:UnbindAction(action)
		end
		if crouchTrack then
			crouchTrack:Stop()
		end
		toastToken += 1
	end)

	-- A new body starts standing.
	janitor:Add(localPlayer.CharacterAdded:Connect(function()
		crouchTrack = nil
	end))

	janitor:Add(RemoteController.connect("DisguiseUpdate", function(update: Types.DisguiseUpdate)
		showDisguise(update)
	end))
	janitor:Add(RemoteController.connect("Notification", function(text: string)
		showToast(text)
	end))
	janitor:Add(RemoteController.connect("ScanState", function(info: { State: string, Seconds: number? })
		if info.State == "Started" then
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
		if centerDot then
			local status = WeaponController.getStatus()
			centerDot.Visible = status.active and not status.attackBlocked
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
