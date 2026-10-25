--!strict
-- The weapon's part of the screen (spec 21, STEP8; the real HUD replaces it in Step 19): a crosshair that opens with the
-- shot spread, hitmarkers (grey for an NPC, red for an agent, bigger and higher-pitched for a headshot, spec 8.4), red
-- markers pointing at whoever shot you, health with its armour plates, the ammo count, and the takedown bar.
--
-- The server owns every number here. The crosshair and ammo are the weapon's own prediction (WeaponController).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Types = require(Shared:WaitForChild("Types"))
local HudKit = require(Shared:WaitForChild("Util"):WaitForChild("HudKit"))
local HudTheme = require(Shared:WaitForChild("Util"):WaitForChild("HudTheme"))
local UiAccessibility = require(Shared.Util.UiAccessibility)
local Janitor = require(Shared:WaitForChild("Util"):WaitForChild("Janitor"))
local SoundPlayer = require(script.Parent.Parent:WaitForChild("Combat"):WaitForChild("SoundPlayer"))
local RemoteController = require(script.Parent.RemoteController)
local WeaponController = require(script.Parent.WeaponController)

type Marker = { label: TextLabel, position: Vector3, expires: number }

local CombatHudController = {}
local janitor = Janitor.new()

local combat = GameConfig.Combat
local feedback = combat.Feedback
local ui = GameConfig.UI
local graphics = HudTheme.get()
local localPlayer = Players.LocalPlayer

local BAR_WIDTH = graphics.VitalsWidthPixels - graphics.PaddingPixels * 2
local BAR_HEIGHT = 8
local MARGIN = graphics.MarginPixels
local VITALS_BOTTOM = combat.Hud.VitalsBottomPixels
local CROSSHAIR_THICKNESS = 2
local TAKEDOWN_WIDTH = 160
local TAKEDOWN_BAR_HEIGHT = 6
local TAKEDOWN_OFFSET = 70 -- pixels below the centre of the screen

local hp = combat.MaxHP
local armor = combat.StartPlates * combat.PlateHP
local hitAt = -math.huge
local hitColor = feedback.NpcHitColor
local hitScale = 1
local takedownStartedAt: number? = nil
local takedownSeconds = 0
local markers: { Marker } = {}

local screen: ScreenGui? = nil
local crosshair: { [string]: Frame } = {}
local hitmarkerBars: { Frame } = {}
local healthText: TextLabel? = nil
local healthFill: Frame? = nil
local plates: { Frame } = {}
local ammoText: TextLabel? = nil
local takedownBack: Frame? = nil
local takedownFill: Frame? = nil
local obstruction: Frame? = nil
local vitalsPanel: Frame? = nil
local reloadFill: Frame? = nil
local reloadBack: Frame? = nil
local weaponCaption: TextLabel? = nil
local shownHP = hp / combat.MaxHP
local shownArmor = armor
local damageAt = -math.huge

local function bar(parent: Instance, name: string, color: Color3): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundColor3 = color
	frame.BorderSizePixel = 0
	frame.Parent = parent
	return frame
end

local function build()
	local gui = HudKit.screen("CombatHud")
	janitor:Add(gui)
	screen = gui
	-- Ticket 8.15: the normal reticle is replaced, not overlaid, when the same attack gate reports obstruction.
	local blocked = Instance.new("Frame")
	blocked.Name = "ObstructionReticle"
	blocked.AnchorPoint = Vector2.new(0.5, 0.5)
	blocked.Position = UDim2.fromScale(0.5, 0.5)
	blocked.Size = UDim2.fromOffset(combat.Hud.BlockedReticlePixels, combat.Hud.BlockedReticlePixels)
	blocked.BackgroundTransparency = 1
	blocked.Visible = false
	blocked.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = blocked
	local outline = Instance.new("UIStroke")
	outline.Color = ui.WarningColor
	outline.Thickness = CROSSHAIR_THICKNESS
	outline.Parent = blocked
	local slash = bar(blocked, "Slash", ui.WarningColor)
	slash.AnchorPoint = Vector2.new(0.5, 0.5)
	slash.Position = UDim2.fromScale(0.5, 0.5)
	slash.Size = UDim2.new(1, 0, 0, CROSSHAIR_THICKNESS)
	slash.Rotation = -45
	local caption = HudKit.text(
		blocked,
		"Caption",
		UDim2.new(0.5, 0, 1, combat.Hud.BlockedLabelGapPixels),
		Vector2.new(0.5, 0),
		UDim2.fromOffset(combat.Hud.BlockedLabelWidthPixels, ui.TextSize)
	)
	caption.Text = "OBSTRUCTED"
	caption.TextColor3 = ui.WarningColor
	obstruction = blocked

	for _, side in { "Left", "Right", "Up", "Down" } do
		local line = bar(gui, `Crosshair{side}`, feedback.CrosshairColor)
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.Visible = false
		crosshair[side] = line
	end

	-- Four short diagonal strokes round the centre.
	for _, rotation in { 45, -45, 45, -45 } do
		local stroke = bar(gui, "Hitmarker", feedback.NpcHitColor)
		stroke.AnchorPoint = Vector2.new(0.5, 0.5)
		stroke.Rotation = rotation
		stroke.BackgroundTransparency = 1
		table.insert(hitmarkerBars, stroke)
	end

	local vitals = HudKit.panel(
		gui,
		"Vitals",
		UDim2.new(0, MARGIN, 1, -VITALS_BOTTOM + BAR_HEIGHT),
		Vector2.new(0, 1),
		UDim2.fromOffset(graphics.VitalsWidthPixels, graphics.VitalsHeightPixels)
	)
	vitalsPanel = vitals
	HudKit.icon(
		vitals,
		"Health",
		UDim2.fromOffset(graphics.PaddingPixels, graphics.PaddingPixels),
		graphics.IconPixels,
		feedback.HealthColor
	)
	local health = HudKit.text(
		vitals,
		"Health",
		UDim2.fromOffset(graphics.PaddingPixels * 2 + graphics.IconPixels, 0),
		Vector2.zero,
		UDim2.fromOffset(BAR_WIDTH - graphics.IconPixels, graphics.PaddingPixels * 3)
	)
	health.TextSize = graphics.NumberSize
	health.TextXAlignment = Enum.TextXAlignment.Left
	healthText = health
	local back = bar(vitals, "HealthBack", ui.ScanRingDimColor)
	back.Position = UDim2.fromOffset(graphics.PaddingPixels, graphics.PaddingPixels * 3)
	back.Size = UDim2.fromOffset(BAR_WIDTH, BAR_HEIGHT)
	healthFill = bar(back, "Fill", feedback.HealthColor)
	for index = 1, combat.MaxPlates do
		local plateBack = bar(vitals, `PlateBack{index}`, ui.ScanRingDimColor)
		local plateWidth = (BAR_WIDTH - graphics.PaddingPixels * (combat.MaxPlates - 1)) / combat.MaxPlates
		plateBack.Position = UDim2.fromOffset(
			graphics.PaddingPixels + (index - 1) * (plateWidth + graphics.PaddingPixels),
			graphics.VitalsHeightPixels - graphics.PaddingPixels - BAR_HEIGHT
		)
		plateBack.Size = UDim2.fromOffset(plateWidth, BAR_HEIGHT)
		plates[index] = bar(plateBack, "Fill", feedback.ArmorColor)
	end

	local ammoPanel = HudKit.panel(
		gui,
		"Ammunition",
		UDim2.new(1, -MARGIN, 1, -MARGIN),
		Vector2.new(1, 1),
		UDim2.fromOffset(graphics.AmmoWidthPixels, graphics.AmmoHeightPixels)
	)
	HudKit.icon(
		ammoPanel,
		"Bullet",
		UDim2.fromOffset(graphics.PaddingPixels, graphics.PaddingPixels * 3),
		graphics.IconPixels,
		graphics.TextColor
	)
	weaponCaption = HudKit.text(
		ammoPanel,
		"Weapon",
		UDim2.fromOffset(graphics.PaddingPixels, graphics.PaddingPixels),
		Vector2.zero,
		UDim2.new(1, -graphics.PaddingPixels * 2, 0, graphics.CaptionSize)
	)
	weaponCaption.TextSize = graphics.CaptionSize
	weaponCaption.TextColor3 = graphics.DimTextColor
	weaponCaption.TextXAlignment = Enum.TextXAlignment.Right
	local ammo = HudKit.text(
		ammoPanel,
		"Ammo",
		UDim2.new(1, -graphics.PaddingPixels, 1, -graphics.PaddingPixels * 2),
		Vector2.new(1, 1),
		UDim2.new(1, -graphics.PaddingPixels * 3 - graphics.IconPixels, 0, graphics.NumberSize)
	)
	ammo.TextSize = graphics.NumberSize
	ammo.TextXAlignment = Enum.TextXAlignment.Right
	ammo.TextYAlignment = Enum.TextYAlignment.Bottom
	ammoText = ammo
	local reload = bar(ammoPanel, "ReloadProgress", ui.ScanRingDimColor)
	reload.Position = UDim2.new(0, graphics.PaddingPixels, 1, -graphics.PaddingPixels)
	reload.Size = UDim2.new(1, -graphics.PaddingPixels * 2, 0, graphics.ReloadBarPixels)
	reloadBack = reload
	reloadFill = bar(reload, "Fill", feedback.ArmorColor)

	local takedown = bar(gui, "TakedownBack", ui.ScanRingDimColor)
	takedown.AnchorPoint = Vector2.new(0.5, 0.5)
	takedown.Position = UDim2.new(0.5, 0, 0.5, TAKEDOWN_OFFSET)
	takedown.Size = UDim2.fromOffset(TAKEDOWN_WIDTH, TAKEDOWN_BAR_HEIGHT)
	takedown.Visible = false
	takedownBack = takedown
	takedownFill = bar(takedown, "Fill", feedback.AgentHitColor)
end

-- How many pixels of the screen a cone of `degrees` covers from the centre.
local function degreesToPixels(degrees: number, fov: number, viewportHeight: number): number
	return math.tan(math.rad(degrees)) * (viewportHeight / 2) / math.tan(math.rad(fov / 2))
end

local function updateCrosshair(viewportHeight: number)
	local status = WeaponController.getStatus()
	if obstruction then
		obstruction.Visible = status.attackBlocked
	end
	local reach = degreesToPixels(status.spreadDegrees, status.viewportFov, viewportHeight)
		+ feedback.CrosshairGapPixels
	local length = feedback.CrosshairLengthPixels
	for side, line in crosshair do
		line.Visible = status.weaponUp and not status.attackBlocked
		local horizontal = side == "Left" or side == "Right"
		local direction = if side == "Left" or side == "Up" then -1 else 1
		line.Size = if horizontal
			then UDim2.fromOffset(length, CROSSHAIR_THICKNESS)
			else UDim2.fromOffset(CROSSHAIR_THICKNESS, length)
		local along = direction * (reach + length / 2)
		line.Position = if horizontal then UDim2.new(0.5, along, 0.5, 0) else UDim2.new(0.5, 0, 0.5, along)
	end
	if ammoText then
		ammoText.Text = `{status.mag} / {status.reserve}`
		ammoText.TextColor3 = if status.mag == 0 then feedback.LowHealthColor else graphics.TextColor
	end
	if weaponCaption then
		weaponCaption.Text = status.name
	end
	if reloadBack and reloadFill then
		reloadBack.Visible = status.reloading
		reloadFill.Size = UDim2.fromScale(status.reloadProgress or 0, 1)
	end
end

local function updateHitmarker(now: number)
	local age = now - hitAt
	local fade = if UiAccessibility.reducedMotion()
		then (if age < feedback.HitmarkerSeconds then 0 else 1)
		else math.clamp(age / feedback.HitmarkerSeconds, 0, 1)
	local pixels = feedback.HitmarkerPixels * hitScale
	local offset = pixels * 0.5
	local corners = { Vector2.new(-1, -1), Vector2.new(1, 1), Vector2.new(1, -1), Vector2.new(-1, 1) }
	for index, stroke in hitmarkerBars do
		stroke.BackgroundColor3 = hitColor
		stroke.BackgroundTransparency = fade
		stroke.Size = UDim2.fromOffset(pixels * 0.6, CROSSHAIR_THICKNESS)
		local corner = corners[index]
		stroke.Position = UDim2.new(0.5, corner.X * offset, 0.5, corner.Y * offset)
	end
end

local function updateMarkers(camera: Camera, now: number)
	for index = #markers, 1, -1 do
		local marker = markers[index]
		if now >= marker.expires then
			marker.label:Destroy()
			table.remove(markers, index)
		else
			local toSource = marker.position - camera.CFrame.Position
			local angle = math.atan2(toSource:Dot(camera.CFrame.RightVector), toSource:Dot(camera.CFrame.LookVector))
			local radius = feedback.DamageIndicatorPixels
			marker.label.Position = UDim2.new(0.5, math.sin(angle) * radius, 0.5, -math.cos(angle) * radius)
			marker.label.Rotation = math.deg(angle)
			marker.label.TextTransparency = if UiAccessibility.reducedMotion()
				then 0
				else 1 - (marker.expires - now) / feedback.DamageIndicatorSeconds
		end
	end
end

local function updateVitals(dt: number, now: number)
	local reduced = UiAccessibility.reducedMotion()
	local settle = if reduced then 1 else 1 - math.exp(-graphics.MeterSettleSpeed * dt)
	shownHP += (hp / combat.MaxHP - shownHP) * settle
	shownArmor += (armor - shownArmor) * settle
	if vitalsPanel then
		local pulse = if reduced then 0 else math.clamp(1 - (now - damageAt) / graphics.DamagePulseSeconds, 0, 1)
		vitalsPanel.BackgroundColor3 = graphics.PanelColor:Lerp(feedback.LowHealthColor, pulse)
		vitalsPanel.BackgroundTransparency = graphics.PanelTransparency
			+ (graphics.DamagePulseTransparency - graphics.PanelTransparency) * pulse
	end
	if healthText and healthFill then
		local fraction = hp / combat.MaxHP
		healthText.Text = `{math.ceil(hp)}`
		healthFill.Size = UDim2.fromScale(math.clamp(shownHP, 0, 1), 1)
		local color = if fraction <= feedback.LowHealthFraction then feedback.LowHealthColor else feedback.HealthColor
		healthFill.BackgroundColor3 = color
		healthText.TextColor3 = if fraction <= feedback.LowHealthFraction then color else graphics.TextColor
	end
	for index, fill in plates do
		fill.Size = UDim2.fromScale(math.clamp((shownArmor - (index - 1) * combat.PlateHP) / combat.PlateHP, 0, 1), 1)
	end
end

local function update(dt: number)
	local camera = workspace.CurrentCamera
	if not (screen and camera) then
		return
	end
	local now = os.clock()
	updateCrosshair(camera.ViewportSize.Y)
	updateHitmarker(now)
	updateMarkers(camera, now)
	updateVitals(dt, now)
	if takedownBack and takedownFill then
		local started = takedownStartedAt
		takedownBack.Visible = started ~= nil
		if started then
			takedownFill.Size =
				UDim2.fromScale(math.clamp((workspace:GetServerTimeNow() - started) / takedownSeconds, 0, 1), 1)
		end
	end
end

local function onHit(info: Types.HitConfirm)
	hitAt = os.clock()
	hitColor = if info.Kind == "Agent" then feedback.AgentHitColor else feedback.NpcHitColor
	hitScale = if info.Head then feedback.HeadshotHitmarkerScale else 1
	local sound = if info.Head
		then feedback.HitSounds.Head
		elseif info.Kind == "Agent" then feedback.HitSounds.Agent
		else feedback.HitSounds.Npc
	SoundPlayer.play(sound, feedback.HitSoundVolume, if info.Head then feedback.HeadshotPitch else 1)
end

local function onDamage(info: Types.DamageInfo)
	local gui = screen
	if not gui then
		return
	end
	local label = Instance.new("TextLabel")
	label.Name = "DamageMarker"
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromOffset(28, 28)
	label.Font = ui.Font
	label.TextSize = ui.TextSize + 6
	label.Text = "▲"
	label.TextColor3 = feedback.DamageIndicatorColor
	label.TextStrokeTransparency = 0.5
	label.Parent = gui
	table.insert(markers, {
		label = label,
		position = info.Position,
		expires = os.clock() + feedback.DamageIndicatorSeconds,
	})
end

function CombatHudController.Init() end

function CombatHudController.Start()
	build()
	SoundPlayer.preload({ feedback.HitSounds.Npc, feedback.HitSounds.Agent, feedback.HitSounds.Head })
	janitor:Add(RemoteController.connect("HitConfirm", onHit))
	janitor:Add(RemoteController.connect("DamageTaken", onDamage))
	janitor:Add(RemoteController.connect("HealthUpdate", function(info: Types.HealthInfo)
		if info.HP < hp or info.Armor < armor then
			damageAt = os.clock()
		end
		hp, armor = info.HP, info.Armor
	end))
	janitor:Add(RemoteController.connect("MeleeState", function(info: Types.MeleeState)
		-- Ticket 8.22: shared bar shows server-timed charge or takedown; Strike is an acknowledgement, not a finisher.
		takedownStartedAt = if info.Active then (info.StartedAt or workspace:GetServerTimeNow()) else nil
		takedownSeconds = info.Seconds
		if takedownFill then
			takedownFill.BackgroundColor3 = if info.Kind == "Charge"
				then feedback.ArmorColor
				else feedback.AgentHitColor
		end
	end))
	janitor:Add(localPlayer.CharacterAdded:Connect(function()
		hp, armor = combat.MaxHP, combat.StartPlates * combat.PlateHP
		shownHP, shownArmor = hp / combat.MaxHP, armor
		damageAt = -math.huge
		takedownStartedAt = nil
	end))
	janitor:Add(RunService.RenderStepped:Connect(update))
	janitor:Add(script.Destroying:Connect(function()
		janitor:Destroy()
	end))
end

return CombatHudController
