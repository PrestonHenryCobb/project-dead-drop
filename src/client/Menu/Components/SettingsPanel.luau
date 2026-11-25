--!strict
-- Session preferences, using confirmed owner state. No optimistic Enabled value or guessed progress duration.
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)
local InputHints = require(Shared.Util.InputHints)
local Janitor = require(Shared.Util.Janitor)
local MenuTheme = require(script.Parent.Parent.MenuTheme)
local MenuIcons = require(script.Parent.MenuIcons)
local AutoRecoverController = require(script.Parent.Parent.Parent.Controllers.AutoRecoverController)
local RemoteController = require(script.Parent.Parent.Parent.Controllers.RemoteController)
local SettingsController = require(script.Parent.Parent.Parent.Controllers.SettingsController)
local GraphicsController = require(script.Parent.Parent.Parent.Controllers.GraphicsController)
local HeldItemController = require(script.Parent.Parent.Parent.Controllers.HeldItemController)
local Accessibility = require(Shared.Util.UiAccessibility)
local SettingsPanel = {}
local cleanup = Janitor.new()
local opened = false
local config = GameConfig.Menu

function SettingsPanel.isOpen(): boolean
	return opened
end

function SettingsPanel.close()
	opened = false
	cleanup:Cleanup()
end

function SettingsPanel.open(parent: Frame)
	SettingsPanel.close()
	opened = true
	local previous = GuiService.SelectedObject
	local overlay = Instance.new("TextButton")
	overlay.Name = "SettingsOverlay"
	overlay.Text = ""
	overlay.AutoButtonColor = false
	overlay.BackgroundColor3 = MenuTheme.Colors.Canvas
	overlay.BackgroundTransparency = config.SurfaceTransparency
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.ZIndex = config.DisplayOrder
	overlay.Modal = true
	overlay.Selectable = false
	overlay.Parent = parent
	cleanup:Add(overlay)
	HeldItemController.setInterfaceBlocked(overlay, true)
	cleanup:Add(function()
		HeldItemController.setInterfaceBlocked(overlay, false)
	end)
	local panel = MenuTheme.infoPanel({
		Name = "Settings",
		Parent = overlay,
		Size = UDim2.fromScale(GameConfig.ClientSettings.PanelFraction, GameConfig.ClientSettings.PanelFraction),
		Position = UDim2.fromScale(0.5, 0.5),
	})
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	local bounds = Instance.new("UISizeConstraint")
	bounds.MaxSize = Vector2.new(GameConfig.MatchHud.PanelWidthPixels, GameConfig.UI.PanelScale.ReferenceHeightPixels)
	bounds.Parent = panel
	local titleHeight = config.TextSizes.Display + config.GapPixels
	MenuTheme.label({
		Name = "SettingsTitle",
		Text = "SETTINGS",
		Style = "Title",
		Parent = panel,
		Size = UDim2.new(1, 0, 0, titleHeight),
	})
	local body = Instance.new("ScrollingFrame")
	body.Name = "Preferences"
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.Position = UDim2.fromOffset(0, titleHeight)
	body.Size = UDim2.new(1, 0, 1, -titleHeight - config.SecondaryHeightPixels - config.GapPixels)
	body.CanvasSize = UDim2.new()
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.ScrollingDirection = Enum.ScrollingDirection.Y
	body.VerticalScrollBarInset = Enum.ScrollBarInset.Always
	body.ScrollBarThickness = config.Art.ScrollbarPixels
	body.ScrollBarImageColor3 = MenuTheme.Colors.Brass
	body.Parent = panel
	MenuTheme.stack(body)
	local sessionDescription = MenuTheme.label({
		Name = "SessionDescription",
		Text = "",
		Style = "Small",
		Parent = body,
		LayoutOrder = 1,
	})
	local function stepper(name: string, title: string, order: number, change: (number) -> ())
		local row = Instance.new("Frame")
		row.Name = name
		row.BackgroundTransparency = 1
		row.LayoutOrder = order
		row.Size = UDim2.new(1, 0, 0, config.ChipHeightPixels + config.SecondaryHeightPixels)
		row.Parent = body
		MenuTheme.label({
			Name = "Label",
			Text = title,
			Style = "Kicker",
			Parent = row,
			Size = UDim2.new(1, 0, 0, config.ChipHeightPixels),
		})
		local minus = MenuTheme.secondaryButton({
			Name = name .. "Decrease",
			Text = "−",
			Parent = row,
			Position = UDim2.fromOffset(0, config.ChipHeightPixels),
			Size = UDim2.new(0.2, -config.GapPixels / 2, 0, config.SecondaryHeightPixels),
			OnActivated = function()
				change(-1)
			end,
		})
		local value = MenuTheme.label({
			Name = "Value",
			Text = "",
			Style = "Mono",
			Parent = row,
			Position = UDim2.new(0.2, 0, 0, config.ChipHeightPixels),
			Size = UDim2.new(0.6, 0, 0, config.SecondaryHeightPixels),
			Alignment = Enum.TextXAlignment.Center,
		})
		local plus = MenuTheme.secondaryButton({
			Name = name .. "Increase",
			Text = "+",
			Parent = row,
			Position = UDim2.new(0.8, config.GapPixels / 2, 0, config.ChipHeightPixels),
			Size = UDim2.new(0.2, -config.GapPixels / 2, 0, config.SecondaryHeightPixels),
			OnActivated = function()
				change(1)
			end,
		})
		return function(text: string, canDecrease: boolean, canIncrease: boolean)
			value.Text = text
			minus.SetEnabled(canDecrease)
			plus.SetEnabled(canIncrease)
			if GuiService.SelectedObject == minus.Instance and not canDecrease then
				GuiService.SelectedObject = if canIncrease then plus.Instance else nil
			elseif GuiService.SelectedObject == plus.Instance and not canIncrease then
				GuiService.SelectedObject = if canDecrease then minus.Instance else nil
			end
		end
	end
	local fov = stepper("FieldOfView", "FIELD OF VIEW", 2, function(direction)
		SettingsController.setFov(SettingsController.get().Fov + direction * GameConfig.ClientSettings.FovStep)
	end)
	local sensitivity = stepper("Sensitivity", "MOUSE SENSITIVITY", 3, function(direction)
		SettingsController.setSensitivity(
			SettingsController.get().Sensitivity + direction * GameConfig.ClientSettings.SensitivityStep
		)
	end)
	local combatVolume = stepper("CombatVolume", "COMBAT EFFECTS VOLUME", 4, function(direction)
		SettingsController.setCombatVolume(
			SettingsController.get().CombatVolume + direction * GameConfig.ClientAudio.CombatVolumeStep
		)
	end)
	local motion = MenuTheme.secondaryButton({
		Name = "ReducedMotion",
		Text = "",
		Parent = body,
		LayoutOrder = 5,
		OnActivated = function()
			SettingsController.setReducedMotion(not SettingsController.get().ReducedMotion)
		end,
	})
	MenuTheme.label({
		Name = "MotionDescription",
		Text = "Extra reduced motion for HUD and menus.",
		Style = "Small",
		Parent = body,
		LayoutOrder = 6,
	})
	local modes: { GraphicsController.Mode } = { "Auto", "Low", "Medium", "High" }
	local graphics = MenuTheme.secondaryButton({
		Name = "GraphicsMode",
		Text = "",
		Parent = body,
		LayoutOrder = 7,
		OnActivated = function()
			local at = table.find(modes, GraphicsController.getMode()) or 1
			SettingsController.setGraphicsMode(modes[at % #modes + 1])
		end,
	})
	local recoverDescription = MenuTheme.label({
		Name = "AutoRecoverDescription",
		Text = "",
		Style = "Small",
		Parent = body,
		LayoutOrder = 8,
	})
	local function enabled(): boolean
		local info = AutoRecoverController.state()
		return if info then info.Enabled else GameConfig.Cover.AutoRecoverDefault
	end
	local toggle = MenuTheme.secondaryButton({
		Name = "AutoRecoverToggle",
		Text = "",
		Parent = body,
		LayoutOrder = 9,
		OnActivated = function()
			RemoteController.fire("RequestAutoRecover", not enabled())
		end,
	})
	local cameraShake = MenuTheme.secondaryButton({
		Name = "CameraShake",
		Text = "",
		Parent = body,
		LayoutOrder = 10,
		OnActivated = function()
			SettingsController.setCameraShake(not SettingsController.get().CameraShake)
		end,
	})
	MenuTheme.label({
		Name = "CameraShakeDescription",
		Text = "Light feedback when hurt or on takedowns.",
		Style = "Small",
		Parent = body,
		LayoutOrder = 11,
	})
	-- Owner 2026-11-25: settings in four plain groups (Aim, Performance, Audio, Espionage). The rows below are the new ones; the older rows above are given
	-- their place in a group by name further down.
	local function header(name: string, title: string)
		MenuTheme.label({ Name = name, Text = title, Style = "Title", Parent = body, LayoutOrder = 0 })
	end
	header("AimHeader", "AIM")
	header("PerformanceHeader", "PERFORMANCE")
	header("AudioHeader", "AUDIO")
	header("EspionageHeader", "ESPIONAGE")
	local updaters: { () -> () } = {}
	-- A button that flips one setting and shows it as "TITLE · ON / OFF".
	local function toggleRow(name: string, title: string, read: () -> boolean, write: (boolean) -> ())
		local button = MenuTheme.secondaryButton({
			Name = name,
			Text = "",
			Parent = body,
			LayoutOrder = 0,
			OnActivated = function()
				write(not read())
			end,
		})
		local last: boolean? = nil
		table.insert(updaters, function()
			local on = read()
			if on ~= last then
				last = on
				button.SetText(`{title} · {if on then "ON" else "OFF"}`)
				button.SetSelected(on)
			end
		end)
	end
	toggleRow("Shadows", "SHADOWS", GraphicsController.shadowsOn, SettingsController.setShadows)
	toggleRow("Bloom", "BLOOM", GraphicsController.bloomOn, SettingsController.setBloom)
	toggleRow("ShowFps", "FPS COUNTER", function()
		return SettingsController.get().ShowFps
	end, SettingsController.setShowFps)
	toggleRow("ExposedOutline", "EXPOSED AGENT OUTLINE", function()
		return SettingsController.get().ExposedOutline
	end, SettingsController.setExposedOutline)
	local worldVolume = stepper("WorldVolume", "AMBIENCE, FOOTSTEPS AND CUES VOLUME", 0, function(direction)
		SettingsController.setWorldVolume(
			SettingsController.get().WorldVolume + direction * GameConfig.ClientAudio.CombatVolumeStep
		)
	end)
	local lastWorld: number? = nil
	table.insert(updaters, function()
		local value = SettingsController.get().WorldVolume
		if value ~= lastWorld then
			lastWorld = value
			worldVolume(if value == 0 then "MUTED" else `{math.floor(value * 100 + 0.5)}%`, value > 0, value < 1)
		end
	end)
	local adsSensitivity = stepper("AdsSensitivity", "AIM DOWN SIGHTS SENSITIVITY", 0, function(direction)
		SettingsController.setAdsSensitivity(
			SettingsController.get().AdsSensitivity + direction * GameConfig.ClientSettings.AdsSensitivityStep
		)
	end)
	local lastAds: number? = nil
	table.insert(updaters, function()
		local value = SettingsController.get().AdsSensitivity
		if value ~= lastAds then
			lastAds = value
			adsSensitivity(
				string.format("%.2f×", value),
				value > GameConfig.ClientSettings.AdsSensitivityMin,
				value < GameConfig.ClientSettings.AdsSensitivityMax
			)
		end
	end)
	local crosshairScale = stepper("CrosshairScale", "CROSSHAIR SIZE", 0, function(direction)
		SettingsController.setCrosshairScale(
			SettingsController.get().CrosshairScale + direction * GameConfig.ClientSettings.CrosshairScaleStep
		)
	end)
	local lastCrosshair: number? = nil
	table.insert(updaters, function()
		local value = SettingsController.get().CrosshairScale
		if value ~= lastCrosshair then
			lastCrosshair = value
			crosshairScale(
				string.format("%.2f×", value),
				value > GameConfig.ClientSettings.CrosshairScaleMin,
				value < GameConfig.ClientSettings.CrosshairScaleMax
			)
		end
	end)
	-- Pictures beside the numbers (owner 2026-11-25): a level bar under each volume and sensitivity, a view wedge for the field of view, and quality
	-- bars on the graphics button.
	local visuals = GameConfig.ClientSettings.Visuals
	local function meter(rowName: string, fraction: () -> number)
		local row = body:FindFirstChild(rowName)
		if not (row and row:IsA("Frame")) then
			return
		end
		local track = Instance.new("Frame")
		track.Name = "Meter"
		track.BackgroundColor3 = MenuTheme.Colors.Border
		track.BorderSizePixel = 0
		track.Position = UDim2.new(
			0.2,
			config.GapPixels,
			0,
			config.ChipHeightPixels + config.SecondaryHeightPixels - visuals.MeterPixels
		)
		track.Size = UDim2.new(0.6, -config.GapPixels * 2, 0, visuals.MeterPixels)
		track.Parent = row
		local fill = Instance.new("Frame")
		fill.BackgroundColor3 = MenuTheme.Colors.BrassBright
		fill.BorderSizePixel = 0
		fill.Parent = track
		local last = -1
		table.insert(updaters, function()
			local value = math.clamp(fraction(), 0, 1)
			if value ~= last then
				last = value
				fill.Size = UDim2.fromScale(value, 1)
			end
		end)
	end
	meter("Sensitivity", function()
		local range = GameConfig.ClientSettings
		return (SettingsController.get().Sensitivity - range.SensitivityMin)
			/ (range.SensitivityMax - range.SensitivityMin)
	end)
	meter("CombatVolume", function()
		return SettingsController.get().CombatVolume
	end)
	meter("AdsSensitivity", function()
		local range = GameConfig.ClientSettings
		return (SettingsController.get().AdsSensitivity - range.AdsSensitivityMin)
			/ (range.AdsSensitivityMax - range.AdsSensitivityMin)
	end)
	meter("WorldVolume", function()
		return SettingsController.get().WorldVolume
	end)
	local fovRow = body:FindFirstChild("FieldOfView")
	if fovRow and fovRow:IsA("Frame") then
		-- Two lines from one point, opening as wide as the field of view.
		local wedge: { Frame } = {}
		for _ = 1, 2 do
			local line = Instance.new("Frame")
			line.Name = "WedgeLine"
			line.AnchorPoint = Vector2.new(0.5, 0.5)
			line.BackgroundColor3 = MenuTheme.Colors.BrassBright
			line.BorderSizePixel = 0
			line.Size = UDim2.fromOffset(visuals.WedgePixels, visuals.MeterPixels / 2)
			line.Parent = fovRow
			table.insert(wedge, line)
		end
		local lastFovShown = -1
		table.insert(updaters, function()
			local fovValue = SettingsController.get().Fov
			if fovValue == lastFovShown then
				return
			end
			lastFovShown = fovValue
			local half = math.rad(fovValue / 2)
			local baseY = config.ChipHeightPixels + config.SecondaryHeightPixels - config.GapPixels
			for index, line in wedge do
				local side = if index == 1 then -1 else 1
				local direction = Vector2.new(side * math.sin(half), -math.cos(half))
				local middle = direction * (visuals.WedgePixels / 2)
				line.Position = UDim2.new(0.2, config.GapPixels * 3 + middle.X, 0, baseY + middle.Y)
				line.Rotation = math.deg(math.atan2(direction.Y, direction.X))
			end
		end)
	end
	table.insert(
		updaters,
		(function()
			local bars: { Frame } = {}
			for index = 1, 3 do
				local bar = Instance.new("Frame")
				bar.Name = `Quality{index}`
				bar.BackgroundColor3 = MenuTheme.Colors.BrassBright
				bar.BorderSizePixel = 0
				bar.AnchorPoint = Vector2.new(0, 1)
				bar.Position = UDim2.new(
					0,
					config.GapPixels * 2 + (index - 1) * visuals.QualityBarPixels * 2,
					1,
					-config.GapPixels
				)
				bar.Size = UDim2.fromOffset(visuals.QualityBarPixels, visuals.QualityBarPixels * index)
				bar.Parent = graphics.Instance
				table.insert(bars, bar)
			end
			local lastMode = ""
			return function()
				local graphicsMode = GraphicsController.getMode()
				if graphicsMode == lastMode then
					return
				end
				lastMode = graphicsMode
				local level = if graphicsMode == "Low"
					then 1
					elseif graphicsMode == "Medium" then 2
					elseif graphicsMode == "High" then 3
					else 0
				for index, bar in bars do
					-- Auto shows every bar dim: it follows the Roblox quality slider.
					bar.BackgroundTransparency = if level == 0
						then visuals.DimTransparency
						elseif index <= level then 0
						else visuals.DimTransparency
				end
			end
		end)()
	)
	-- A colour choice: eight swatches, a hue slider and a preview card at the right (`makePreview` fills the card and returns a function that repaints it).
	local outline = GameConfig.ExposedOutline
	local function colorPicker(
		name: string,
		title: string,
		read: () -> Color3,
		write: (Color3) -> (),
		makePreview: (Frame) -> (Color3) -> (),
		shape: (() -> number)? -- another number the preview depends on (the crosshair size); the preview repaints when it changes
	)
		local colorRow = Instance.new("Frame")
		colorRow.Name = name
		colorRow.BackgroundTransparency = 1
		colorRow.Size =
			UDim2.new(1, 0, 0, config.ChipHeightPixels + config.SecondaryHeightPixels * 2 + config.GapPixels)
		colorRow.Parent = body
		local previewSize = visuals.PreviewPixels
		local controls = Instance.new("Frame")
		controls.Name = "Controls"
		controls.BackgroundTransparency = 1
		controls.Size = UDim2.new(1, -(previewSize + config.GapPixels), 1, 0)
		controls.Parent = colorRow
		local previewFrame = Instance.new("Frame")
		previewFrame.Name = "Preview"
		previewFrame.BackgroundTransparency = 1
		previewFrame.Position = UDim2.new(1, -previewSize, 0, config.ChipHeightPixels)
		previewFrame.Size = UDim2.fromOffset(previewSize, previewSize)
		previewFrame.Parent = colorRow
		local repaint = makePreview(previewFrame)
		MenuTheme.label({
			Name = "Label",
			Text = title,
			Style = "Kicker",
			Parent = colorRow,
			Size = UDim2.new(1, 0, 0, config.ChipHeightPixels),
		})
		local swatches: { { button: TextButton, color: Color3, stroke: UIStroke } } = {}
		for index, color in outline.Swatches do
			local swatch = Instance.new("TextButton")
			swatch.Name = `Swatch{index}`
			swatch.Text = ""
			swatch.AutoButtonColor = true
			swatch.BackgroundColor3 = color
			swatch.BorderSizePixel = 0
			local count = #outline.Swatches
			swatch.Position = UDim2.new((index - 1) / count, 0, 0, config.ChipHeightPixels)
			swatch.Size = UDim2.new(1 / count, -config.GapPixels / 2, 0, config.SecondaryHeightPixels)
			swatch.Parent = controls
			local ring = Instance.new("UIStroke")
			ring.Color = MenuTheme.Colors.Text
			ring.Thickness = config.FocusPixels
			ring.Enabled = false
			ring.Parent = swatch
			cleanup:Add(swatch.Activated:Connect(function()
				write(color)
			end))
			table.insert(swatches, { button = swatch, color = color, stroke = ring })
		end
		local hueBar = Instance.new("TextButton")
		hueBar.Name = "HueSlider"
		hueBar.Text = ""
		hueBar.AutoButtonColor = false
		hueBar.BackgroundColor3 = Color3.new(1, 1, 1)
		hueBar.BorderSizePixel = 0
		hueBar.Position = UDim2.fromOffset(0, config.ChipHeightPixels + config.SecondaryHeightPixels + config.GapPixels)
		hueBar.Size = UDim2.new(1, 0, 0, config.SecondaryHeightPixels)
		hueBar.Parent = controls
		local hueGradient = Instance.new("UIGradient")
		local hueKeys: { ColorSequenceKeypoint } = {}
		local hueSteps = 6
		for step = 0, hueSteps do
			table.insert(
				hueKeys,
				ColorSequenceKeypoint.new(
					step / hueSteps,
					Color3.fromHSV(step / hueSteps, outline.HueSaturation, outline.HueValue)
				)
			)
		end
		hueGradient.Color = ColorSequence.new(hueKeys)
		hueGradient.Parent = hueBar
		local handle = Instance.new("Frame")
		handle.Name = "Handle"
		handle.AnchorPoint = Vector2.new(0.5, 0.5)
		handle.BackgroundColor3 = MenuTheme.Colors.Text
		handle.BorderSizePixel = 0
		handle.Size = UDim2.new(0, config.TrimPixels * 3, 1, config.GapPixels)
		handle.Position = UDim2.fromScale(0, 0.5)
		handle.Parent = hueBar
		local dragging = false
		local function pickHue(x: number)
			local fraction = math.clamp((x - hueBar.AbsolutePosition.X) / math.max(1, hueBar.AbsoluteSize.X), 0, 1)
			write(Color3.fromHSV(fraction, outline.HueSaturation, outline.HueValue))
		end
		cleanup:Add(hueBar.InputBegan:Connect(function(input: InputObject)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				dragging = true
				pickHue(input.Position.X)
			end
		end))
		cleanup:Add(UserInputService.InputChanged:Connect(function(input: InputObject)
			if
				dragging
				and (
					input.UserInputType == Enum.UserInputType.MouseMovement
					or input.UserInputType == Enum.UserInputType.Touch
				)
			then
				pickHue(input.Position.X)
			end
		end))
		cleanup:Add(UserInputService.InputEnded:Connect(function(input: InputObject)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				dragging = false
			end
		end))
		local lastColor: Color3? = nil
		local lastShape = -1
		table.insert(updaters, function()
			local color = read()
			local currentShape = if shape then shape() else 0
			if color ~= lastColor or currentShape ~= lastShape then
				lastColor, lastShape = color, currentShape
				local hue = color:ToHSV()
				handle.Position = UDim2.fromScale(hue, 0.5)
				for _, entry in swatches do
					entry.stroke.Enabled = entry.color == color
				end
				repaint(color)
			end
		end)
	end
	colorPicker(
		"OutlineColor",
		"OUTLINE COLOUR",
		function()
			return SettingsController.get().ExposedOutlineColor
		end,
		SettingsController.setExposedOutlineColor,
		function(card)
			-- An agent's bust framed in the chosen colour.
			MenuIcons.portrait(card, "Guise", visuals.PreviewPixels, UDim2.new())
			local frame = Instance.new("UIStroke")
			frame.Thickness = visuals.PreviewOutlinePixels
			frame.Parent = card
			return function(color)
				frame.Color = color
			end
		end
	)
	colorPicker(
		"CrosshairColor",
		"CROSSHAIR COLOUR",
		function()
			return SettingsController.get().CrosshairColor
		end,
		SettingsController.setCrosshairColor,
		function(card)
			-- The four crosshair bars on a dark card, at the chosen colour and size.
			local backing = Instance.new("Frame")
			backing.BackgroundColor3 = MenuTheme.Colors.Canvas
			backing.BorderSizePixel = 0
			backing.Size = UDim2.fromScale(1, 1)
			backing.Parent = card
			local bars: { Frame } = {}
			for index = 1, 4 do
				local bar = Instance.new("Frame")
				bar.Name = `Bar{index}`
				bar.BorderSizePixel = 0
				bar.AnchorPoint = Vector2.new(0.5, 0.5)
				bar.Parent = backing
				table.insert(bars, bar)
			end
			local combatConfig = GameConfig.Combat.Feedback
			return function(color)
				local scale = SettingsController.get().CrosshairScale
				local length = combatConfig.CrosshairLengthPixels * scale * visuals.CrosshairPreviewZoom
				local gap = combatConfig.CrosshairGapPixels * scale * visuals.CrosshairPreviewZoom
				local thickness = math.max(1, math.floor(visuals.CrosshairPreviewThicknessPixels * scale + 0.5))
				for index, bar in bars do
					bar.BackgroundColor3 = color
					local horizontal = index <= 2
					local direction = if index % 2 == 1 then -1 else 1
					local along = direction * (gap + length / 2)
					bar.Size = if horizontal
						then UDim2.fromOffset(length, thickness)
						else UDim2.fromOffset(thickness, length)
					bar.Position = if horizontal then UDim2.new(0.5, along, 0.5, 0) else UDim2.new(0.5, 0, 0.5, along)
				end
			end
		end,
		function()
			return SettingsController.get().CrosshairScale
		end
	)
	for _, update in updaters do
		update()
	end
	cleanup:Add(RunService.Heartbeat:Connect(function()
		for _, update in updaters do
			update()
		end
	end))
	local lastFov, lastSensitivity = nil :: number?, nil :: number?
	local lastVolume: number? = nil
	local lastMotion, lastGraphics = "", ""
	local lastShake = ""
	local lastRecover: boolean? = nil
	local function refresh()
		local values = SettingsController.get()
		if values.Fov ~= lastFov then
			lastFov = values.Fov
			fov(`{values.Fov}°`, values.Fov > GameConfig.UI.FovMin, values.Fov < GameConfig.UI.FovMax)
		end
		if values.Sensitivity ~= lastSensitivity then
			lastSensitivity = values.Sensitivity
			sensitivity(
				string.format("%.2f×", values.Sensitivity),
				values.Sensitivity > GameConfig.ClientSettings.SensitivityMin,
				values.Sensitivity < GameConfig.ClientSettings.SensitivityMax
			)
		end
		local motionText = if values.ReducedMotion
			then "ON · SESSION"
			elseif Accessibility.reducedMotion() then "ON · ROBLOX"
			else "FOLLOW ROBLOX"
		if values.CombatVolume ~= lastVolume then
			lastVolume = values.CombatVolume
			combatVolume(
				if values.CombatVolume == 0 then "MUTED" else `{math.floor(values.CombatVolume * 100 + 0.5)}%`,
				values.CombatVolume > 0,
				values.CombatVolume < 1
			)
		end
		if motionText ~= lastMotion then
			lastMotion = motionText
			motion.SetText(`REDUCED MOTION · {motionText}`)
			motion.SetSelected(values.ReducedMotion)
		end
		local shakeText = if not values.CameraShake
			then "OFF"
			elseif Accessibility.reducedMotion() then "PAUSED BY REDUCED MOTION"
			else "ON"
		if shakeText ~= lastShake then
			lastShake = shakeText
			cameraShake.SetText(`CAMERA SHAKE · {shakeText}`)
			cameraShake.SetSelected(values.CameraShake)
		end
		local graphicsMode = GraphicsController.getMode()
		if graphicsMode ~= lastGraphics then
			lastGraphics = graphicsMode
			graphics.SetText(`GRAPHICS · {string.upper(graphicsMode)}`)
		end
		local on = enabled()
		if on ~= lastRecover then
			lastRecover = on
			toggle.SetText(`AUTO RE-COVER · {if on then "ON" else "OFF"}`)
			toggle.SetSelected(on)
		end
	end
	refresh()
	cleanup:Add(RunService.Heartbeat:Connect(refresh))
	MenuTheme.secondaryButton({
		Name = "ResetPreferences",
		Text = "RESET ALL SETTINGS",
		Parent = body,
		LayoutOrder = 12,
		OnActivated = function()
			SettingsController.reset()
		end,
	})
	MenuTheme.label({
		Name = "ControlsTitle",
		Text = "FIELD CONTROLS",
		Style = "Kicker",
		Parent = body,
		LayoutOrder = 13,
	})
	MenuTheme.label({
		Name = "StealthControls",
		Text = `STEALTH · Hold {GameConfig.Controls.Scan.Name} on a person to scan. {GameConfig.Controls.Disguise.Name} changes disguise. Hold {GameConfig.Controls.Blend.Name} for social emotes. {GameConfig.Controls.Sprint.Name} sprints; hold {GameConfig.Controls.Crouch.Name} to crouch.`,
		Style = "Small",
		Parent = body,
		LayoutOrder = 14,
	})
	MenuTheme.label({
		Name = "CombatControls",
		Text = `COMBAT · Left mouse fires, right mouse aims, {GameConfig.Controls.Reload.Name} reloads. Tap {GameConfig.Controls.Melee.Name} to strike, hold for a charged strike or a takedown from behind. Keys 1 / 2 / 3 select weapon / gadgets; fire deploys a held gadget, aim uses its alternate action.`,
		Style = "Small",
		Parent = body,
		LayoutOrder = 15,
	})
	MenuTheme.label({
		Name = "ObjectiveControls",
		Text = `OBJECTIVE · Hold {GameConfig.Controls.Interact.Name} on Intel and revealed vault terminals. Take the Package, call extraction and hold Interact in its open zone. {GameConfig.Controls.DropPackage.Name} drops the Package. Middle mouse pings your aim; Alt + middle mouse marks Danger.`,
		Style = "Small",
		Parent = body,
		LayoutOrder = 16,
	})
	MenuTheme.label({
		Name = "GamepadControls",
		Text = "", -- populated for the current device below
		Style = "Small",
		Parent = body,
		LayoutOrder = 17,
	})
	-- Only the controls of the device in use are listed (owner request 2026-11-20).
	local function showControls()
		local pad = InputHints.isGamepad()
		sessionDescription.Text = InputHints.text(
			`Session preferences. {InputHints.name(GameConfig.ClientSettings.Key)} opens settings during a match. Changes apply at once and are saved with your profile.`,
			`Saved with your profile. {InputHints.name(GameConfig.ClientSettings.PadKey)} opens settings during a match; B closes.`
		)
		recoverDescription.Text = `Re-cover automatically when possible. {InputHints.bracket(
			GameConfig.Controls.Disguise,
			GameConfig.Controls.DisguisePad,
			"re-covers immediately"
		)}. Applies to this session.`
		for _, name in { "StealthControls", "CombatControls", "ObjectiveControls" } do
			local label = body:FindFirstChild(name)
			if label and label:IsA("GuiObject") then
				label.Visible = not pad
			end
		end
		local padLabel = body:FindFirstChild("GamepadControls")
		if padLabel and padLabel:IsA("TextLabel") then
			padLabel.Visible = pad
			padLabel.Text = InputHints.text(
				"",
				`GAMEPAD · RT fire / LT aim · X interact or reload · Y ability · R3 melee · A jump · D-pad up scan / down disguise / left blend / right cycle equipment. {InputHints.name(
					GameConfig.Controls.DropPackagePad
				)} drops the Package. LT + D-pad right pings; LT + RB marks Danger. Flight: left stick move / right stick look / A-B height.`
			)
		end
	end
	showControls()
	cleanup:Add(InputHints.onChange(showControls))
	-- Where each row sits, group by group.
	local order = {
		SessionDescription = 1,
		AimHeader = 10,
		FieldOfView = 11,
		Sensitivity = 12,
		CameraShake = 13,
		CameraShakeDescription = 14,
		AdsSensitivity = 15,
		CrosshairScale = 16,
		CrosshairColor = 17,
		PerformanceHeader = 20,
		GraphicsMode = 21,
		Shadows = 22,
		Bloom = 23,
		ShowFps = 24,
		ReducedMotion = 25,
		MotionDescription = 26,
		AudioHeader = 30,
		CombatVolume = 31,
		WorldVolume = 32,
		EspionageHeader = 40,
		ExposedOutline = 41,
		OutlineColor = 42,
		AutoRecoverToggle = 44,
		AutoRecoverDescription = 45,
		ResetPreferences = 50,
		ControlsTitle = 60,
		StealthControls = 61,
		CombatControls = 62,
		ObjectiveControls = 63,
		GamepadControls = 64,
	}
	for name, place in order do
		local item = body:FindFirstChild(name)
		if item and item:IsA("GuiObject") then
			item.LayoutOrder = place
		end
	end
	MenuTheme.secondaryButton({
		Name = "CloseSettings",
		Text = "CLOSE SETTINGS",
		Parent = panel,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		OnActivated = SettingsPanel.close,
	})
	for _, child in overlay:GetDescendants() do
		if child:IsA("GuiObject") then
			child.ZIndex = config.DisplayOrder + 1
		end
	end
	cleanup:Add(function()
		if previous and previous.Parent then
			GuiService.SelectedObject = previous
		else
			GuiService.SelectedObject = nil
			-- A profile push can rebuild the menu underneath this modal, replacing its old selection.
			local screen = parent:FindFirstChild("Screen")
			if screen then
				for _, item in screen:GetDescendants() do
					if item:IsA("GuiButton") and item.Selectable and item.Visible then
						GuiService.SelectedObject = item
						break
					end
				end
			end
		end
	end)
	cleanup:Add(overlay.Destroying:Connect(function()
		if opened then
			SettingsPanel.close()
		end
	end))
	GuiService.SelectedObject = motion.Instance
end

return SettingsPanel
