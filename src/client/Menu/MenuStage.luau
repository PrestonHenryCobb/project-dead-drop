--!strict
-- Cinematic gala balcony behind the menu. Client-only geometry far from the map, with one operative holding
-- their Hardware and the camera framings each screen uses.
--
-- The operative is the game's own rig (StarterPlayer.StarterCharacter, made by RigService) dressed by OutfitApplier.
-- Agents have no look of their own until Step 16, so every agent stands in the shared True Form outfit; only the weapon
-- changes. Weapons not built yet (no WeaponDef) are shown without a gun rather than with a stand-in.
--
--   local stage = MenuStage.new()
--   stage:show("Guise", "GuiseSMG")
--   stage:hideOperative()          -- for screens that do not show the operative
--   stage:frame("Play")            -- "Play" | "Agents" | "PreDeploy"; snaps when Reduce Motion is on
--   stage:destroy()                -- removes everything and hands the camera back

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Janitor = require(Shared:WaitForChild("Util"):WaitForChild("Janitor"))
local OutfitApplier = require(Shared:WaitForChild("Util"):WaitForChild("OutfitApplier"))
local OutfitDefs = require(Shared:WaitForChild("Defs"):WaitForChild("OutfitDefs"))
local UiAccessibility = require(Shared:WaitForChild("Util"):WaitForChild("UiAccessibility"))
local WeaponDefs = require(Shared:WaitForChild("Defs"):WaitForChild("WeaponDefs"))
local ViewModel = require(script.Parent.Parent:WaitForChild("Combat"):WaitForChild("ViewModel"))

local GalaSet = require(script.Parent.Components.GalaSet)
local config = GameConfig.Menu.Stage
local panInfo = TweenInfo.new(GameConfig.Menu.CameraPanSeconds, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

export type Framing = "Play" | "Agents" | "PreDeploy"

local MenuStage = {}
MenuStage.__index = MenuStage

export type MenuStage = typeof(setmetatable(
	{} :: {
		janitor: Janitor.Janitor,
		folder: Folder,
		rig: Model?,
		weapon: ViewModel.ViewModel?,
		shown: string?, -- "agent/hardware" on stage now
		feet: CFrame,
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
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = brightness
	light.Range = range
	light.Shadows = config.LampShadows
	light.Parent = holder
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

function MenuStage.new(): MenuStage
	local janitor = Janitor.new()
	local folder = Instance.new("Folder")
	folder.Name = "MenuStage" -- inside a folder, so WeaponVisualController's scan of Workspace's children never sees the rig
	folder.Parent = workspace
	janitor:Add(folder)
	local origin = CFrame.new(config.Origin)
	buildRoom(folder, origin)
	GalaSet.build(folder, origin)
	local self = setmetatable({
		janitor = janitor,
		folder = folder,
		rig = nil,
		weapon = nil,
		shown = nil,
		-- The operative faces the camera (-Z); the open balcony and skyline sit behind them.
		feet = origin * CFrame.Angles(0, math.rad(config.RigTurnDegrees), 0),
		cameraTween = nil,
	}, MenuStage)
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = config.FieldOfView
	return self
end

local function clearOperative(self: MenuStage)
	if self.weapon then
		self.weapon:destroy()
		self.weapon = nil
	end
	if self.rig then
		self.rig:Destroy()
		self.rig = nil
	end
end

-- Puts the operative on stage holding this Hardware. Rebuilds only when the agent or weapon changes.
function MenuStage.show(self: MenuStage, agentId: string, hardwareId: string?)
	local key = `{agentId}/{hardwareId or ""}`
	if self.shown == key then
		return
	end
	clearOperative(self)
	self.shown = nil
	local template = StarterPlayer:FindFirstChild("StarterCharacter")
	if not (template and template:IsA("Model")) then
		return -- RigService has not made the rig yet; the next show() call tries again
	end
	self.shown = key
	local rig = template:Clone()
	local root = rig:FindFirstChild("HumanoidRootPart") :: BasePart
	local humanoid = rig:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	root.Anchored = true
	rig.Parent = self.folder
	OutfitApplier.apply(rig, OutfitDefs.trueForm)
	rig:PivotTo(self.feet * CFrame.new(0, humanoid.HipHeight + root.Size.Y / 2, 0))
	self.rig = rig

	local def = hardwareId and WeaponDefs.get(hardwareId)
	local hand = rig:FindFirstChild("RightHand")
	if def and hand and hand:IsA("BasePart") then
		local weapon = ViewModel.new(def)
		weapon.model.Name = "StageWeapon"
		weapon.model.Parent = self.folder
		local left = rig:FindFirstChild("LeftHand")
		-- Held at the side, barrel forward: the rig's own resting hand, turned so the gun points along the body.
		weapon:placeAtRightHand(
			hand.CFrame * CFrame.Angles(math.rad(-90), 0, 0),
			if left and left:IsA("BasePart") then left.CFrame else nil
		)
		self.weapon = weapon
	end
end

-- Takes the operative off the stage (a screen with no use for them); show() puts them back.
function MenuStage.hideOperative(self: MenuStage)
	self.shown = nil
	clearOperative(self)
end

function MenuStage.frame(self: MenuStage, framing: Framing)
	local shot = config.Cameras[framing]
	local goal =
		CFrame.lookAt((self.feet * CFrame.new(shot.Eye)).Position, (self.feet * CFrame.new(shot.Focus)).Position)
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	if self.cameraTween then
		self.cameraTween:Cancel()
	end
	if UiAccessibility.reducedMotion() then
		camera.CFrame = goal
	else
		local tween = TweenService:Create(camera, panInfo, { CFrame = goal })
		self.cameraTween = tween
		tween:Play()
	end
end

-- Removes the stage and gives the camera back to the game (Custom, the default field of view).
function MenuStage.destroy(self: MenuStage)
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
