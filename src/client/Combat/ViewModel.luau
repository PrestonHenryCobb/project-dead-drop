--!strict
-- The first-person gun and arms (STEP8 answers). Client only: nobody else ever sees these parts.
--
-- The model hangs off the camera. Each frame it settles toward the pose asked for (Tucked: across the chest while
-- disguised; Ready: up in the right third of the screen once exposed; Aim: centred on the line of sight), with a little
-- lag behind the view turning, a walking bob, a jolt for each shot and a dip while reloading.
--
-- The arms are plain sleeves and hands in the colours of the local character; a real arm rig comes with the art pass.
--
--   ViewModel.new(def) -> ViewModel
--   vm:update(camera, dt, input)   place it for this frame
--   vm:kick()                      a shot's jolt
--   vm:setColors(sleeve, skin)
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
type DrawPart = { part: BasePart, offset: CFrame, size: Vector3 }

local ViewModel = {}
ViewModel.__index = ViewModel

export type ViewModel = typeof(setmetatable(
	{} :: {
		def: WeaponDef,
		model: Model,
		sleeves: { Part },
		hands: { Part },
		current: CFrame,
		sway: Vector3,
		kickBack: number,
		bobPhase: number,
		lastCamera: CFrame?,
		visible: boolean,
		muzzle: Attachment,
		muzzleOffset: Vector3,
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
local function buildSuppressedSmg(model: Model): ({ Part }, { Part })
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

	local hands = {
		addPart(model, "RightHand", Vector3.new(0.36, 0.36, 0.38), CFrame.new(0.02, -0.55, 0.6), Color3.new(1, 1, 1)),
		addPart(model, "LeftHand", Vector3.new(0.36, 0.36, 0.38), CFrame.new(-0.03, -0.24, -0.95), Color3.new(1, 1, 1)),
	}
	local sleeves = {
		addPart(
			model,
			"RightSleeve",
			Vector3.new(0.4, 0.4, 2),
			CFrame.new(0.2, -0.95, 1.65) * CFrame.Angles(math.rad(-22), math.rad(-10), 0),
			Color3.new(1, 1, 1)
		),
		addPart(
			model,
			"LeftSleeve",
			Vector3.new(0.4, 0.4, 2.1),
			CFrame.new(-0.55, -0.75, 0.2) * CFrame.Angles(math.rad(-30), math.rad(34), 0),
			Color3.new(1, 1, 1)
		),
	}
	return sleeves, hands
end

local builders: { [string]: (Model) -> ({ Part }, { Part }) } = {
	GuiseSMG = buildSuppressedSmg,
}

function ViewModel.new(def: WeaponDef): ViewModel
	local build = builders[def.Id]
	assert(build, `No view model for weapon {def.Id}`)
	local model = Instance.new("Model")
	model.Name = "ViewModel"
	local sleeves, hands = build(model)
	local parts: { DrawPart } = {}
	local low = Vector3.new(math.huge, math.huge, math.huge)
	local high = -low
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") then
			local offset = child:GetAttribute("Offset") :: CFrame
			table.insert(parts, { part = child, offset = offset, size = child.Size })
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
	model.PrimaryPart = model:FindFirstChild("Receiver") :: Part
	model.Parent = workspace.CurrentCamera
	return setmetatable({
		def = def,
		model = model,
		sleeves = sleeves,
		hands = hands,
		current = CFrame.identity,
		sway = Vector3.zero,
		kickBack = 0,
		bobPhase = 0,
		lastCamera = nil,
		visible = true,
		muzzle = muzzle,
		muzzleOffset = muzzle.Position,
		parts = parts,
		corners = corners,
		tuck = 0,
		drawScale = 1,
	}, ViewModel)
end

function ViewModel.getMuzzlePosition(self: ViewModel): Vector3
	return self.muzzle.WorldPosition
end

function ViewModel.isFireBlocked(_self: ViewModel, camera: Camera): boolean
	return WeaponPlacement.wallDistance(camera) <= presentation.FullTuckStuds
end

function ViewModel.setColors(self: ViewModel, sleeve: Color3, skin: Color3)
	for _, part in self.sleeves do
		part.Color = sleeve
	end
	for _, part in self.hands do
		part.Color = skin
	end
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
	local rotation = presentation.TuckRotation * self.tuck
	local tuck = CFrame.new(presentation.TuckPosition * self.tuck)
		* CFrame.Angles(math.rad(rotation.X), math.rad(rotation.Y), math.rad(rotation.Z))
	local relativeTarget = WeaponPlacement.fit(
		poseCFrame(input.pose) * offset * tuck,
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
	local relative = WeaponPlacement.fit(
		cameraCFrame:ToObjectSpace(self.current),
		self.corners,
		camera.FieldOfView,
		camera.ViewportSize
	)
	self.current = cameraCFrame * relative
	-- Compress camera-space depth and geometry together: projection stays the same while the gun avoids the wall.
	local scale = math.min(
		1,
		math.max(distance * presentation.WallDepthFraction, presentation.NearDepthStuds)
			/ WeaponPlacement.depth(relative, self.corners)
	)
	self.drawScale = math.min(scale, self.drawScale + (1 - self.drawScale) * blend)
	local drawFrame = cameraCFrame * (CFrame.new(relative.Position * self.drawScale) * relative.Rotation)
	for _, entry in self.parts do
		entry.part.Size = entry.size * self.drawScale
		entry.part.CFrame = drawFrame * (CFrame.new(entry.offset.Position * self.drawScale) * entry.offset.Rotation)
	end
	self.muzzle.Position = self.muzzleOffset * self.drawScale
end

function ViewModel.destroy(self: ViewModel)
	self.model:Destroy()
end

return ViewModel
