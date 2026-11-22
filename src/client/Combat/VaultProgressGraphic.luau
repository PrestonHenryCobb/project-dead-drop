--!strict
-- Floating vault-door dials. Only revealed server snapshots can supply IDs, progress or completion.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)
local Types = require(Shared.Types)
local HudKit = require(Shared.Util.HudKit)
local HudTheme = require(Shared.Util.HudTheme)
local config = GameConfig.UI.VaultGraphic
local theme = HudTheme.get()
local VaultProgressGraphic = {}

export type View = { update: (Types.VaultTerminalInfo?) -> () }

local DOOR = {
	{ 0.15, 0.1, 0.85, 0.1 },
	{ 0.85, 0.1, 0.85, 0.9 },
	{ 0.85, 0.9, 0.15, 0.9 },
	{ 0.15, 0.9, 0.15, 0.1 },
	{ 0.25, 0.2, 0.75, 0.2 },
	{ 0.75, 0.2, 0.75, 0.8 },
	{ 0.75, 0.8, 0.25, 0.8 },
	{ 0.25, 0.8, 0.25, 0.2 },
	{ 0.5, 0.35, 0.5, 0.65 },
	{ 0.36, 0.42, 0.64, 0.58 },
	{ 0.36, 0.58, 0.64, 0.42 },
	{ 0.08, 0.25, 0.22, 0.25 },
	{ 0.08, 0.75, 0.22, 0.75 },
}
local CHECK = { { 0.2, 0.5, 0.4, 0.7 }, { 0.4, 0.7, 0.8, 0.28 } }

function VaultProgressGraphic.new(parent: Instance, index: number, count: number): View
	local root = Instance.new("Frame")
	root.Name = `VaultDial{index}`
	root.BackgroundTransparency = 1
	root.Position = UDim2.fromOffset((index - 1) * config.CellWidthPixels, 0)
	root.Size = UDim2.fromOffset(config.CellWidthPixels, config.HeightPixels)
	root.Visible = false
	root.Parent = parent
	if index < count then
		local connector = Instance.new("Frame")
		connector.Name = "VaultLink"
		connector.Position = UDim2.fromOffset((config.CellWidthPixels + config.DialPixels) / 2, config.DialPixels / 2)
		connector.Size = UDim2.fromOffset(config.CellWidthPixels - config.DialPixels, theme.StrokePixels)
		connector.BackgroundColor3 = theme.TextColor
		connector.BackgroundTransparency = config.ConnectorTransparency
		connector.BorderSizePixel = 0
		connector.Parent = root
	end
	local dial = Instance.new("Frame")
	dial.Name = "DoorProgress"
	dial.BackgroundTransparency = 1
	dial.Position = UDim2.fromOffset((config.CellWidthPixels - config.DialPixels) / 2, 0)
	dial.Size = UDim2.fromOffset(config.DialPixels, config.DialPixels)
	dial.Parent = root
	local ring = HudKit.ring(dial, "VaultTick", config.DialPixels)
	local inset = (config.DialPixels - config.IconPixels) / 2
	local door =
		HudKit.icon(dial, "VaultDoor", UDim2.fromOffset(inset, inset), config.IconPixels, theme.TextColor, DOOR)
	local check =
		HudKit.icon(dial, "VaultComplete", UDim2.fromOffset(inset, inset), config.IconPixels, theme.AccentColor, CHECK)
	check.Visible = false
	local function caption(name: string, y: number): TextLabel
		local label = HudKit.text(
			root,
			name,
			UDim2.fromOffset(0, y),
			Vector2.zero,
			UDim2.fromOffset(config.CellWidthPixels, theme.CaptionSize)
		)
		label.TextSize = theme.CaptionSize
		return label
	end
	local identity = caption("VaultId", config.DialPixels + theme.PaddingPixels / 2)
	local percent = caption("Percent", config.DialPixels + theme.PaddingPixels / 2 + theme.CaptionSize)
	local warning = caption("Contested", config.DialPixels + theme.PaddingPixels / 2 + theme.CaptionSize * 2)
	warning.Text = "CONTESTED"
	warning.TextColor3 = GameConfig.UI.WarningColor
	warning.BackgroundColor3 = theme.PanelColor
	warning.BackgroundTransparency = GameConfig.UI.FloatingHud.WarningTransparency
	warning.Visible = false
	return {
		update = function(terminal: Types.VaultTerminalInfo?)
			root.Visible = terminal ~= nil
			if not terminal then
				return
			end
			local color = if terminal.Contested
				then GameConfig.UI.WarningColor
				elseif terminal.Hacked then theme.AccentColor
				else theme.TextColor
			ring(terminal.Progress, color)
			identity.Text = `VAULT {terminal.VaultId}`
			percent.Text = `{math.floor(math.clamp(terminal.Progress, 0, 1) * 100)}%`
			percent.TextColor3 = color
			door.Visible = not terminal.Hacked
			check.Visible = terminal.Hacked
			warning.Visible = terminal.Contested and not terminal.Hacked
		end,
	}
end

return VaultProgressGraphic
