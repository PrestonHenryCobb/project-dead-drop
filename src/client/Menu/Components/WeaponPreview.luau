--!strict
-- Uses the playable weapon builders; the model is moved off the gameplay camera immediately.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Types = require(ReplicatedStorage.Shared.Types)
local ViewModel = require(script.Parent.Parent.Parent.Combat.ViewModel)
local Kit = require(script.Parent.ViewKit)
local Art = require(script.Parent.DecoArt)
local Preview = {}

function Preview.mount(parent: Instance, def: Types.WeaponDef, janitor: any, interactive: boolean?)
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "HardwareArtwork"
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.BackgroundColor3 = Kit.Theme.Colors.Canvas
	viewport.BorderSizePixel = 0
	viewport.Ambient = Color3.fromRGB(180, 170, 145)
	viewport.LightColor = Color3.fromRGB(255, 239, 205)
	viewport.LightDirection = Vector3.new(-1, -1, -1)
	viewport.Parent = parent
	Art.trim(viewport)
	local world = Instance.new("WorldModel")
	world.Parent = viewport
	local weapon = ViewModel.new(def)
	weapon.model.Parent = world
	weapon:placeAtRightHand(weapon.rightGrip)
	janitor:Add(function()
		weapon:destroy()
	end)
	local camera = Instance.new("Camera")
	camera.FieldOfView = 32
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	local bounds, size = weapon.model:GetBoundingBox()
	local yaw = 1.25
	local zoomed = false
	local function render()
		local aspect = math.max(viewport.AbsoluteSize.X / math.max(viewport.AbsoluteSize.Y, 1), 0.1)
		local radius = size.Magnitude / 2
		local fov = math.rad(camera.FieldOfView / 2)
		local distance = radius / math.sin(math.min(fov, math.atan(math.tan(fov) * aspect)))
		distance *= if zoomed then 1.03 else 1.22
		local center = bounds.Position
		camera.CFrame = CFrame.lookAt(center + Vector3.new(math.sin(yaw), 0.16, math.cos(yaw)).Unit * distance, center)
	end
	janitor:Add(viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(render))
	if interactive then
		local dragging = false
		local stick = 0
		viewport.Active = true
		janitor:Add(viewport.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				dragging = true
			end
		end))
		janitor:Add(UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				dragging = false
			end
			if input.KeyCode == Enum.KeyCode.Thumbstick2 then
				stick = 0
			end
		end))
		janitor:Add(UserInputService.InputChanged:Connect(function(input)
			if input.KeyCode == Enum.KeyCode.Thumbstick2 then
				stick = input.Position.X
			end
			if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
				yaw += input.Delta.X * 0.012
				render()
			end
		end))
		janitor:Add(UserInputService.WindowFocusReleased:Connect(function()
			dragging = false
			stick = 0
		end))
		janitor:Add(RunService.RenderStepped:Connect(function(dt)
			local selected = GuiService.SelectedObject
			if math.abs(stick) > 0.15 and selected and selected:IsDescendantOf(parent.Parent) then
				yaw += stick * dt * 2
				render()
			end
		end))
	end
	render()
	return {
		rotate = function(delta: number)
			yaw += delta
			render()
		end,
		zoom = function()
			zoomed = not zoomed
			render()
		end,
	}
end
return Preview
