--!strict
-- Session preferences, using confirmed owner state. No optimistic Enabled value or guessed progress duration.
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)
local Janitor = require(Shared.Util.Janitor)
local MenuTheme = require(script.Parent.Parent.MenuTheme)
local AutoRecoverController = require(script.Parent.Parent.Parent.Controllers.AutoRecoverController)
local RemoteController = require(script.Parent.Parent.Parent.Controllers.RemoteController)
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
	local panel = MenuTheme.infoPanel({
		Name = "Settings",
		Parent = overlay,
		Size = UDim2.fromOffset(
			GameConfig.MatchHud.PanelWidthPixels,
			config.SecondaryHeightPixels * 4 + config.PaddingPixels * 3
		),
		Position = UDim2.fromScale(0.5, 0.5),
	})
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	MenuTheme.stack(panel).Padding = UDim.new(0, config.GapPixels)
	MenuTheme.label({ Name = "SettingsTitle", Text = "SETTINGS", Style = "Title", Parent = panel, LayoutOrder = 1 })
	MenuTheme.label({
		Name = "AutoRecoverDescription",
		Text = `Re-cover automatically when possible. {GameConfig.Controls.Disguise.Name} still re-covers immediately. Applies to this session.`,
		Style = "Small",
		Parent = panel,
		LayoutOrder = 2,
	})
	local function enabled(): boolean
		local info = AutoRecoverController.state()
		return if info then info.Enabled else GameConfig.Cover.AutoRecoverDefault
	end
	local toggle = MenuTheme.secondaryButton({
		Name = "AutoRecoverToggle",
		Text = "",
		Parent = panel,
		LayoutOrder = 3,
		OnActivated = function()
			RemoteController.fire("RequestAutoRecover", not enabled())
		end,
	})
	local function refresh()
		local on = enabled()
		toggle.SetText(`AUTO RE-COVER · {if on then "ON" else "OFF"}`)
		toggle.SetSelected(on)
	end
	refresh()
	cleanup:Add(RunService.Heartbeat:Connect(refresh))
	MenuTheme.secondaryButton({
		Name = "CloseSettings",
		Text = "CLOSE SETTINGS",
		Parent = panel,
		LayoutOrder = 4,
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
		end
	end)
	cleanup:Add(overlay.Destroying:Connect(function()
		if opened then
			SettingsPanel.close()
		end
	end))
	GuiService.SelectedObject = toggle.Instance
end

return SettingsPanel
