--!strict
-- Session preferences, using confirmed owner state. No optimistic Enabled value or guessed progress duration.
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)
local InputHints = require(Shared.Util.InputHints)
local Janitor = require(Shared.Util.Janitor)
local MenuTheme = require(script.Parent.Parent.MenuTheme)
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
			GraphicsController.setMode(modes[at % #modes + 1])
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
		Text = "RESET CAMERA + COMBAT AUDIO",
		Parent = body,
		LayoutOrder = 12,
		OnActivated = SettingsController.reset,
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
			`Session preferences. {InputHints.name(GameConfig.ClientSettings.Key)} opens settings during a match. Changes take effect immediately.`,
			"Applies immediately. B closes."
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
