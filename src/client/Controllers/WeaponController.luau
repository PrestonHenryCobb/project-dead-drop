--!strict
-- The local player's weapon (spec 13, STEP8). Left mouse draws and fires, right mouse aims, R reloads, V strikes (and,
-- held from behind, takes down). The client predicts what it can feel at once: the shot's sound and jolt, the recoil, the
-- ammo count and the reload. The server decides everything that counts, and corrects ammo through AmmoUpdate.
--
--   * Firing sends a FireRequest with where the camera is, the direction of the shot (spread included), and the server
--     time it was fired at, so the server can rewind targets to what this screen showed (spec 13.3).
--   * Recoil is added to the camera after the default camera runs, then settles back, so shots follow the view.
--   * The first-person gun is a ViewModel: tucked across the chest while disguised, raised and to the right once exposed,
--     centred when aiming. Aiming while disguised is "weapon drawn", which Security and cameras find suspicious.
--
--   WeaponController.getStatus() -> Status    for the HUD

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Types = require(Shared:WaitForChild("Types"))
local WeaponDefs = require(Shared:WaitForChild("Defs"):WaitForChild("WeaponDefs"))
local Combat = script.Parent.Parent:WaitForChild("Combat")
local ShotFx = require(Combat:WaitForChild("ShotFx"))
local SoundPlayer = require(Combat:WaitForChild("SoundPlayer"))
local ViewModel = require(Combat:WaitForChild("ViewModel"))
local RemoteController = require(script.Parent.RemoteController)

export type Status = {
	name: string,
	mag: number,
	reserve: number,
	reloading: boolean,
	spreadDegrees: number, -- the cone a shot can land in now
	weaponUp: boolean, -- aiming, exposed or just fired: the weapon is in hand
	aiming: boolean,
	viewportFov: number, -- the field of view the spread is drawn at
}

local WeaponController = {}

local localPlayer = Players.LocalPlayer
local combat = GameConfig.Combat
local controls = GameConfig.Controls
local rng = Random.new()

local ARM_PARTS = { "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand" }
local RAISE_AFTER_FIRE_SECONDS = 1 -- the gun stays up this long after a shot, until the server confirms cover is broken
local COLOR_REFRESH_SECONDS = 1
local EMPTY_CLICK_GAP = 0.3
local MAX_SHOTS_PER_FRAME = 3
local FOV_TOLERANCE = 0.01 -- degrees: the camera stores its field of view at lower precision than a number
local AIM_BLEND_RATE = 14
local FIRE_NOISE_PITCH = 0.04 -- shots vary a little in pitch so a burst is not a machine

local def: Types.WeaponDef = WeaponDefs.get(combat.DefaultWeapon) :: Types.WeaponDef
local viewModel: ViewModel.ViewModel? = nil

local mag = def.MagSize
local reserve = def.ReserveAmmo
local reloadEndsAt = 0
local reloadStartedAt = 0
local nextFireAt = 0
local firing = false
local aiming = false
local aimBlend = 0
local spreadExtra = 0
local recoilPitch, recoilYaw = 0, 0 -- degrees the view is kicked up and sideways, settling back
local appliedPitch, appliedYaw = 0, 0 -- how much of that is already in the camera (see step)
local lastFireAt = -math.huge
local lastEmptyAt = -math.huge
local exposed = false
local baseFov = 70
local appliedFov = 0
local lastColorRefresh = -math.huge

local function character(): (Model?, Humanoid?, BasePart?)
	local model = localPlayer.Character
	local humanoid = model and model:FindFirstChildOfClass("Humanoid")
	local root = model and model:FindFirstChild("HumanoidRootPart")
	if model and humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return model, humanoid, root
	end
	return nil, nil, nil
end

local function isReloading(now: number): boolean
	return reloadEndsAt > now
end

local function weaponUp(now: number): boolean
	return aiming or exposed or now - lastFireAt < RAISE_AFTER_FIRE_SECONDS
end

local function currentSpread(root: BasePart?): number
	local spread = def.Spread
	local degrees = spread.Hip + (spread.Aim - spread.Hip) * aimBlend
	if root then
		local velocity = root.AssemblyLinearVelocity
		if Vector3.new(velocity.X, 0, velocity.Z).Magnitude > combat.MovingSpeedStuds then
			degrees *= spread.MoveMult
		end
	end
	return degrees + spreadExtra
end

-- A direction inside a cone of `degrees` round where the camera looks, evenly across the cone.
local function spreadDirection(cframe: CFrame, degrees: number): Vector3
	if degrees <= 0 then
		return cframe.LookVector
	end
	local radius = math.tan(math.rad(degrees)) * math.sqrt(rng:NextNumber())
	local angle = rng:NextNumber(0, 2 * math.pi)
	return (cframe.LookVector + cframe.RightVector * (radius * math.cos(angle)) + cframe.UpVector * (radius * math.sin(
		angle
	))).Unit
end

local function startReload(now: number)
	if isReloading(now) or mag >= def.MagSize or reserve <= 0 then
		return
	end
	reloadStartedAt = now
	reloadEndsAt = now + def.ReloadSeconds
	SoundPlayer.play(def.Sounds.Reload, combat.Feedback.ShotVolume)
	RemoteController.fire("ReloadRequest")
end

local function fireOnce(camera: Camera, root: BasePart, now: number)
	if isReloading(now) then
		return
	end
	if mag <= 0 then
		if now - lastEmptyAt >= EMPTY_CLICK_GAP then
			lastEmptyAt = now
			SoundPlayer.play(def.Sounds.Empty, combat.Feedback.ShotVolume)
		end
		startReload(now)
		return
	end
	nextFireAt = math.max(nextFireAt, now - combat.FireRateToleranceSeconds) + 60 / def.RPM
	mag -= 1
	lastFireAt = now

	local direction = spreadDirection(camera.CFrame, currentSpread(root))
	RemoteController.fire("FireRequest", camera.CFrame.Position, direction, workspace:GetServerTimeNow(), def.Id)

	-- What the shot feels like, at once.
	SoundPlayer.play(
		def.Sounds.Fire,
		combat.Feedback.ShotVolume,
		1 + rng:NextNumber(-FIRE_NOISE_PITCH, FIRE_NOISE_PITCH)
	)
	local recoil = def.Recoil
	recoilPitch += recoil.PitchPerShot
	recoilYaw += rng:NextNumber(-recoil.YawPerShot, recoil.YawPerShot)
	spreadExtra = math.min(spreadExtra + def.Spread.PerShot, def.Spread.MaxExtra)
	if viewModel then
		viewModel:kick()
	end
	local point, normal = ShotFx.mapHit(camera.CFrame.Position, direction)
	if point and normal then
		ShotFx.impact(point, normal)
	end
	if mag <= 0 then
		startReload(now)
	end
end

-- Hides the local character's own arms; the view model has arms of its own.
local function hideOwnArms(model: Model)
	for _, name in ARM_PARTS do
		local part = model:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			part.LocalTransparencyModifier = 1
		end
	end
end

local function refreshColors(model: Model, now: number)
	if now - lastColorRefresh < COLOR_REFRESH_SECONDS or not viewModel then
		return
	end
	lastColorRefresh = now
	local sleeve = model:FindFirstChild("LeftUpperArm")
	local hand = model:FindFirstChild("LeftHand")
	if sleeve and sleeve:IsA("BasePart") and hand and hand:IsA("BasePart") then
		viewModel:setColors(sleeve.Color, hand.Color)
	end
end

local function step(dt: number)
	local camera = workspace.CurrentCamera
	local model, humanoid, root = character()
	if not camera then
		return
	end
	local now = os.clock()

	-- The field of view, with aiming zooming it. Someone else changing it is respected.
	if aimBlend == 0 or (appliedFov ~= 0 and math.abs(camera.FieldOfView - appliedFov) > FOV_TOLERANCE) then
		baseFov = camera.FieldOfView
	end

	if not (model and humanoid and root) then
		if viewModel then
			viewModel:setVisible(false)
		end
		return
	end

	aimBlend += ((if aiming then 1 else 0) - aimBlend) * math.min(AIM_BLEND_RATE * dt, 1)
	if aimBlend < 0.001 then
		aimBlend = 0
	end

	-- A reload that has run its time puts the rounds in (the server confirms with AmmoUpdate).
	if reloadEndsAt ~= 0 and now >= reloadEndsAt then
		reloadEndsAt = 0
		local take = math.min(def.MagSize - mag, reserve)
		mag += take
		reserve -= take
	end

	-- Recoil climbs the view and settles; spread closes up while the trigger is off.
	local recover = math.min(def.Recoil.RecoverRate * dt, 1)
	recoilPitch -= recoilPitch * recover
	recoilYaw -= recoilYaw * recover
	spreadExtra = math.max(0, spreadExtra - def.Spread.RecoverPerSecond * dt)
	-- The default camera builds each frame on the CFrame it finds, so only the change in recoil is added here: the view
	-- climbs as the kick grows and comes back down as it settles, and never piles up.
	camera.CFrame *= CFrame.Angles(math.rad(recoilPitch - appliedPitch), math.rad(recoilYaw - appliedYaw), 0)
	appliedPitch, appliedYaw = recoilPitch, recoilYaw

	if firing and def.Automatic then
		local shots = 0
		while firing and now >= nextFireAt and shots < MAX_SHOTS_PER_FRAME do
			fireOnce(camera, root, now)
			shots += 1
			if mag <= 0 or isReloading(now) then
				break
			end
		end
	end

	local zoom = 1 + (def.AimZoom - 1) * aimBlend
	appliedFov = baseFov * zoom
	camera.FieldOfView = appliedFov

	hideOwnArms(model)
	refreshColors(model, now)
	if not viewModel then
		viewModel = ViewModel.new(def)
	end
	local view = viewModel :: ViewModel.ViewModel
	view:setVisible(true)
	local pose = if aiming
		then "Aim"
		elseif exposed or now - lastFireAt < RAISE_AFTER_FIRE_SECONDS then "Ready"
		else "Tucked"
	local velocity = root.AssemblyLinearVelocity
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	view:update(camera, dt, {
		pose = pose,
		speedFraction = math.clamp(speed / GameConfig.Speeds.Sprint, 0, 1),
		reloadProgress = if isReloading(now) then (now - reloadStartedAt) / def.ReloadSeconds else nil,
	})
end

function WeaponController.getStatus(): Status
	local now = os.clock()
	local _, _, root = character()
	local camera = workspace.CurrentCamera
	return {
		name = def.Name,
		mag = mag,
		reserve = reserve,
		reloading = isReloading(now),
		spreadDegrees = currentSpread(root),
		weaponUp = weaponUp(now),
		aiming = aiming,
		viewportFov = if camera then camera.FieldOfView else baseFov,
	}
end

local function onFire(_: string, state: Enum.UserInputState): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin then
		firing = true
		local camera = workspace.CurrentCamera
		local _, _, root = character()
		local now = os.clock()
		-- A click fires at once; a held trigger carries on in step() for an automatic weapon.
		if camera and root and now >= nextFireAt then
			fireOnce(camera, root, now)
		end
	else
		firing = false
	end
	return Enum.ContextActionResult.Sink
end

local function onAim(_: string, state: Enum.UserInputState): Enum.ContextActionResult
	local on = state == Enum.UserInputState.Begin
	if aiming ~= on then
		aiming = on
		RemoteController.fire("RequestDraw", on)
	end
	return Enum.ContextActionResult.Sink
end

local function onReload(_: string, state: Enum.UserInputState): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin then
		startReload(os.clock())
	end
	return Enum.ContextActionResult.Sink
end

local function onMelee(_: string, state: Enum.UserInputState): Enum.ContextActionResult
	local camera = workspace.CurrentCamera
	if state == Enum.UserInputState.Begin and camera then
		RemoteController.fire("RequestMelee", "Press", camera.CFrame.LookVector)
		SoundPlayer.play(combat.Feedback.MeleeSound, combat.Feedback.ShotVolume)
	elseif state == Enum.UserInputState.End then
		RemoteController.fire("RequestMelee", "Release")
	end
	return Enum.ContextActionResult.Sink
end

local function resetForSpawn()
	mag, reserve = def.MagSize, def.ReserveAmmo
	reloadEndsAt = 0
	firing, aiming = false, false
	spreadExtra, recoilPitch, recoilYaw = 0, 0, 0
	appliedPitch, appliedYaw = 0, 0
	nextFireAt = 0
end

function WeaponController.Init() end

function WeaponController.Start()
	local sounds = {
		def.Sounds.Fire,
		def.Sounds.Reload,
		def.Sounds.Empty,
		combat.Feedback.MeleeSound,
		combat.Feedback.ImpactSound,
	}
	SoundPlayer.preload(sounds)

	RemoteController.connect("AmmoUpdate", function(info: Types.AmmoInfo)
		mag, reserve = info.Mag, info.Reserve
		if info.ReloadSeconds <= 0 then
			reloadEndsAt = 0
		end
	end)
	RemoteController.connect("CoverStateChanged", function(info: Types.CoverInfo)
		exposed = info.State == "Exposed"
	end)

	ContextActionService:BindActionAtPriority("WeaponFire", onFire, false, 3000, controls.Fire, controls.FirePad)
	ContextActionService:BindActionAtPriority("WeaponAim", onAim, false, 3000, controls.Aim, controls.AimPad)
	ContextActionService:BindActionAtPriority(
		"WeaponReload",
		onReload,
		false,
		3000,
		controls.Reload,
		controls.ReloadPad
	)
	ContextActionService:BindActionAtPriority("WeaponMelee", onMelee, false, 3000, controls.Melee, controls.MeleePad)

	localPlayer.CharacterAdded:Connect(resetForSpawn)
	-- Losing the window means the button-up never arrives, so the trigger and the aim let go here.
	UserInputService.WindowFocusReleased:Connect(function()
		firing = false
		if aiming then
			aiming = false
			RemoteController.fire("RequestDraw", false)
		end
	end)
	-- After the default camera has run this frame, so the recoil sits on top of where the view points.
	RunService:BindToRenderStep("WeaponStep", Enum.RenderPriority.Camera.Value + 2, step)
end

return WeaponController
