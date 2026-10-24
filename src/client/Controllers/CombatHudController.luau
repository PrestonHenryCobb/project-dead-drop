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
local SoundPlayer = require(script.Parent.Parent:WaitForChild("Combat"):WaitForChild("SoundPlayer"))
local RemoteController = require(script.Parent.RemoteController)
local WeaponController = require(script.Parent.WeaponController)

type Marker = { label: TextLabel, position: Vector3, expires: number }

local CombatHudController = {}

local combat = GameConfig.Combat
local feedback = combat.Feedback
local ui = GameConfig.UI
local localPlayer = Players.LocalPlayer

local BAR_WIDTH = 200
local BAR_HEIGHT = 8
local PLATE_WIDTH = 60
local MARGIN = 24
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
	screen = gui

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

	local health = HudKit.text(
		gui,
		"Health",
		UDim2.new(0, MARGIN, 1, -MARGIN - 28),
		Vector2.new(0, 1),
		UDim2.fromOffset(BAR_WIDTH, 24)
	)
	health.TextXAlignment = Enum.TextXAlignment.Left
	healthText = health
	local back = bar(gui, "HealthBack", ui.ScanRingDimColor)
	back.Position = UDim2.new(0, MARGIN, 1, -MARGIN - 14)
	back.Size = UDim2.fromOffset(BAR_WIDTH, BAR_HEIGHT)
	healthFill = bar(back, "Fill", feedback.HealthColor)
	for index = 1, combat.MaxPlates do
		local plateBack = bar(gui, `PlateBack{index}`, ui.ScanRingDimColor)
		plateBack.Position = UDim2.new(0, MARGIN + (index - 1) * (PLATE_WIDTH + 10), 1, -MARGIN)
		plateBack.Size = UDim2.fromOffset(PLATE_WIDTH, BAR_HEIGHT)
		plates[index] = bar(plateBack, "Fill", feedback.ArmorColor)
	end

	local ammo =
		HudKit.text(gui, "Ammo", UDim2.new(1, -MARGIN, 1, -MARGIN), Vector2.new(1, 1), UDim2.fromOffset(260, 56))
	ammo.TextXAlignment = Enum.TextXAlignment.Right
	ammo.TextYAlignment = Enum.TextYAlignment.Bottom
	ammoText = ammo

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
	local reach = degreesToPixels(status.spreadDegrees, status.viewportFov, viewportHeight)
		+ feedback.CrosshairGapPixels
	local length = feedback.CrosshairLengthPixels
	for side, line in crosshair do
		line.Visible = status.weaponUp
		local horizontal = side == "Left" or side == "Right"
		local direction = if side == "Left" or side == "Up" then -1 else 1
		line.Size = if horizontal
			then UDim2.fromOffset(length, CROSSHAIR_THICKNESS)
			else UDim2.fromOffset(CROSSHAIR_THICKNESS, length)
		local along = direction * (reach + length / 2)
		line.Position = if horizontal then UDim2.new(0.5, along, 0.5, 0) else UDim2.new(0.5, 0, 0.5, along)
	end
	if ammoText then
		local line = `{status.name}\n{status.mag} / {status.reserve}`
		ammoText.Text = if status.reloading then `{line}\nRELOADING` else line
		ammoText.TextColor3 = if status.mag == 0 then feedback.LowHealthColor else ui.TextColor
	end
end

local function updateHitmarker(now: number)
	local age = now - hitAt
	local fade = math.clamp(age / feedback.HitmarkerSeconds, 0, 1)
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
			marker.label.TextTransparency = 1 - (marker.expires - now) / feedback.DamageIndicatorSeconds
		end
	end
end

local function updateVitals()
	if healthText and healthFill then
		local fraction = hp / combat.MaxHP
		healthText.Text = `HP {math.ceil(hp)}`
		healthFill.Size = UDim2.fromScale(fraction, 1)
		local color = if fraction <= feedback.LowHealthFraction then feedback.LowHealthColor else feedback.HealthColor
		healthFill.BackgroundColor3 = color
		healthText.TextColor3 = if fraction <= feedback.LowHealthFraction then color else ui.TextColor
	end
	for index, fill in plates do
		fill.Size = UDim2.fromScale(math.clamp((armor - (index - 1) * combat.PlateHP) / combat.PlateHP, 0, 1), 1)
	end
end

local function update(_: number)
	local camera = workspace.CurrentCamera
	if not (screen and camera) then
		return
	end
	local now = os.clock()
	updateCrosshair(camera.ViewportSize.Y)
	updateHitmarker(now)
	updateMarkers(camera, now)
	updateVitals()
	if takedownBack and takedownFill then
		local started = takedownStartedAt
		takedownBack.Visible = started ~= nil
		if started then
			takedownFill.Size = UDim2.fromScale(math.clamp((now - started) / takedownSeconds, 0, 1), 1)
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
	RemoteController.connect("HitConfirm", onHit)
	RemoteController.connect("DamageTaken", onDamage)
	RemoteController.connect("HealthUpdate", function(info: Types.HealthInfo)
		hp, armor = info.HP, info.Armor
	end)
	RemoteController.connect("MeleeState", function(info: Types.MeleeState)
		takedownStartedAt = if info.Active then os.clock() else nil
		takedownSeconds = info.Seconds
	end)
	localPlayer.CharacterAdded:Connect(function()
		hp, armor = combat.MaxHP, combat.StartPlates * combat.PlateHP
		takedownStartedAt = nil
	end)
	RunService.RenderStepped:Connect(update)
end

return CombatHudController
