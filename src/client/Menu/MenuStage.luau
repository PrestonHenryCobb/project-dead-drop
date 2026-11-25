--!strict
-- Cinematic gala balcony behind the menu. Client-only geometry far from the map, with one operative holding
-- their Hardware and the camera framings each screen uses.
--
-- The operative uses an available StarterCharacter or a local blank R15, dressed by the shared OutfitApplier.
-- Each agent stands in their own outfit (Defs/AgentLooks); only the weapon
-- changes. Weapons not built yet (no WeaponDef) are shown without a gun rather than with a stand-in.
--
--   local stage = MenuStage.new()
--   stage:show("Guise", "GuiseSMG")
--   stage:hideOperative()          -- for screens that do not show the operative
--   stage:frame("Play")            -- "Play" | "Agents" | "PreDeploy"; snaps when Reduce Motion is on
--   stage:destroy()                -- removes everything and hands the camera back

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Janitor = require(Shared:WaitForChild("Util"):WaitForChild("Janitor"))
local OutfitApplier = require(Shared:WaitForChild("Util"):WaitForChild("OutfitApplier"))
local AgentLooks = require(Shared:WaitForChild("Defs"):WaitForChild("AgentLooks"))
local UiAccessibility = require(Shared:WaitForChild("Util"):WaitForChild("UiAccessibility"))
local WeaponDefs = require(Shared:WaitForChild("Defs"):WaitForChild("WeaponDefs"))
local ViewModel = require(script.Parent.Parent:WaitForChild("Combat"):WaitForChild("ViewModel"))

local StagePose = require(script.Parent.Components.StagePose)
local GalaSet = require(script.Parent.Components.GalaSet)
local config = GameConfig.Menu.Stage
local fadeInfo = TweenInfo.new(GameConfig.Menu.ScreenFadeSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local panInfo = TweenInfo.new(GameConfig.Menu.CameraPanSeconds, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

export type Framing = "Play" | "Agents" | "Hardware" | "PreDeploy"

local MenuStage = {}
MenuStage.__index = MenuStage

export type MenuStage = typeof(setmetatable(
	{} :: {
		janitor: Janitor.Janitor,
		folder: Folder,
		rig: Model?,
		weapon: ViewModel.ViewModel?,
		shown: string?, -- "agent/hardware" on stage now
		dressedAgent: string?, -- whose outfit the rig on stage wears
		requestedAgent: string?,
		requestedHardware: string?,
		previewTemplate: Model?,
		loadingTemplate: boolean,
		templateAttempts: number,
		destroyed: boolean,
		feet: CFrame,
		framing: Framing,
		poseState: StagePose.State?,
		idleBusyUntil: number, -- a pose transition runs until then; idle motion waits for it
		idleSince: number,
		idleAccumulator: number,
		poseJanitor: Janitor.Janitor,
		fadeJanitor: Janitor.Janitor,
		visibility: NumberValue,
		opacity: { [Instance]: number },
		cameraTween: Tween?,
	},
	MenuStage
))

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material
)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function lamp(parent: Instance, position: Vector3, color: Color3, brightness: number, range: number)
	local holder =
		part(parent, "Lamp", Vector3.new(0.6, 1.2, 0.3), CFrame.new(position), config.Brass, Enum.Material.Metal)
	-- Lighting helpers are not set dressing and must never become foreground boxes during a camera move.
	holder.Transparency = 1
	holder.CastShadow = false
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = brightness
	light.Range = range
	light.Shadows = config.LampShadows
	light.Parent = holder
end

local function shotFrame(framing: Framing): CFrame
	local shot = config.Cameras[framing]
	local origin = CFrame.new(config.Origin)
	return CFrame.lookAt((origin * CFrame.new(shot.Eye)).Position, (origin * CFrame.new(shot.Focus)).Position)
end

-- The balcony floor and a small fixed non-shadowed light budget. Set dressing is built by GalaSet.
local function buildRoom(folder: Folder, origin: CFrame)
	part(
		folder,
		"BalconyFloor",
		Vector3.new(config.RoomSize.X, 1, config.RoomSize.Z),
		origin * CFrame.new(0, -0.5, 0),
		config.Floor,
		Enum.Material.Marble
	)
	-- Only local, non-shadowed stage lights; the map's Lighting and time of day remain untouched.
	lamp(folder, (origin * CFrame.new(-3, 9, -4)).Position, config.LampColor, config.LampBrightness, config.LampRange)
	for _, side in { -1, 1 } do
		lamp(
			folder,
			(origin * CFrame.new(side * 15, 7, 5)).Position,
			config.LampColor,
			config.LampBrightness,
			config.LampRange
		)
	end
	local rim = part(
		folder,
		"Rim",
		Vector3.new(0.2, 0.2, 0.2),
		origin * CFrame.new(1.5, 6, 3),
		config.RimColor,
		Enum.Material.Neon
	)
	rim.Transparency = 1
	local light = Instance.new("PointLight")
	light.Color = config.RimColor
	light.Brightness = config.RimBrightness
	light.Range = config.LampRange / 2
	light.Shadows = false
	light.Parent = rim
end

-- A blank local R15 uses the same construction API and outfit as RigService without requiring a spawned character.
-- StarterCharacter is a spawn template, so it must not be the menu's only possible rig source.
local function requestPreviewTemplate(self: MenuStage)
	if
		self.loadingTemplate
		or self.previewTemplate
		or self.destroyed
		or self.templateAttempts >= config.RigAttempts
	then
		return
	end
	self.loadingTemplate = true
	self.templateAttempts += 1
	task.spawn(function()
		local description = Instance.new("HumanoidDescription")
		local ok, result = pcall(function()
			return Players:CreateHumanoidModelFromDescriptionAsync(description, Enum.HumanoidRigType.R15)
		end)
		description:Destroy()
		self.loadingTemplate = false
		if ok then
			if self.destroyed then
				result:Destroy()
				return
			end
			self.previewTemplate = result
			self.janitor:Add(result)
			if self.requestedAgent then
				self:show(self.requestedAgent, self.requestedHardware)
			end
		elseif not self.destroyed then
			warn(`[MenuStage] Preview rig unavailable: {result}`)
			if self.templateAttempts < config.RigAttempts then
				self.janitor:Add(task.delay(config.RigRetrySeconds, function()
					if self.requestedAgent and not self.rig then
						requestPreviewTemplate(self)
					end
				end))
			end
		end
	end)
end

local idleStep: (self: MenuStage, dt: number) -> () -- defined after poseOperative, which it drives

function MenuStage.new(): MenuStage
	local janitor = Janitor.new()
	local folder = Instance.new("Folder")
	folder.Name = "MenuStage" -- inside a folder, so WeaponVisualController's scan of Workspace's children never sees the rig
	folder.Parent = workspace
	janitor:Add(folder)
	local poseJanitor, fadeJanitor = Janitor.new(), Janitor.new()
	janitor:Add(poseJanitor)
	janitor:Add(fadeJanitor)
	local visibility = Instance.new("NumberValue")
	visibility.Value = 0
	janitor:Add(visibility)
	local origin = CFrame.new(config.Origin)
	buildRoom(folder, origin)
	GalaSet.build(folder, origin)
	local self = setmetatable({
		janitor = janitor,
		folder = folder,
		rig = nil,
		weapon = nil,
		shown = nil,
		dressedAgent = nil,
		requestedAgent = nil,
		requestedHardware = nil,
		previewTemplate = nil,
		loadingTemplate = false,
		templateAttempts = 0,
		destroyed = false,
		framing = "Play" :: Framing,
		poseState = nil,
		idleBusyUntil = 0,
		idleSince = 0,
		idleAccumulator = 0,
		poseJanitor = poseJanitor,
		fadeJanitor = fadeJanitor,
		visibility = visibility,
		opacity = {},
		-- The operative faces the camera (-Z); the open balcony and skyline sit behind them.
		feet = origin * CFrame.Angles(0, math.rad(config.RigTurnDegrees), 0),
		cameraTween = nil,
	}, MenuStage)
	janitor:Add(visibility.Changed:Connect(function(value: number)
		for item, base in self.opacity do
			if item.Parent and (item:IsA("BasePart") or item:IsA("Decal")) then
				item.Transparency = base + (1 - base) * (1 - value)
			end
		end
	end))
	-- Idle life (owner 2026-11-25): the finished pose gets breathing, a leaning upper body and a roving head added on top.
	janitor:Add(RunService.Heartbeat:Connect(function(dt: number)
		idleStep(self, dt)
	end))
	-- The server builds StarterCharacter asynchronously. A menu request must survive late/partial replication.
	janitor:Add(StarterPlayer.DescendantAdded:Connect(function()
		if self.requestedAgent and not self.rig then
			self:show(self.requestedAgent, self.requestedHardware)
		end
	end))
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	-- Enter at a valid balcony shot. Tweening from the gameplay camera flies through the intervening world/floor.
	camera.CFrame = shotFrame("Play")
	camera.FieldOfView = config.Cameras.Play.FieldOfView
	return self
end

local function clearOperative(self: MenuStage)
	self.poseJanitor:Cleanup()
	self.poseState = nil
	self.dressedAgent = nil
	table.clear(self.opacity)
	if self.weapon then
		self.weapon:destroy()
		self.weapon = nil
	end
	if self.rig then
		self.rig:Destroy()
		self.rig = nil
	end
end

local function familyOf(self: MenuStage): string
	return if self.requestedHardware
		then (config.Portrait.WeaponFamilies :: { [string]: string })[self.requestedHardware] or "TwoHanded"
		else "OneHanded"
end

local function captureOpacity(self: MenuStage, model: Model)
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") or item:IsA("Decal") then
			local base = item.Transparency
			self.opacity[item] = base
			item.Transparency = base + (1 - base) * (1 - self.visibility.Value)
		end
	end
end

local function fadeOperative(self: MenuStage, value: number, finished: (() -> ())?)
	self.fadeJanitor:Cleanup()
	if UiAccessibility.reducedMotion() or self.visibility.Value == value then
		self.visibility.Value = value
		if finished then
			finished()
		end
		return
	end
	local tween = TweenService:Create(self.visibility, fadeInfo, { Value = value })
	self.fadeJanitor:Add(function()
		tween:Cancel()
	end)
	if finished then
		self.fadeJanitor:Add(tween.Completed:Connect(function(status)
			if status == Enum.PlaybackState.Completed then
				finished()
			end
		end))
	end
	tween:Play()
end

local function poseOperative(self: MenuStage, state: StagePose.State)
	local rig = self.rig
	if not rig then
		return
	end
	local portrait = config.Portrait
	self.poseState = state
	StagePose.apply(rig, state, self.feet)
	local hand = rig:FindFirstChild("RightHand") :: BasePart
	local left = rig:FindFirstChild("LeftHand") :: BasePart
	local weapon = self.weapon
	if not weapon then
		return
	end
	local angles = portrait.GripDegrees
	local grip = CFrame.Angles(math.rad(angles.X), math.rad(angles.Y), math.rad(angles.Z))
	local rightFrame = hand.CFrame * grip
	if state.SupportWeapon > 0 then
		local target = rightFrame * weapon.rightGrip:Inverse() * weapon.leftGrip * grip:Inverse()
		StagePose.reachLeftHand(rig, left.CFrame:Lerp(target, state.SupportWeapon))
	end
	if state.SupportCuff > 0 then
		StagePose.reachLeftHand(rig, left.CFrame:Lerp(hand.CFrame * portrait.CuffOffset, state.SupportCuff))
	end
	weapon:placeAtRightHand(rightFrame, left.CFrame * grip)
end

idleStep = function(self: MenuStage, dt: number)
	local rig, base = self.rig, self.poseState
	local idle = config.Idle
	self.idleAccumulator += dt
	if
		not rig
		or not base
		or self.destroyed
		or self.visibility.Value <= 0
		or self.idleAccumulator < 1 / idle.Hz
		or UiAccessibility.reducedMotion()
	then
		return
	end
	local now = os.clock()
	if now < self.idleBusyUntil then
		return
	end
	self.idleAccumulator = 0
	local intensity = math.clamp((now - self.idleBusyUntil) / idle.BlendInSeconds, 0, 1)
	poseOperative(self, StagePose.idle(base, now, intensity))
	self.poseState = base -- the base pose stays the thing a screen change blends from
end

local function transitionPose(self: MenuStage)
	self.poseJanitor:Cleanup()
	self.idleBusyUntil = os.clock() + panInfo.Time
	local goal = StagePose.describe(self.framing, familyOf(self))
	local from = self.poseState
	if not self.rig or not from or UiAccessibility.reducedMotion() then
		self.poseState = goal
		poseOperative(self, goal)
		return
	end
	local alpha = self.poseJanitor:Add(Instance.new("NumberValue"))
	self.poseJanitor:Add(alpha.Changed:Connect(function(value: number)
		if not self.destroyed and self.rig then
			poseOperative(self, StagePose.blend(from, goal, value))
		end
	end))
	local tween = TweenService:Create(alpha, panInfo, { Value = 1 })
	self.poseJanitor:Add(function()
		tween:Cancel()
	end)
	poseOperative(self, from)
	tween:Play()
end

local function replaceWeapon(self: MenuStage, hardwareId: string?)
	if self.weapon then
		for _, item in self.weapon.model:GetDescendants() do
			self.opacity[item] = nil
		end
		self.weapon:destroy()
		self.weapon = nil
	end
	local def = hardwareId and WeaponDefs.get(hardwareId)
	if def then
		local weapon = ViewModel.new(def)
		weapon.model.Name = "StageWeapon"
		weapon.model.Parent = self.folder
		self.weapon = weapon
		captureOpacity(self, weapon.model)
	end
	transitionPose(self)
end

-- Keep the shared display body across selections and replace only the selected Hardware.
function MenuStage.show(self: MenuStage, agentId: string, hardwareId: string?)
	if self.destroyed then
		return
	end
	self.requestedAgent, self.requestedHardware = agentId, hardwareId
	local key = `{agentId}/{hardwareId or ""}`
	if self.shown == key then
		fadeOperative(self, 1)
		return
	end
	if self.rig and self.dressedAgent ~= agentId then
		clearOperative(self) -- a different agent has a different outfit: build the rig again
	end
	if self.rig then
		replaceWeapon(self, hardwareId)
		self.shown = key
		fadeOperative(self, 1)
		return
	end
	clearOperative(self)
	self.shown = nil
	local template = self.previewTemplate or StarterPlayer:FindFirstChild("StarterCharacter")
	if not (template and template:IsA("Model")) then
		requestPreviewTemplate(self)
		return
	end
	for _, name in
		{
			"HumanoidRootPart",
			"Head",
			"UpperTorso",
			"LowerTorso",
			"LeftUpperArm",
			"LeftLowerArm",
			"LeftHand",
			"RightUpperArm",
			"RightLowerArm",
			"RightHand",
			"LeftUpperLeg",
			"LeftLowerLeg",
			"LeftFoot",
			"RightUpperLeg",
			"RightLowerLeg",
			"RightFoot",
		}
	do
		local body = template:FindFirstChild(name)
		if not (body and body:IsA("BasePart")) then
			requestPreviewTemplate(self)
			return
		end
	end
	if not template:FindFirstChildOfClass("Humanoid") then
		requestPreviewTemplate(self)
		return
	end
	local rig = template:Clone()
	-- Match RigService's classic joint conversion so a freshly generated display body stays upright.
	for _, item in rig:GetDescendants() do
		if item.ClassName == "AnimationConstraint" then
			local constraint = item :: any
			local a, b = constraint.Attachment0 :: Attachment?, constraint.Attachment1 :: Attachment?
			if a and b then
				local joint = Instance.new("Motor6D")
				joint.Name = item.Name
				joint.Part0, joint.Part1 = a.Parent :: BasePart, b.Parent :: BasePart
				joint.C0, joint.C1 = a.CFrame, b.CFrame
				joint.Parent = b.Parent
			end
			item:Destroy()
		elseif
			item:IsA("BallSocketConstraint")
			or item:IsA("NoCollisionConstraint")
			or item.ClassName == "WrapTarget"
		then
			item:Destroy()
		end
	end
	local root = rig:FindFirstChild("HumanoidRootPart") :: BasePart
	local humanoid = rig:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.AutoRotate = false
	root.Transparency = 1 -- never include the internal rig pivot in the visible/fading actor
	root.CastShadow = false
	for _, item in rig:GetDescendants() do
		if item:IsA("BasePart") then
			item.LocalTransparencyModifier = 0
			item.CanCollide, item.CanTouch, item.CanQuery = false, false, false
		elseif item:IsA("Script") or item:IsA("LocalScript") then
			item:Destroy()
		end
	end
	root.Anchored = true
	rig.Parent = self.folder
	local outfit = AgentLooks.outfit(agentId)
	OutfitApplier.apply(rig, outfit)
	self.dressedAgent = agentId
	-- The shared fallback Crop is a flat rectangular Part. Give this close-up display a rounded crown,
	-- with its center at the head's HairAttachment instead of a visor-shaped box lowered across the face.
	local hair = rig:FindFirstChild("Hair")
	local hairHandle = hair and hair:FindFirstChild("Handle")
	if outfit.Hair.Style == "Crop" and hairHandle and hairHandle:IsA("Part") then
		hairHandle.Shape = Enum.PartType.Ball
		hairHandle.Size *= Vector3.new(1, 1.5, 0.9)
		local attachment = hairHandle:FindFirstChild("HairAttachment")
		if attachment and attachment:IsA("Attachment") then
			attachment.CFrame = CFrame.identity
		end
	end
	rig:PivotTo(self.feet * CFrame.new(0, humanoid.HipHeight + root.Size.Y / 2, 0))
	self.rig = rig
	self.shown = key
	self.visibility.Value = 0
	captureOpacity(self, rig)
	replaceWeapon(self, hardwareId)
	fadeOperative(self, 1)
end

-- Takes the operative off the stage (a screen with no use for them); show() puts them back.
function MenuStage.hideOperative(self: MenuStage)
	self.requestedAgent, self.requestedHardware = nil, nil
	self.shown = nil
	fadeOperative(self, 0, function()
		if not self.requestedAgent then
			clearOperative(self)
		end
	end)
end

function MenuStage.frame(self: MenuStage, framing: Framing)
	self.framing = framing
	transitionPose(self)
	local shot = config.Cameras[framing]
	local goal = shotFrame(framing)
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	if self.cameraTween then
		self.cameraTween:Cancel()
	end
	if UiAccessibility.reducedMotion() then
		camera.CFrame = goal
		camera.FieldOfView = shot.FieldOfView
	else
		local tween = TweenService:Create(camera, panInfo, { CFrame = goal, FieldOfView = shot.FieldOfView })
		self.cameraTween = tween
		tween:Play()
	end
end

-- Removes the stage and gives the camera back to the game (Custom, the default field of view).
function MenuStage.destroy(self: MenuStage)
	self.destroyed = true
	self.requestedAgent, self.requestedHardware = nil, nil
	if self.cameraTween then
		self.cameraTween:Cancel()
	end
	clearOperative(self)
	self.janitor:Destroy()
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	camera.FieldOfView = GameConfig.Menu.Stage.DefaultFieldOfView
end

return MenuStage
