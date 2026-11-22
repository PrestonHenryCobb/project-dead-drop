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
local Badge = require(script.Parent.VaultBadge)
local VaultProgressGraphic = {}

export type View = { update: (Types.VaultTerminalInfo?) -> () }

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
	local ring = HudKit.ring(dial, "VaultProgress", config.DialPixels)
	local badge = Badge.new(dial, config.IconPixels)
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
			identity.Text = if terminal.Hacked then "✓" else ""
			identity.TextColor3 = color
			badge.update(terminal.VaultId, color)
			percent.Text = `{math.floor(math.clamp(terminal.Progress, 0, 1) * 100)}%`
			percent.TextColor3 = color
			warning.Visible = terminal.Contested and not terminal.Hacked
		end,
	}
end

return VaultProgressGraphic
