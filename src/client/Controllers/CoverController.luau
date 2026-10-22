--!strict
-- The player's own cover on screen (spec 7, 21): a meter at the bottom, a restricted-area warning, a "cover available"
-- prompt, the loud flash, text and vignette when exposed, pings for enemies exposed nearby, and a debug panel (state,
-- suspicion, zone, witnesses, alarm) that stays until the real HUD in Step 19.
--
-- The server owns every number here and sends only this player's own state. Nothing is predicted.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Types = require(Shared:WaitForChild("Types"))
local HudKit = require(Shared:WaitForChild("Util"):WaitForChild("HudKit"))
local RemoteController = require(script.Parent.RemoteController)

type Ping = { position: Vector3, expires: number, label: TextLabel }

local CoverController = {}

local ui = GameConfig.UI
local cover = GameConfig.Cover
local localPlayer = Players.LocalPlayer

local gui: ScreenGui? = nil
local panel: TextLabel? = nil
local stateLabel: TextLabel? = nil
local meterFill: Frame? = nil
local warning: TextLabel? = nil
local prompt: TextLabel? = nil
local exposedText: TextLabel? = nil
local flash: Frame? = nil
local vignette: HudKit.EdgeGlow? = nil

local coverState: Types.CoverState = "Covered"
local canRecover = false
local blocker = ""
local lockoutEndsAt = 0
local exposedMinEndsAt = 0
local suspicion: Types.SuspicionInfo = { Value = 0, Security = 0, Npc = 0, Camera = 0 }
local trespass: Types.TrespassInfo = { Restricted = false, ZoneTier = 0, Clearance = 0 }
local alarm = 0

local exposedAt = -math.huge
local pingFlashAt = -math.huge
local pings: { Ping } = {}

local function build()
	local screen = HudKit.screen("CoverHud")
	gui = screen

	local flashFrame = Instance.new("Frame")
	flashFrame.Name = "Flash"
	flashFrame.Size = UDim2.fromScale(1, 1)
	flashFrame.BackgroundColor3 = ui.CoverColors.Exposed
	flashFrame.BackgroundTransparency = 1
	flashFrame.BorderSizePixel = 0
	flashFrame.Parent = screen
	flash = flashFrame

	vignette = HudKit.edgeGlow(screen, ui.CoverColors.Exposed)

	local debugPanel = HudKit.text(screen, "Debug", UDim2.new(0, 16, 0, 16), Vector2.zero, UDim2.fromOffset(300, 120))
	debugPanel.TextXAlignment = Enum.TextXAlignment.Left
	debugPanel.TextYAlignment = Enum.TextYAlignment.Top
	debugPanel.TextSize = ui.TextSize - 4
	panel = debugPanel

	-- The meter (spec 21): state text above a bar that fills left to right.
	local meterBack = Instance.new("Frame")
	meterBack.Name = "Meter"
	meterBack.AnchorPoint = Vector2.new(0.5, 1)
	meterBack.Position = UDim2.new(0.5, 0, 1, -24)
	meterBack.Size = UDim2.fromOffset(ui.MeterWidthPixels, ui.MeterHeightPixels)
	meterBack.BackgroundColor3 = ui.ScanRingDimColor
	meterBack.BorderSizePixel = 0
	meterBack.Parent = screen
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BorderSizePixel = 0
	fill.Parent = meterBack
	meterFill = fill
	stateLabel = HudKit.text(screen, "State", UDim2.new(0.5, 0, 1, -38), Vector2.new(0.5, 1), UDim2.fromOffset(300, 24))

	local warningText =
		HudKit.text(screen, "Warning", UDim2.new(0.5, 0, 0, 120), Vector2.new(0.5, 0), UDim2.fromOffset(500, 36))
	warningText.TextColor3 = ui.WarningColor
	warningText.TextSize = ui.TextSize + 10
	warningText.Visible = false
	warning = warningText

	local promptText =
		HudKit.text(screen, "Prompt", UDim2.new(0.5, 0, 1, -80), Vector2.new(0.5, 1), UDim2.fromOffset(400, 24))
	promptText.Visible = false
	prompt = promptText

	local bigText =
		HudKit.text(screen, "Exposed", UDim2.fromScale(0.5, 0.3), Vector2.new(0.5, 0.5), UDim2.fromOffset(600, 80))
	bigText.Text = "EXPOSED"
	bigText.TextColor3 = ui.CoverColors.Exposed
	bigText.TextSize = ui.TextSize + 32
	bigText.Visible = false
	exposedText = bigText
end

local function refreshText(now: number)
	local fill, label, debugPanel, warn, hint = meterFill, stateLabel, panel, warning, prompt
	if not (fill and label and debugPanel and warn and hint) then
		return
	end
	local color = ui.CoverColors[coverState]
	fill.BackgroundColor3 = color
	fill.Size = UDim2.fromScale(math.clamp(suspicion.Value / cover.SuspicionMax, 0, 1), 1)
	label.Text = string.upper(coverState)
	label.TextColor3 = color

	local lockout = math.max(0, lockoutEndsAt - now)
	local lines = {
		`COVER {string.upper(coverState)}`,
		`SUSPICION {suspicion.Value}%`,
		`ZONE T{trespass.ZoneTier}  CLEARANCE T{trespass.Clearance}`,
		`WITNESSES S{suspicion.Security} N{suspicion.Npc} C{suspicion.Camera}`,
		`ALARM {alarm}`,
	}
	if lockout > 0 then
		table.insert(lines, string.format("LOCKOUT %.1fs", lockout))
	end
	debugPanel.Text = table.concat(lines, "\n")

	-- The restricted-area warning is always up while above clearance; it says so when someone is watching.
	local watched = suspicion.Security + suspicion.Npc + suspicion.Camera > 0
	warn.Visible = trespass.Restricted and coverState ~= "Exposed"
	warn.Text = if watched then "SUSPECTED: RESTRICTED AREA" else "RESTRICTED AREA"

	local waitSeconds = math.max(lockout, exposedMinEndsAt - now)
	hint.Visible = coverState == "Exposed"
	if canRecover then
		hint.Text = "COVER AVAILABLE [G]"
		hint.TextColor3 = ui.CoverColors.Covered
	else
		if blocker == "Zone" then
			hint.Text = "LEAVE THE RESTRICTED AREA TO RE-COVER"
		elseif blocker == "Seen" then
			hint.Text = "BREAK LINE OF SIGHT FROM GUARDS"
		else
			hint.Text = string.format("COVER IN %.0fs", math.max(waitSeconds, 0))
		end
		hint.TextColor3 = ui.DimTextColor
	end
end

-- The exposed effects fade on a timeline from the moment of exposure (STYLE_QUESTIONS C2).
local function updateEffects(now: number)
	local flashFrame, glow, text = flash, vignette, exposedText
	if not (flashFrame and glow and text) then
		return
	end
	local age = now - exposedAt
	local flashAlpha = 1
	if age < ui.ExposedFlashSeconds then
		flashAlpha = ui.ExposedFlashTransparency + (1 - ui.ExposedFlashTransparency) * (age / ui.ExposedFlashSeconds)
	end
	local pingAge = now - pingFlashAt
	if pingAge < ui.ExposedFlashSeconds then
		local pingAlpha = ui.PingFlashTransparency + (1 - ui.PingFlashTransparency) * (pingAge / ui.ExposedFlashSeconds)
		flashAlpha = math.min(flashAlpha, pingAlpha)
	end
	flashFrame.BackgroundTransparency = flashAlpha
	glow.setAll(if age < ui.ExposedVignetteSeconds then 0.2 + 0.8 * (age / ui.ExposedVignetteSeconds) else 1)
	text.Visible = age < ui.ExposedTextSeconds
end

-- A "!" where an enemy within range was exposed (spec 7.2), kept at the screen edge when it is off screen.
local function updatePings(now: number)
	local camera = workspace.CurrentCamera
	local screen = gui
	if not (camera and screen) then
		return
	end
	for index = #pings, 1, -1 do
		local ping = pings[index]
		if now >= ping.expires then
			ping.label:Destroy()
			table.remove(pings, index)
		else
			local point, onScreen = camera:WorldToViewportPoint(ping.position)
			local size = camera.ViewportSize
			local x, y = point.X, point.Y
			if not onScreen or point.Z < 0 then
				-- Behind or beside us: pin it to the edge on the side it is on.
				local relative = camera.CFrame:PointToObjectSpace(ping.position)
				local direction = Vector2.new(relative.X, -relative.Y)
				if direction.Magnitude < 1e-3 then
					direction = Vector2.new(0, 1)
				end
				direction = direction.Unit
				x = size.X / 2 + direction.X * (size.X / 2 - 30)
				y = size.Y / 2 + direction.Y * (size.Y / 2 - 30)
			end
			ping.label.Position = UDim2.fromOffset(math.clamp(x, 30, size.X - 30), math.clamp(y, 30, size.Y - 30))
		end
	end
end

function CoverController.Init() end

function CoverController.Start()
	build()

	RemoteController.connect("CoverStateChanged", function(info: Types.CoverInfo)
		local now = os.clock()
		if info.State == "Exposed" and coverState ~= "Exposed" then
			exposedAt = now
		end
		coverState = info.State
		canRecover = info.CanRecover
		blocker = info.Blocker
		lockoutEndsAt = now + info.LockoutSeconds
		exposedMinEndsAt = now + info.ExposedMinSeconds
	end)
	RemoteController.connect("SuspicionUpdate", function(info: Types.SuspicionInfo)
		suspicion = info
	end)
	RemoteController.connect("TrespassWarning", function(info: Types.TrespassInfo)
		trespass = info
	end)
	RemoteController.connect("AlarmLevel", function(level: number)
		alarm = level
	end)
	RemoteController.connect("ExposedPing", function(info: { Position: Vector3, Seconds: number })
		local screen = gui
		if not screen then
			return
		end
		local label =
			HudKit.text(screen, "Ping", UDim2.fromOffset(0, 0), Vector2.new(0.5, 0.5), UDim2.fromOffset(40, 40))
		label.Text = "!"
		label.TextColor3 = ui.CoverColors.Exposed
		label.TextSize = ui.TextSize + 24
		table.insert(pings, { position = info.Position, expires = os.clock() + info.Seconds, label = label })
		pingFlashAt = os.clock() -- a fainter version of the flash you get when you are exposed yourself
	end)

	-- A new body is Covered; the server sends the state again, but do not show the last life's.
	localPlayer.CharacterAdded:Connect(function()
		coverState = "Covered"
		canRecover = false
		suspicion = { Value = 0, Security = 0, Npc = 0, Camera = 0 }
	end)

	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		refreshText(now)
		updateEffects(now)
		updatePings(now)
	end)
end

return CoverController
