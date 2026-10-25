--!strict
-- Geometry-only hint for every upright humanoid rig. The server still selects the target and validates the hold.
-- No target name, team test, marker or attribute is attached to any character.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local HudKit = require(Shared:WaitForChild("Util"):WaitForChild("HudKit"))
local HudTheme = require(Shared:WaitForChild("Util"):WaitForChild("HudTheme"))
local Janitor = require(Shared:WaitForChild("Util"):WaitForChild("Janitor"))
local RemoteController = require(script.Parent.RemoteController)
local WeaponController = require(script.Parent.WeaponController)
local TakedownHintController = {}
local config = GameConfig.Combat
local graphics = HudTheme.get()
local janitor = Janitor.new()
local candidates: { [Model]: boolean } = {}
local enabled, active, interacting = true, false, false
local params = RaycastParams.new()
params.CollisionGroup = GameConfig.Rig.CollisionGroup
params.RespectCanCollide = true

local function add(instance: Instance)
	if instance:IsA("Model") then
		candidates[instance] = true
	end
end

local function available(): boolean
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local camera = workspace.CurrentCamera
	if
		not (
			enabled
			and not active
			and not interacting
			and root
			and root:IsA("BasePart")
			and humanoid
			and humanoid.Health > 0
			and camera
		) or WeaponController.getStatus().attackBlocked
	then
		return false
	end
	local look = camera.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)
	if flatLook.Magnitude < graphics.DirectionEpsilonStuds then
		return false
	end
	flatLook = flatLook.Unit
	local nearest: BasePart? = nil
	local best = math.huge
	local reach = config.Melee.Range + config.Melee.ReachSlackStuds
	for model in candidates do
		if model ~= character then
			local other = model:FindFirstChild("HumanoidRootPart")
			local otherHumanoid = model:FindFirstChildOfClass("Humanoid")
			local controller = model:FindFirstChildOfClass("AnimationController")
			if
				other
				and other:IsA("BasePart")
				and ((otherHumanoid and otherHumanoid.Health > 0) or controller)
				and math.abs(other.CFrame.UpVector.Y) > math.abs(other.CFrame.LookVector.Y)
			then
				local offset = other.Position - root.Position
				local flat = Vector3.new(offset.X, 0, offset.Z)
				local distance = flat.Magnitude
				if
					distance <= reach
					and distance < best
					and math.abs(offset.Y) <= config.Melee.HeightStuds
					and (distance < graphics.DirectionEpsilonStuds or flat.Unit:Dot(flatLook) >= math.cos(
						math.rad(config.Melee.SwingConeDegrees / 2)
					))
					and workspace:Raycast(root.Position, offset, params) == nil
				then
					nearest, best = other, distance
				end
			end
		end
	end
	if not nearest then
		return false
	end
	local behind = root.Position - nearest.Position
	local flat = Vector3.new(behind.X, 0, behind.Z)
	local facing = nearest.CFrame.LookVector
	local forward = Vector3.new(facing.X, 0, facing.Z)
	if forward.Magnitude < graphics.DirectionEpsilonStuds then
		return false
	end
	return flat.Magnitude < graphics.DirectionEpsilonStuds
		or (-forward.Unit):Dot(flat.Unit) >= math.cos(math.rad(config.Takedown.ConeDegrees / 2))
end

function TakedownHintController.Init() end

function TakedownHintController.Start()
	local gui = HudKit.screen("TakedownHint")
	janitor:Add(gui)
	local panel = HudKit.panel(
		gui,
		"Opportunity",
		UDim2.new(0.5, 0, 0.5, graphics.ActionOffsetPixels),
		Vector2.new(0.5, 0),
		UDim2.fromOffset(graphics.ActionWidthPixels, graphics.ActionHeightPixels)
	)
	local root = panel.Parent :: Frame
	local label = HudKit.text(
		panel,
		"Hint",
		UDim2.fromOffset(graphics.PaddingPixels, graphics.PaddingPixels),
		Vector2.zero,
		UDim2.new(1, -graphics.PaddingPixels * 2, 0, graphics.IconPixels)
	)
	local input = game:GetService("UserInputService")
	root.Visible = false
	for _, instance in workspace:GetChildren() do
		add(instance)
	end
	janitor:Add(workspace.ChildAdded:Connect(add))
	janitor:Add(workspace.ChildRemoved:Connect(function(instance: Instance)
		if instance:IsA("Model") then
			candidates[instance] = nil
		end
	end))
	janitor:Add(RemoteController.connect("Downed", function()
		enabled = false
	end))
	janitor:Add(RemoteController.connect("Eliminated", function()
		enabled = false
	end))
	janitor:Add(RemoteController.connect("Revived", function()
		enabled = true
	end))
	janitor:Add(RemoteController.connect("MeleeState", function(info: { Active: boolean })
		active = info.Active
	end))
	janitor:Add(RemoteController.connect("InteractState", function(info: { Active: boolean })
		interacting = info.Active
	end))
	janitor:Add(Players.LocalPlayer.CharacterAdded:Connect(function()
		enabled, active, interacting = true, false, false
	end))
	local elapsed = 0
	janitor:Add(RunService.RenderStepped:Connect(function(dt: number)
		elapsed += dt
		if elapsed >= config.Takedown.CheckSeconds then
			elapsed = 0
			root.Visible = available()
			local usingPad = string.find(input:GetLastInputType().Name, "Gamepad", 1, true) ~= nil
			local key = if usingPad then GameConfig.Controls.MeleePad else GameConfig.Controls.Melee
			label.Text = `[ {string.gsub(key.Name, "^Button", "")} ] TAKEDOWN`
		end
	end))
	janitor:Add(script.Destroying:Connect(function()
		janitor:Destroy()
	end))
end

return TakedownHintController
