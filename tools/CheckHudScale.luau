--!strict
-- Ticket 19-hud-scale: native UI layout assertions; safe in the Studio EDIT command bar.
-- Makes invisible CoreGui fixtures and fresh module clones. Does not start/stop Play, rebuild or touch world state.
local RunService = game:GetService("RunService")
assert(RunService:IsStudio(), "Studio review only")
local clone = game.ReplicatedStorage.Shared:Clone()
clone.Name = "HudScaleReviewModules"
clone.Parent = game.ServerStorage
local gui = Instance.new("ScreenGui")
gui.Name = "HudScaleReviewFixtures"
gui.IgnoreGuiInset = true
gui.Parent = game:GetService("CoreGui")
local ok, problem = pcall(function()
	local kit = require(clone.Util.HudKit)
	local scale = require(clone.Util.HudScale)
	local reference = Instance.new("Frame")
	reference.BackgroundTransparency = 1
	reference.Visible = false
	reference.Parent = gui
	local config = require(clone.GameConfig).UI
	local layout = require(clone.Util.HudTheme).get()
	local cover = kit.panel(
		reference,
		"Cover",
		UDim2.new(0.5, 0, 1, -layout.CoverBottomPixels),
		Vector2.new(0.5, 1),
		UDim2.fromOffset(layout.CoverWidthPixels, layout.CoverHeightPixels)
	)
	local warning = kit.panel(
		reference,
		"Warning",
		UDim2.new(0.5, 0, 1, -(layout.CoverBottomPixels + layout.CoverHeightPixels + layout.PaddingPixels)),
		Vector2.new(0.5, 1),
		UDim2.fromOffset(layout.ActionWidthPixels, config.TraversalWarnings.HeightPixels)
	)
	local root = cover.Parent :: Frame
	local warningRoot = warning.Parent :: Frame
	local icon = kit.icon(
		cover,
		"Eye",
		UDim2.fromOffset(layout.PaddingPixels, layout.PaddingPixels),
		layout.IconPixels,
		layout.TextColor
	)
	for _, viewport in
		{
			Vector2.new(1280, 720),
			Vector2.new(1600, 900),
			Vector2.new(1920, 1080),
			Vector2.new(2560, 1440),
			Vector2.new(3840, 2160),
			Vector2.new(3440, 1440),
		}
	do
		reference.Size = UDim2.fromOffset(viewport.X, viewport.Y)
		RunService.Heartbeat:Wait()
		RunService.Heartbeat:Wait()
		local factor = scale.factor(viewport)
		assert(math.abs(root.AbsoluteSize.X - layout.CoverWidthPixels * factor) < 1, "Wrong rendered panel width")
		assert(math.abs(icon.AbsoluteSize.X - layout.IconPixels * factor) < 1, "Icons did not scale with panel")
		local bottom = reference.AbsolutePosition.Y + viewport.Y
		assert(
			math.abs(bottom - root.AbsolutePosition.Y - root.AbsoluteSize.Y - layout.CoverBottomPixels * factor) < 1,
			"Bottom margin did not scale with panel"
		)
		assert(
			root.AbsolutePosition.Y - warningRoot.AbsolutePosition.Y - warningRoot.AbsoluteSize.Y
				>= layout.PaddingPixels * factor - 1,
			"Warning overlaps Cover panel"
		)
		print("HUD_SCALE_VIEWPORT_PASS", viewport, factor)
	end
	-- Updates are absolute, not cumulative; repeated resizing must not enlarge offsets again.
	reference.Size = UDim2.fromOffset(1280, 720)
	RunService.Heartbeat:Wait()
	RunService.Heartbeat:Wait()
	assert(root.Position.Y.Offset == -layout.CoverBottomPixels, "Repeated resize compounded margin")
	reference.Size = UDim2.fromOffset(1920, 1080)
	RunService.Heartbeat:Wait()
	root.Position = UDim2.new(0.5, 20, 1, -30)
	RunService.Heartbeat:Wait()
	RunService.Heartbeat:Wait()
	assert(root.Position.X.Offset == 30 and root.Position.Y.Offset == -45, "A repositioned panel did not rescale once")
	local camera = workspace.CurrentCamera
	assert(camera, "No Studio camera")
	local cameraPanel = kit.panel(
		gui,
		"CameraBound",
		UDim2.fromScale(0.5, 0.5),
		Vector2.new(0.5, 0.5),
		UDim2.fromOffset(layout.VitalsWidthPixels, layout.VitalsHeightPixels)
	)
	local cameraRoot = cameraPanel.Parent :: Frame
	cameraRoot.Visible = false
	RunService.Heartbeat:Wait()
	RunService.Heartbeat:Wait()
	assert(
		math.abs(cameraRoot.AbsoluteSize.X - layout.VitalsWidthPixels * scale.factor(camera.ViewportSize)) < 1,
		"Camera-bound HUD did not use the viewport"
	)
	cameraRoot:Destroy()
	root:Destroy()
	warningRoot:Destroy()
	reference.Size = UDim2.fromOffset(1920, 1080)
	RunService.Heartbeat:Wait()
	print(
		"HUD_SCALE_NATIVE_PASS",
		"six viewports, spacing, icons, repeat resize, reposition, camera binding and cleanup"
	)
end)
gui:Destroy()
clone:Destroy()
assert(ok, tostring(problem))
