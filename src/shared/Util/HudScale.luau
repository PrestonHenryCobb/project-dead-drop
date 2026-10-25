--!strict
-- Ticket 19-hud-scale: event-driven panel sizing, with unchanged screen anchors and angular aiming coordinates.
local GameConfig = require(script.Parent.Parent.GameConfig)
local Janitor = require(script.Parent.Janitor)
local config = GameConfig.UI.PanelScale
local HudScale = {}

function HudScale.factor(viewport: Vector2): number
	return math.clamp(
		math.min(viewport.X / config.ReferenceWidthPixels, viewport.Y / config.ReferenceHeightPixels),
		config.Minimum,
		config.Maximum
	)
end

-- A container reference also supports panels in bounded UI previews; ordinary HUDs follow CurrentCamera.
function HudScale.bind(root: GuiObject, reference: GuiObject?)
	local janitor = Janitor.new()
	local cameraJanitor = Janitor.new()
	janitor:Add(cameraJanitor)
	local scaler = Instance.new("UIScale")
	scaler.Name = "ViewportScale"
	scaler.Parent = root
	janitor:Add(scaler)
	local basePosition = root.Position
	local appliedPosition = root.Position
	local function refresh()
		local camera = workspace.CurrentCamera
		local viewport = if reference
			then reference.AbsoluteSize
			else (if camera then camera.ViewportSize else Vector2.zero)
		local factor = HudScale.factor(viewport)
		scaler.Scale = factor
		-- UIScale scales size/children, not the top-level panel's screen-space margin.
		appliedPosition = UDim2.new(
			basePosition.X.Scale,
			basePosition.X.Offset * factor,
			basePosition.Y.Scale,
			basePosition.Y.Offset * factor
		)
		root.Position = appliedPosition
	end
	janitor:Add(root:GetPropertyChangedSignal("Position"):Connect(function()
		if root.Position ~= appliedPosition then
			basePosition = root.Position
			refresh()
		end
	end))
	if reference then
		janitor:Add(reference:GetPropertyChangedSignal("AbsoluteSize"):Connect(refresh))
		refresh()
	else
		local function cameraChanged()
			cameraJanitor:Cleanup()
			local camera = workspace.CurrentCamera
			if camera then
				cameraJanitor:Add(camera:GetPropertyChangedSignal("ViewportSize"):Connect(refresh))
			end
			refresh()
		end
		janitor:Add(workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(cameraChanged))
		cameraChanged()
	end
	janitor:Add(root.Destroying:Connect(function()
		janitor:Destroy()
	end))
end

return table.freeze(HudScale)
