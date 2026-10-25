--!strict
-- The first-person gun (STEP8 answers). Client only: nobody else ever sees these parts.
--
-- The model hangs off the camera. Each frame it settles toward the pose asked for (Tucked: across the chest while
-- disguised; Ready: up in the right third of the screen once exposed; Aim: centred on the line of sight), with a little
-- lag behind the view turning, a walking bob, a jolt for each shot and a dip while reloading.
--
-- Ticket 8.15: FirstPersonBodyController poses cosmetic camera-relative arm meshes to the grips; the real body is hidden.
--
--   ViewModel.new(def) -> ViewModel
--   vm:update(camera, dt, input)   place it for this frame
--   vm:kick()                      a shot's jolt
--   vm:getHandTargets()            world frames for cosmetic first-person hands
--   vm:setVisible(visible)
--   vm:destroy()

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Types = require(Shared:WaitForChild("Types"))
local WeaponPlacement = require(script.Parent.WeaponPlacement)

type WeaponDef = Types.WeaponDef

export type Input = {
	pose: string, -- "Tucked", "Ready" or "Aim"
	speedFraction: number, -- 0 standing, 1 at full speed
	reloadProgress: number?, -- 0 to 1 while reloading
}

local config = GameConfig.Combat.ViewModel
local presentation = GameConfig.Combat.Presentation
local SIGNS = { -1, 1 }
type DrawPart = { part: BasePart, offset: CFrame, size: Vector3, left: boolean }

local ViewModel = {}
ViewModel.__index = ViewModel

export type ViewModel = typeof(setmetatable(
	{} :: {
		def: WeaponDef,
		model: Model,
		rightGrip: CFrame,
		leftGrip: CFrame,
		drawFrame: CFrame,
		current: CFrame,
		sway: Vector3,
		kickBack: number,
		bobPhase: number,
		lastCamera: CFrame?,
		visible: boolean,
		muzzle: Attachment,
		muzzleOffset: Vector3,
		leftMuzzle: Attachment?,
		leftMuzzleOffset: Vector3,
		singleAkimbo: boolean,
		aimShiftX: number,
		parts: { DrawPart },
		corners: { Vector3 },
		tuck: number,
		drawScale: number,
	},
	ViewModel
))

local function poseCFrame(name: string): CFrame
	local pose = config.Poses[name]
	assert(pose, `No view model pose {name}`)
	local r = pose.Rotation
	return CFrame.new(pose.Position) * CFrame.Angles(math.rad(r.X), math.rad(r.Y), math.rad(r.Z))
end

local function addPart(
	parent: Model,
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part:SetAttribute("Offset", offset) -- where it sits in the gun's own frame
	part.Parent = parent
	return part
end

-- The suppressed SMG, built from parts: +x right, +y up, -z the way it points.
local function buildSuppressedSmg(model: Model): (CFrame, CFrame)
	local body, accent = config.GunColor, config.AccentColor
	addPart(model, "Receiver", Vector3.new(0.3, 0.42, 1.5), CFrame.new(0, 0, 0), body)
	addPart(model, "TopRail", Vector3.new(0.18, 0.1, 1.2), CFrame.new(0, 0.26, -0.05), accent)
	addPart(model, "Handguard", Vector3.new(0.26, 0.3, 0.7), CFrame.new(0, -0.02, -0.95), accent)
	local suppressor = addPart(
		model,
		"Suppressor",
		Vector3.new(1.3, 0.34, 0.34),
		CFrame.new(0, 0.04, -1.95) * CFrame.Angles(0, math.rad(90), 0),
		body
	)
	suppressor.Shape = Enum.PartType.Cylinder
	-- Ticket 8.11: the cylinder's local +X end is the barrel tip. This stays entirely in the local view model.
	local muzzle = Instance.new("Attachment")
	muzzle.Name = "Muzzle"
	muzzle.Position = Vector3.new(suppressor.Size.X / 2, 0, 0)
	muzzle.Parent = suppressor
	addPart(
		model,
		"Magazine",
		Vector3.new(0.22, 0.8, 0.32),
		CFrame.new(0, -0.58, 0.1) * CFrame.Angles(math.rad(8), 0, 0),
		accent
	)
	addPart(
		model,
		"Grip",
		Vector3.new(0.26, 0.62, 0.28),
		CFrame.new(0, -0.5, 0.58) * CFrame.Angles(math.rad(-15), 0, 0),
		body
	)
	addPart(model, "Stock", Vector3.new(0.2, 0.34, 0.8), CFrame.new(0, 0.02, 1.1), accent)
	addPart(model, "RearSight", Vector3.new(0.1, 0.16, 0.2), CFrame.new(0, 0.39, 0.45), body)
	addPart(model, "FrontSight", Vector3.new(0.08, 0.16, 0.12), CFrame.new(0, 0.37, -0.75), body)

	return CFrame.new(0.02, -0.55, 0.6), CFrame.new(-0.03, -0.24, -0.95)
end

local function buildFoldingCarbine(model: Model): (CFrame, CFrame)
	local body, accent = config.GunColor, config.AccentColor
	addPart(model, "Receiver", Vector3.new(0.28, 0.4, 1.35), CFrame.identity, body)
	addPart(model, "Handguard", Vector3.new(0.24, 0.28, 1.1), CFrame.new(0, 0, -1.0), accent)
	addPart(model, "Rail", Vector3.new(0.16, 0.08, 1.55), CFrame.new(0, 0.24, -0.25), accent)
	addPart(
		model,
		"Grip",
		Vector3.new(0.24, 0.6, 0.28),
		CFrame.new(0, -0.46, 0.4) * CFrame.Angles(math.rad(-12), 0, 0),
		body
	)
	addPart(model, "Magazine", Vector3.new(0.2, 0.65, 0.3), CFrame.new(0, -0.48, -0.15), accent)
	addPart(model, "FoldHinge", Vector3.new(0.36, 0.26, 0.15), CFrame.new(0, 0, 0.78), accent)
	addPart(model, "Stock", Vector3.new(0.16, 0.24, 0.85), CFrame.new(0, 0, 1.2), body)
	addPart(model, "Butt", Vector3.new(0.24, 0.55, 0.12), CFrame.new(0, -0.08, 1.65), accent)
	addPart(model, "FrontSight", Vector3.new(0.07, 0.16, 0.1), CFrame.new(0, 0.25, -1.45), body)
	addPart(model, "RearSight", Vector3.new(0.12, 0.16, 0.12), CFrame.new(0, 0.3, 0.4), body)
	local barrel = addPart(
		model,
		"Barrel",
		Vector3.new(0.7, 0.14, 0.14),
		CFrame.new(0, 0.02, -1.85) * CFrame.Angles(0, math.pi / 2, 0),
		body
	)
	barrel.Shape = Enum.PartType.Cylinder
	local muzzle = Instance.new("Attachment")
	muzzle.Name = "Muzzle"
	muzzle.Position = Vector3.new(barrel.Size.X / 2, 0, 0)
	muzzle.Parent = barrel
	return CFrame.new(0.02, -0.46, 0.4), CFrame.new(-0.03, -0.18, -1.0)
end

local function buildPistol(model: Model, suppressed: boolean): (CFrame, CFrame)
	local body, accent = config.GunColor, config.AccentColor
	addPart(model, "Receiver", Vector3.new(0.23, 0.25, 0.95), CFrame.identity, body)
	addPart(model, "Slide", Vector3.new(0.25, 0.18, 1.0), CFrame.new(0, 0.18, -0.03), accent)
	addPart(
		model,
		"Grip",
		Vector3.new(0.23, 0.58, 0.3),
		CFrame.new(0, -0.36, 0.26) * CFrame.Angles(math.rad(-13), 0, 0),
		body
	)
	addPart(model, "TriggerGuard", Vector3.new(0.16, 0.12, 0.26), CFrame.new(0, -0.21, -0.08), accent)
	addPart(model, "FrontSight", Vector3.new(0.05, 0.06, 0.07), CFrame.new(0, 0.3, -0.43), body)
	addPart(model, "RearSight", Vector3.new(0.12, 0.06, 0.07), CFrame.new(0, 0.3, 0.35), body)
	local length = if suppressed then 0.75 else 0.45
	local radius = if suppressed then 0.2 else 0.17
	local barrel = addPart(
		model,
		if suppressed then "Suppressor" else "ShroudedBarrel",
		Vector3.new(length, radius, radius),
		CFrame.new(0, 0.15, -0.5 - length / 2) * CFrame.Angles(0, math.pi / 2, 0),
		body
	)
	barrel.Shape = Enum.PartType.Cylinder
	local muzzle = Instance.new("Attachment")
	muzzle.Name = "Muzzle"
	muzzle.Position = Vector3.new(length / 2, 0, 0)
	muzzle.Parent = barrel
	return CFrame.new(0.01, -0.32, 0.25), CFrame.new(-0.15, -0.3, 0.18)
end

local function buildHeavySmg(model: Model): (CFrame, CFrame)
	local right, left = buildSuppressedSmg(model)
	local barrel = model:FindFirstChild("Suppressor") :: Part
	barrel.Name = "HeavyBarrel"
	barrel.Size = Vector3.new(0.7, 0.24, 0.24)
	barrel:SetAttribute("Offset", CFrame.new(0, 0.04, -1.65) * CFrame.Angles(0, math.pi / 2, 0))(
		barrel:FindFirstChild("Muzzle") :: Attachment
	).Position =
		Vector3.new(barrel.Size.X / 2, 0, 0)
	local magazine = model:FindFirstChild("Magazine") :: Part
	magazine.Size = Vector3.new(0.3, 0.9, 0.4)
	return right, left
end

local function buildMarksmanPistol(model: Model): (CFrame, CFrame)
	local right, left = buildPistol(model, false)
	local barrel = model:FindFirstChild("ShroudedBarrel") :: Part
	barrel.Size = Vector3.new(0.9, 0.2, 0.2)
	barrel:SetAttribute("Offset", CFrame.new(0, 0.15, -0.95) * CFrame.Angles(0, math.pi / 2, 0))(
		barrel:FindFirstChild("Muzzle") :: Attachment
	).Position =
		Vector3.new(barrel.Size.X / 2, 0, 0)
	addPart(model, "OpticBase", Vector3.new(0.22, 0.09, 0.3), CFrame.new(0, 0.33, 0.05), config.AccentColor)
	addPart(model, "Optic", Vector3.new(0.16, 0.16, 0.2), CFrame.new(0, 0.43, 0.05), config.GunColor)
	return right, left
end

local function buildMedicShotgun(model: Model): (CFrame, CFrame)
	local body, accent = config.GunColor, config.AccentColor
	addPart(model, "Receiver", Vector3.new(0.4, 0.48, 1.25), CFrame.identity, body)
	addPart(model, "ForeEnd", Vector3.new(0.34, 0.32, 0.9), CFrame.new(0, -0.08, -1.0), accent)
	addPart(model, "Stock", Vector3.new(0.25, 0.35, 0.95), CFrame.new(0, -0.08, 1.05), body)
	addPart(model, "Butt", Vector3.new(0.33, 0.58, 0.15), CFrame.new(0, -0.12, 1.55), accent)
	addPart(
		model,
		"Grip",
		Vector3.new(0.28, 0.62, 0.3),
		CFrame.new(0, -0.4, 0.45) * CFrame.Angles(math.rad(-18), 0, 0),
		body
	)
	local barrel = addPart(
		model,
		"Barrel",
		Vector3.new(1.3, 0.24, 0.24),
		CFrame.new(0, 0.1, -1.5) * CFrame.Angles(0, math.pi / 2, 0),
		body
	)
	barrel.Shape = Enum.PartType.Cylinder
	local tube = addPart(
		model,
		"MagazineTube",
		Vector3.new(1.1, 0.19, 0.19),
		CFrame.new(0, -0.15, -1.25) * CFrame.Angles(0, math.pi / 2, 0),
		accent
	)
	tube.Shape = Enum.PartType.Cylinder
	local muzzle = Instance.new("Attachment")
	muzzle.Name = "Muzzle"
	muzzle.Position = Vector3.new(barrel.Size.X / 2, 0, 0)
	muzzle.Parent = barrel
	return CFrame.new(0.02, -0.4, 0.45), CFrame.new(-0.03, -0.22, -1.0)
end

local function buildDualPistols(model: Model): (CFrame, CFrame)
	local right = buildPistol(model, false)
	local leftModel = Instance.new("Model")
	local left = buildPistol(leftModel, false)
	local separation = 0.35 -- model geometry: spacing between the two receivers
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") then
			part:SetAttribute("Offset", CFrame.new(separation, 0, 0) * (part:GetAttribute("Offset") :: CFrame))
		end
	end
	for _, part in leftModel:GetChildren() do
		if part:IsA("BasePart") then
			part.Name = "Left" .. part.Name
			part:SetAttribute("Offset", CFrame.new(-separation, 0, 0) * (part:GetAttribute("Offset") :: CFrame))
			part.Parent = model
		end
	end
	leftModel:Destroy()
	local leftMuzzle = (model:FindFirstChild("LeftShroudedBarrel") :: Part):FindFirstChild("Muzzle") :: Attachment
	leftMuzzle.Name = "LeftMuzzle"
	return CFrame.new(separation, 0, 0) * right, CFrame.new(-separation, 0, 0) * left
end

local builders: { [string]: (Model) -> (CFrame, CFrame) } = {
	GuiseSMG = buildSuppressedSmg,
	ReticleCarbine = buildFoldingCarbine,
	ParapetHeavySMG = buildHeavySmg,
	ReticlePistol = buildMarksmanPistol,
	SutureShotgun = buildMedicShotgun,
	SutureDualPistols = buildDualPistols,
	GuisePistol = function(model)
		return buildPistol(model, true)
	end,
	FeintPistol = function(model)
		return buildPistol(model, false)
	end,
}

function ViewModel.new(def: WeaponDef): ViewModel
	local build = builders[def.Id]
	assert(build, `No view model for weapon {def.Id}`)
	local model = Instance.new("Model")
	model.Name = "ViewModel"
	local rightGrip, leftGrip = build(model)
	local parts: { DrawPart } = {}
	local low = Vector3.new(math.huge, math.huge, math.huge)
	local high = -low
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") then
			local offset = child:GetAttribute("Offset") :: CFrame
			table.insert(
				parts,
				{ part = child, offset = offset, size = child.Size, left = string.sub(child.Name, 1, 4) == "Left" }
			)
			-- Frame the gun itself; sleeves may extend behind the camera like real first-person arms.
			if not string.find(child.Name, "Sleeve") then
				for _, x in SIGNS do
					for _, y in SIGNS do
						for _, z in SIGNS do
							local point = offset:PointToWorldSpace(child.Size * Vector3.new(x, y, z) / 2)
							low = low:Min(point)
							high = high:Max(point)
						end
					end
				end
			end
		end
	end
	local corners: { Vector3 } = {}
	for _, x in SIGNS do
		for _, y in SIGNS do
			for _, z in SIGNS do
				table.insert(
					corners,
					Vector3.new(
						if x < 0 then low.X else high.X,
						if y < 0 then low.Y else high.Y,
						if z < 0 then low.Z else high.Z
					)
				)
			end
		end
	end
	local muzzle = model:FindFirstChild("Muzzle", true) :: Attachment
	local leftMuzzle = model:FindFirstChild("LeftMuzzle", true) :: Attachment?
	local receiver = model:FindFirstChild("Receiver") :: Part
	model.PrimaryPart = model:FindFirstChild("Receiver") :: Part
	model.Parent = workspace.CurrentCamera
	return setmetatable({
		def = def,
		model = model,
		rightGrip = rightGrip,
		leftGrip = leftGrip,
		drawFrame = CFrame.identity,
		current = CFrame.identity,
		sway = Vector3.zero,
		kickBack = 0,
		bobPhase = 0,
		lastCamera = nil,
		visible = true,
		muzzle = muzzle,
		muzzleOffset = muzzle.Position,
		leftMuzzle = leftMuzzle,
		leftMuzzleOffset = if leftMuzzle then leftMuzzle.Position else Vector3.zero,
		singleAkimbo = false,
		aimShiftX = (receiver:GetAttribute("Offset") :: CFrame).Position.X,
		parts = parts,
		corners = corners,
		tuck = 0,
		drawScale = 1,
	}, ViewModel)
end

function ViewModel.getMuzzlePosition(self: ViewModel, useLeft: boolean?): Vector3
	if useLeft and self.leftMuzzle then
		return self.leftMuzzle.WorldPosition
	end
	return self.muzzle.WorldPosition
end

function ViewModel.isFireBlocked(self: ViewModel, camera: Camera): boolean
	return WeaponPlacement.attackBlocked(WeaponPlacement.wallDistance(camera), self.tuck)
end

-- Third-person display reuses the same geometry, but is parented in a separate client-only folder.
function ViewModel.placeAtRightHand(self: ViewModel, hand: CFrame, leftHand: CFrame?)
	local origin = hand * self.rightGrip:Inverse()
	for _, entry in self.parts do
		entry.part.Size = entry.size
		local frame = if entry.left and leftHand then leftHand * self.leftGrip:Inverse() else origin
		entry.part.CFrame = frame * entry.offset
	end
end

function ViewModel.getHandTargets(self: ViewModel): (CFrame?, CFrame?)
	if not self.visible or self.drawFrame == CFrame.identity then
		return nil, nil
	end
	local right = CFrame.new(self.rightGrip.Position * self.drawScale) * self.rightGrip.Rotation
	local left = CFrame.new(self.leftGrip.Position * self.drawScale) * self.leftGrip.Rotation
	return self.drawFrame * right, if self.singleAkimbo then nil else self.drawFrame * left
end

function ViewModel.setVisible(self: ViewModel, visible: boolean)
	if self.visible == visible then
		return
	end
	self.visible = visible
	for _, entry in self.parts do
		entry.part.Transparency = if visible then 0 else 1
	end
end

function ViewModel.kick(self: ViewModel)
	self.kickBack = math.min(self.kickBack + self.def.Recoil.ViewKick, self.def.Recoil.ViewKick * 4)
end

function ViewModel.update(self: ViewModel, camera: Camera, dt: number, input: Input)
	local cameraCFrame = camera.CFrame

	-- Lag behind the view turning: how far the camera turned since last frame, as a rate.
	local last = self.lastCamera
	self.lastCamera = cameraCFrame
	local swayTarget = Vector3.zero
	if last and dt > 0 then
		local turn = last:ToObjectSpace(cameraCFrame)
		local pitch, yaw = turn:ToEulerAnglesYXZ()
		local limit = config.SwayLimitStuds
		swayTarget = Vector3.new(
			math.clamp(yaw / dt * config.SwayStrength, -limit, limit),
			math.clamp(-pitch / dt * config.SwayStrength, -limit, limit),
			0
		)
	end
	self.sway = self.sway:Lerp(swayTarget, 1 - math.exp(-config.SwaySettle * dt))

	-- A walking bob that all but vanishes while aiming.
	local steady = if input.pose == "Aim" then config.AimBobFraction else 1
	self.bobPhase += dt * config.BobSpeed * input.speedFraction
	local bob = Vector3.new(
		math.cos(self.bobPhase) * config.BobStuds,
		math.abs(math.sin(self.bobPhase)) * config.BobStuds,
		0
	) * (input.speedFraction * steady)

	self.kickBack -= self.kickBack * math.min(config.KickRecoverSpeed * dt, 1)

	local offset = CFrame.new(self.sway + bob + Vector3.new(0, 0, self.kickBack))
	local progress = input.reloadProgress
	if progress then
		local dip = math.sin(math.pi * progress)
		offset = offset
			* CFrame.new(0, -dip * config.ReloadDipStuds, 0)
			* CFrame.Angles(0, 0, math.rad(config.ReloadTilt) * dip)
	end

	local distance = WeaponPlacement.wallDistance(camera)
	local blend = 1 - math.exp(-presentation.TuckBlendSpeed * dt)
	self.tuck += (WeaponPlacement.tuckFraction(distance) - self.tuck) * blend
	self.singleAkimbo = self.leftMuzzle ~= nil and input.pose == "Aim"
	local center = if self.singleAkimbo then CFrame.new(-self.aimShiftX, 0, 0) else CFrame.identity
	local relativeTarget = WeaponPlacement.fit(
		center * poseCFrame(input.pose) * offset,
		self.corners,
		camera.FieldOfView,
		camera.ViewportSize
	)
	local target = cameraCFrame * relativeTarget
	local settle = 1 - math.exp(-config.PoseSpeed * dt)
	if self.current == CFrame.identity then
		self.current = target
	else
		-- Settle in the camera's own frame, so turning the view never drags the gun through the world.
		local relative = cameraCFrame:ToObjectSpace(self.current):Lerp(cameraCFrame:ToObjectSpace(target), settle)
		self.current = cameraCFrame * relative
	end

	-- Fit again after interpolation so a sudden FOV/aspect change cannot leave a corner outside the view.
	local baseRelative = WeaponPlacement.fit(
		cameraCFrame:ToObjectSpace(self.current),
		self.corners,
		camera.FieldOfView,
		camera.ViewportSize
	)
	self.current = cameraCFrame * baseRelative
	-- Apply wall tuck after ordinary pose settling. Filtering it twice would leave the gun visibly tucked after
	-- the gate's fraction cleared. The same fraction now directly drives across-body rendering and blocking.
	local relative = WeaponPlacement.fit(
		baseRelative:Lerp(poseCFrame("Tucked") * offset, self.tuck),
		self.corners,
		camera.FieldOfView,
		camera.ViewportSize
	)
	-- Compress camera-space depth and geometry together: projection stays the same while the gun avoids the wall.
	local scale = math.min(
		1,
		math.max(distance * presentation.WallDepthFraction, presentation.NearDepthStuds)
			/ WeaponPlacement.depth(relative, self.corners)
	)
	self.drawScale = math.min(scale, self.drawScale + (1 - self.drawScale) * blend)
	local drawFrame = cameraCFrame * (CFrame.new(relative.Position * self.drawScale) * relative.Rotation)
	self.drawFrame = drawFrame
	for _, entry in self.parts do
		entry.part.Size = entry.size * self.drawScale
		entry.part.CFrame = drawFrame * (CFrame.new(entry.offset.Position * self.drawScale) * entry.offset.Rotation)
		entry.part.Transparency = if entry.left and self.singleAkimbo then 1 else 0
	end
	self.muzzle.Position = self.muzzleOffset * self.drawScale
	if self.leftMuzzle then
		self.leftMuzzle.Position = self.leftMuzzleOffset * self.drawScale
	end
end

function ViewModel.destroy(self: ViewModel)
	self.model:Destroy()
end

return ViewModel
