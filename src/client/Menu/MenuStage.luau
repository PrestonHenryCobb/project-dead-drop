--!strict
-- Ticket menu-shell: the 3D stage behind the menu. A small walnut-and-brass mezzanine built on this client only, far from
-- the map, with one operative on it holding their Hardware, and the camera framings each screen uses.
--
-- The operative is the game's own rig (StarterPlayer.StarterCharacter, made by RigService) dressed by OutfitApplier.
-- Agents have no look of their own until Step 16, so every agent stands in the shared True Form outfit; only the weapon
-- changes. Weapons not built yet (no WeaponDef) are shown without a gun rather than with a stand-in.
--
--   local stage = MenuStage.new()
--   stage:show("Guise", "GuiseSMG")
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
	light.Shadows = true
	light.Parent = holder
end

-- The room: floor, carpet, back and side walls in walnut, a brass rail across the back (the mezzanine balustrade),
-- pilasters, sconces and a cool rim light behind the operative. Open towards the camera (-Z).
local function buildRoom(folder: Folder, origin: CFrame)
	local size = config.RoomSize
	local wood = Enum.Material.WoodPlanks
	part(
		folder,
		"Floor",
		Vector3.new(size.X, 1, size.Z),
		origin * CFrame.new(0, -0.5, 0),
		config.Floor,
		Enum.Material.Marble
	)
	part(
		folder,
		"Carpet",
		Vector3.new(10, 0.1, 10),
		origin * CFrame.new(0, 0.05, 0),
		config.Carpet,
		Enum.Material.Fabric
	)
	part(
		folder,
		"BackWall",
		Vector3.new(size.X, size.Y, 1),
		origin * CFrame.new(0, size.Y / 2, size.Z / 2),
		config.Walnut,
		wood
	)
	for _, side in { -1, 1 } do
		part(
			folder,
			"SideWall",
			Vector3.new(1, size.Y, size.Z),
			origin * CFrame.new(side * size.X / 2, size.Y / 2, 0),
			config.Walnut,
			wood
		)
		for _, x in { 7, 15 } do
			part(
				folder,
				"Pilaster",
				Vector3.new(1.6, size.Y, 1.2),
				origin * CFrame.new(side * x, size.Y / 2, size.Z / 2 - 1),
				config.Floor,
				Enum.Material.Marble
			)
			lamp(
				folder,
				(origin * CFrame.new(side * x, 9, size.Z / 2 - 1.8)).Position,
				config.LampColor,
				config.LampBrightness,
				config.LampRange
			)
		end
	end
	-- The balustrade: a brass handrail on slim posts in front of the back wall.
	local railZ = size.Z / 2 - 4
	part(
		folder,
		"Rail",
		Vector3.new(size.X - 4, 0.3, 0.3),
		origin * CFrame.new(0, 3.4, railZ),
		config.Brass,
		Enum.Material.Metal
	)
	part(
		folder,
		"RailFoot",
		Vector3.new(size.X - 4, 0.3, 0.6),
		origin * CFrame.new(0, 0.15, railZ),
		config.Brass,
		Enum.Material.Metal
	)
	for x = -(size.X / 2 - 3), size.X / 2 - 3, 1.5 do
		part(
			folder,
			"Baluster",
			Vector3.new(0.15, 3.3, 0.15),
			origin * CFrame.new(x, 1.75, railZ),
			config.Brass,
			Enum.Material.Metal
		)
	end
	-- Key light over the operative and a cyan rim from behind, so the silhouette reads against the dark wood.
	lamp(folder, (origin * CFrame.new(-3, 11, -4)).Position, config.LampColor, config.LampBrightness, config.LampRange)
	local rim = part(
		folder,
		"Rim",
		Vector3.new(0.2, 0.2, 0.2),
		origin * CFrame.new(1.5, 6, 3),
		config.RimColor,
		Enum.Material.Neon
	)
	rim.Transparency = 1
	local rimLight = Instance.new("PointLight")
	rimLight.Color = config.RimColor
	rimLight.Brightness = config.RimBrightness
	rimLight.Range = config.LampRange / 2
	rimLight.Parent = rim
end

function MenuStage.new(): MenuStage
	local janitor = Janitor.new()
	local folder = Instance.new("Folder")
	folder.Name = "MenuStage" -- inside a folder, so WeaponVisualController's scan of Workspace's children never sees the rig
	folder.Parent = workspace
	janitor:Add(folder)
	local origin = CFrame.new(config.Origin)
	buildRoom(folder, origin)
	local self = setmetatable({
		janitor = janitor,
		folder = folder,
		rig = nil,
		weapon = nil,
		shown = nil,
		-- The operative faces the open side of the room (-Z), where the camera is; the back wall is behind them.
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
	self.shown = key
	clearOperative(self)
	local template = StarterPlayer:FindFirstChild("StarterCharacter")
	if not (template and template:IsA("Model")) then
		return -- RigService has not made the rig yet; the next show() call tries again
	end
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
