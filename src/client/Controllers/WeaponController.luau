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
local Janitor = require(Shared:WaitForChild("Util"):WaitForChild("Janitor"))
local WeaponDefs = require(Shared:WaitForChild("Defs"):WaitForChild("WeaponDefs"))
local Combat = script.Parent.Parent:WaitForChild("Combat")
local ShotFx = require(Combat:WaitForChild("ShotFx"))
local ShotVisuals = require(Combat:WaitForChild("ShotVisuals"))
local SoundPlayer = require(Combat:WaitForChild("SoundPlayer"))
local ViewModel = require(Combat:WaitForChild("ViewModel"))
local WeaponCadence = require(Combat:WaitForChild("WeaponCadence"))
local WeaponPlacement = require(Combat:WaitForChild("WeaponPlacement"))
local RemoteController = require(script.Parent.RemoteController)
local HeldItemController = require(script.Parent.HeldItemController)

export type Status = {
	active: boolean, -- owner is alive and not downed/eliminated
	weaponId: string,
	name: string,
	mag: number,
	reserve: number,
	reloading: boolean,
	reloadProgress: number?, -- Ticket HUD refresh: the same predicted clock used by the view model
	spreadDegrees: number, -- the cone a shot can land in now
	weaponUp: boolean, -- aiming, exposed or just fired: the weapon is in hand
	aiming: boolean,
	viewportFov: number, -- the field of view the spread is drawn at
	attackBlocked: boolean, -- same wall-tuck state used by every attack path and the obstruction graphic
}

local WeaponController = {}
local janitor = Janitor.new()
local characterJanitor = Janitor.new()

local localPlayer = Players.LocalPlayer
local combat = GameConfig.Combat
local controls = GameConfig.Controls
local rng = Random.new()

local RAISE_AFTER_FIRE_SECONDS = 1 -- the gun stays up this long after a shot, until the server confirms cover is broken
local EMPTY_CLICK_GAP = 0.3
local MAX_SHOTS_PER_FRAME = 3
local FOV_TOLERANCE = 0.01 -- degrees: the camera stores its field of view at lower precision than a number
local AIM_BLEND_RATE = 14
local FIRE_NOISE_PITCH = 0.04 -- shots vary a little in pitch so a burst is not a machine

local def: Types.WeaponDef = WeaponDefs.get(combat.DefaultWeapon) :: Types.WeaponDef
local streak = WeaponCadence.newStreak()
local burstRemaining = 0
local shotDirections: { Vector3 } = table.create(def.Pellets or 1)
local viewModel: ViewModel.ViewModel? = nil

local mag = def.MagSize
local reserve = def.ReserveAmmo
local reloadEndsAt = 0
local reloadStartedAt = 0
local predictedReloadPending = false -- waiting for the server to confirm a reload completed locally
local nextFireAt = 0
local lastMeleeAt = -math.huge
local takedownActive = false
local meleePending = false -- press through server action completion/cancel; fire prediction must wait
local firing = false
local held = true
local combatEnabled = true -- owner-only Downed/Revived/Eliminated messages, never a character attribute
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

local function character(): (Model?, Humanoid?, BasePart?)
	if not combatEnabled then
		return nil, nil, nil
	end
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

local function attackBlocked(camera: Camera?): boolean
	if not (held and combatEnabled and camera) then
		return false
	end
	if viewModel then
		return viewModel:isFireBlocked(camera)
	end
	-- Input may arrive before the first render creates the model; collision must still block that first attack.
	return WeaponPlacement.attackBlocked(WeaponPlacement.wallDistance(camera), 0)
end

local function weaponUp(now: number): boolean
	return aiming or exposed or now - lastFireAt < RAISE_AFTER_FIRE_SECONDS
end

local function cancelLocalMelee()
	if meleePending or takedownActive then
		RemoteController.fire("RequestMelee", "Cancel")
	end
	meleePending, takedownActive = false, false
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
	burstRemaining = 0
	reloadEndsAt = now + def.ReloadSeconds
	SoundPlayer.play(def.Sounds.Reload, combat.Feedback.ShotVolume)
	RemoteController.fire("ReloadRequest")
end

local function fireOnce(camera: Camera, root: BasePart, now: number)
	if not held or isReloading(now) then
		return
	end
	if meleePending or takedownActive or now < lastMeleeAt + (def.PostMeleeFireDelay or 0) then
		return -- Ticket 8.9: match the server's recovery gate before predicting any ammo, sound or recoil
	end
	if attackBlocked(camera) then
		burstRemaining = 0
		return -- a fully tucked gun cannot fire; keep ammo, recoil and requests untouched
	end
	if mag <= 0 then
		if now - lastEmptyAt >= EMPTY_CLICK_GAP then
			lastEmptyAt = now
			SoundPlayer.play(def.Sounds.Empty, combat.Feedback.ShotVolume)
		end
		startReload(now)
		return
	end
	nextFireAt = math.max(nextFireAt, now - combat.FireRateToleranceSeconds)
		+ WeaponCadence.gapAfterShot(def, streak, now, aiming)
	if def.Burst then
		if burstRemaining == 0 then
			burstRemaining = def.Burst.Count
		end
		burstRemaining -= 1
	end
	mag -= 1
	lastFireAt = now

	for index = 1, def.Pellets or 1 do
		shotDirections[index] = spreadDirection(camera.CFrame, currentSpread(root))
	end
	RemoteController.fire(
		"FireRequest",
		camera.CFrame.Position,
		if def.Pellets then shotDirections else shotDirections[1],
		workspace:GetServerTimeNow(),
		def.Id
	)

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
	for index, direction in shotDirections do
		local point, normal = ShotFx.mapHit(camera.CFrame.Position, direction)
		if viewModel then
			ShotVisuals.fire(
				def,
				viewModel:getMuzzlePosition(def.AimedRPM ~= nil and not aiming and mag % 2 == 0),
				point or (camera.CFrame.Position + direction * combat.MaxShotStuds),
				index == 1
			)
		end
		if point and normal then
			ShotFx.impact(point, normal)
		end
	end
	if mag <= 0 then
		startReload(now)
	end
end

local function step(dt: number)
	local camera = workspace.CurrentCamera
	local model, humanoid, root = character()
	if not camera then
		cancelLocalMelee()
		return
	end
	local now = os.clock()

	-- The field of view, with aiming zooming it. Someone else changing it is respected.
	if aimBlend == 0 or (appliedFov ~= 0 and math.abs(camera.FieldOfView - appliedFov) > FOV_TOLERANCE) then
		baseFov = camera.FieldOfView
	end

	if not (model and humanoid and root) then
		cancelLocalMelee()
		if viewModel then
			viewModel:setVisible(false)
		end
		camera.FieldOfView = baseFov
		appliedFov = baseFov
		aimBlend = 0
		return
	end
	if attackBlocked(camera) then
		-- Never queue a burst/held shot through an obstruction. Require fresh input after the tuck clears.
		firing = false
		burstRemaining = 0
		if aiming then
			aiming = false
			RemoteController.fire("RequestDraw", false)
		end
		cancelLocalMelee()
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
		predictedReloadPending = true
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

	if (firing and def.Automatic) or burstRemaining > 0 then
		local shots = 0
		while
			((firing and def.Automatic) or burstRemaining > 0)
			and now >= nextFireAt
			and shots < MAX_SHOTS_PER_FRAME
		do
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
	if not held then
		if viewModel then
			viewModel:setVisible(false)
		end
		return
	end

	if viewModel and viewModel.model.Parent ~= camera then
		viewModel:destroy()
		viewModel = nil
	end
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

function WeaponController.getHandTargets(): (CFrame?, CFrame?, number)
	if combatEnabled and held and viewModel then
		local right, left = viewModel:getHandTargets()
		return right, left, viewModel.drawScale
	end
	return nil, nil, 1
end

function WeaponController.getStatus(): Status
	local now = os.clock()
	local _, _, root = character()
	local camera = workspace.CurrentCamera
	return {
		active = root ~= nil,
		weaponId = def.Id,
		name = def.Name,
		mag = mag,
		reserve = reserve,
		reloading = isReloading(now),
		reloadProgress = if isReloading(now)
			then math.clamp((now - reloadStartedAt) / def.ReloadSeconds, 0, 1)
			else nil,
		spreadDegrees = currentSpread(root),
		weaponUp = root ~= nil and held and weaponUp(now),
		aiming = aiming,
		viewportFov = if camera then camera.FieldOfView else baseFov,
		attackBlocked = root ~= nil and attackBlocked(camera),
	}
end

local function onFire(_: string, state: Enum.UserInputState): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin then
		if not combatEnabled or meleePending or takedownActive then
			return Enum.ContextActionResult.Sink
		end
		if attackBlocked(workspace.CurrentCamera) then
			firing = false
			burstRemaining = 0
			return Enum.ContextActionResult.Sink
		end
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
		if state == Enum.UserInputState.Cancel then
			burstRemaining = 0
		end
	end
	return Enum.ContextActionResult.Sink
end

local function onAim(_: string, state: Enum.UserInputState): Enum.ContextActionResult
	local on = state == Enum.UserInputState.Begin
	if on and (meleePending or not character() or attackBlocked(workspace.CurrentCamera)) then
		return Enum.ContextActionResult.Sink
	end
	if aiming ~= on then
		aiming = on
		RemoteController.fire("RequestDraw", on)
	end
	return Enum.ContextActionResult.Sink
end

local function onReload(_: string, state: Enum.UserInputState): Enum.ContextActionResult
	if held and state == Enum.UserInputState.Begin and character() then
		cancelLocalMelee()
		startReload(os.clock())
	end
	return Enum.ContextActionResult.Sink
end

local function onMelee(_: string, state: Enum.UserInputState): Enum.ContextActionResult
	local camera = workspace.CurrentCamera
	if held and state == Enum.UserInputState.Begin and camera then
		if UserInputService:GetFocusedTextBox() or attackBlocked(camera) then
			return Enum.ContextActionResult.Sink
		end
		local _, humanoid = character()
		local now = os.clock()
		if
			not humanoid
			or meleePending
			or takedownActive
			or isReloading(now)
			or now - lastMeleeAt < combat.Melee.CooldownSeconds
		then
			return Enum.ContextActionResult.Sink
		end
		meleePending = true
		firing = false
		burstRemaining = 0
		if aiming then
			aiming = false
			RemoteController.fire("RequestDraw", false)
		end
		RemoteController.fire("RequestMelee", "Press", camera.CFrame.LookVector)
	elseif state == Enum.UserInputState.Cancel then
		cancelLocalMelee()
	elseif state == Enum.UserInputState.End and meleePending then
		if camera and character() and held and not attackBlocked(camera) then
			RemoteController.fire("RequestMelee", "Release", camera.CFrame.LookVector)
		else
			cancelLocalMelee()
		end
	end
	return Enum.ContextActionResult.Sink
end

local function resetWeapon()
	if viewModel then
		viewModel:destroy()
		viewModel = nil
	end
	mag, reserve = def.MagSize, def.ReserveAmmo
	reloadEndsAt = 0
	predictedReloadPending = false
	firing, aiming = false, false
	spreadExtra, recoilPitch, recoilYaw = 0, 0, 0
	appliedPitch, appliedYaw = 0, 0
	nextFireAt = 0
	streak = WeaponCadence.newStreak()
	burstRemaining = 0
	lastMeleeAt = -math.huge
	takedownActive = false
	meleePending = false
end

local function resetForSpawn()
	combatEnabled = true
	characterJanitor:Cleanup()
	resetWeapon()
end

local function onTestLoadout(info: Types.TestLoadoutInfo)
	if not RunService:IsStudio() then
		return
	end
	local nextDef = WeaponDefs.get(info.WeaponId)
	if not nextDef then
		return
	end
	if not info.Reset and nextDef.Id == def.Id then
		mag, reserve = info.Mag, info.Reserve
		return -- a sync must not interrupt a live reload or held trigger
	end
	local camera = workspace.CurrentCamera
	if camera then
		camera.CFrame *= CFrame.Angles(math.rad(-appliedPitch), math.rad(-appliedYaw), 0)
	end
	def = nextDef
	shotDirections = table.create(def.Pellets or 1)
	resetWeapon() -- deliberately retains downed state and the current character's lifecycle connections
	mag, reserve = info.Mag, info.Reserve
	aimBlend = 0
	lastFireAt = -math.huge
	SoundPlayer.preload({ def.Sounds.Fire, def.Sounds.Reload, def.Sounds.Empty })
end

local function setCombatEnabled(value: boolean)
	combatEnabled = value
	if not value then
		cancelLocalMelee()
		firing = false
		burstRemaining = 0
		takedownActive = false
		reloadEndsAt = 0
		predictedReloadPending = false
		if aiming then
			aiming = false
			RemoteController.fire("RequestDraw", false)
		end
		if viewModel then
			viewModel:setVisible(false)
		end
	end
end

local function onCharacter(model: Model)
	resetForSpawn()
	local humanoid = model:WaitForChild("Humanoid") :: Humanoid
	if localPlayer.Character ~= model then
		return
	end
	characterJanitor:Add(humanoid.Died:Connect(function()
		cancelLocalMelee()
		firing, aiming = false, false
		takedownActive = false
		reloadEndsAt = 0
		if viewModel then
			viewModel:destroy()
			viewModel = nil
		end
	end))
end

function WeaponController.Init() end

function WeaponController.Start()
	ShotVisuals.start()
	local sounds = {
		def.Sounds.Fire,
		def.Sounds.Reload,
		def.Sounds.Empty,
		combat.Feedback.MeleeSound,
		combat.Feedback.ImpactSound,
	}
	SoundPlayer.preload(sounds)
	if RunService:IsStudio() then
		janitor:Add(RemoteController.connect("TestLoadoutChanged", onTestLoadout))
	end

	janitor:Add(RemoteController.connect("AmmoUpdate", function(info: Types.AmmoInfo)
		if info.WeaponId and info.WeaponId ~= def.Id then
			return
		end
		-- Ticket 8.10: a delayed reload confirmation must not put predicted shots back in the magazine.
		-- Only consume this exception once, for a reload we actually completed; other updates correct normally.
		local confirmsPredictedReload = predictedReloadPending
			and info.ReloadSeconds <= 0
			and info.Reserve == reserve
			and info.Mag >= mag
		if not confirmsPredictedReload then
			mag, reserve = info.Mag, info.Reserve
		end
		if info.ReloadSeconds <= 0 then
			reloadEndsAt = 0
			predictedReloadPending = false
		end
	end))
	janitor:Add(RemoteController.connect("CoverStateChanged", function(info: Types.CoverInfo)
		exposed = info.State == "Exposed"
	end))
	janitor:Add(RemoteController.connect("DisguiseUpdate", function()
		cancelLocalMelee()
	end))
	janitor:Add(RemoteController.connect("MeleeState", function(info: Types.MeleeState)
		if not combatEnabled or not held then
			cancelLocalMelee()
			return
		end
		takedownActive = info.Active and info.Kind == "Takedown"
		meleePending = info.Active
		if info.Kind == "Strike" then
			lastMeleeAt = os.clock()
			SoundPlayer.play(combat.Feedback.MeleeSound, combat.Feedback.ShotVolume)
		end
	end))
	-- Step 9 keeps the Humanoid alive while downed. Health > 0 alone is therefore not permission to predict combat.
	janitor:Add(RemoteController.connect("Downed", function()
		setCombatEnabled(false)
	end))
	janitor:Add(RemoteController.connect("Eliminated", function()
		setCombatEnabled(false)
	end))
	janitor:Add(RemoteController.connect("Revived", function()
		setCombatEnabled(true)
	end))

	local item: HeldItemController.Item = {
		fire = function(state)
			onFire("WeaponFire", state)
		end,
		aim = function(state)
			onAim("WeaponAim", state)
		end,
		setHeld = function(value)
			if not value then
				cancelLocalMelee()
			end
			held = value
		end,
	}
	HeldItemController.registerWeapon(item)
	janitor:Add(UserInputService.WindowFocusReleased:Connect(cancelLocalMelee))
	janitor:Add(UserInputService.TextBoxFocused:Connect(cancelLocalMelee))
	janitor:Add(function()
		HeldItemController.unregisterWeapon(item)
	end)
	ContextActionService:BindActionAtPriority(
		"WeaponReload",
		onReload,
		false,
		combat.InputPriority,
		controls.Reload,
		controls.ReloadPad
	)
	ContextActionService:BindActionAtPriority(
		"WeaponMelee",
		onMelee,
		false,
		combat.InputPriority,
		controls.Melee,
		controls.MeleePad
	)

	janitor:Add(localPlayer.CharacterAdded:Connect(onCharacter))
	if localPlayer.Character then
		task.spawn(onCharacter, localPlayer.Character)
	end
	-- After the default camera has run this frame, so the recoil sits on top of where the view points.
	RunService:BindToRenderStep("WeaponStep", Enum.RenderPriority.Camera.Value + 2, step)
	janitor:Add(function()
		RunService:UnbindFromRenderStep("WeaponStep")
		ContextActionService:UnbindAction("WeaponReload")
		ContextActionService:UnbindAction("WeaponMelee")
		characterJanitor:Destroy()
		if viewModel then
			viewModel:destroy()
			viewModel = nil
		end
	end)
	janitor:Add(script.Destroying:Connect(function()
		janitor:Destroy()
	end))
end

return WeaponController
