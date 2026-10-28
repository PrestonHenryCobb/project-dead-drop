--!strict
-- Shared top-of-screen regions for the existing HUD. Center is reserved for the clock, phase and vault panels.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)
local HudTheme = require(Shared.Util.HudTheme)
local HudLayout = {}

export type Region = { Edge: "Left" | "Center" | "Right", Offset: number, Top: number, Width: number, Height: number }

function HudLayout.regions(graphics: HudTheme.Theme): { [string]: Region }
	local margin, gap = graphics.MarginPixels, graphics.PaddingPixels
	local height = graphics.CoverHeightPixels
	local noticesTop = margin + (height + gap) * 2
	local match = GameConfig.MatchHud
	return {
		Alarm = { Edge = "Left", Offset = margin, Top = margin, Width = graphics.VitalsWidthPixels, Height = height },
		Intel = {
			Edge = "Left",
			Offset = margin,
			Top = margin + height + gap,
			Width = graphics.CoverWidthPixels,
			Height = height,
		},
		Toast = {
			Edge = "Left",
			Offset = margin,
			Top = noticesTop,
			Width = graphics.CoverWidthPixels,
			Height = gap * 3,
		},
		Package = { Edge = "Right", Offset = margin, Top = margin, Width = graphics.CoverWidthPixels, Height = height },
		Extraction = {
			Edge = "Right",
			Offset = margin,
			Top = margin + height + gap,
			Width = graphics.CoverWidthPixels,
			Height = height,
		},
		Exposure = {
			Edge = "Right",
			Offset = margin,
			Top = noticesTop,
			Width = GameConfig.UI.CoverBreak.BannerWidthPixels,
			Height = GameConfig.UI.CoverBreak.BannerHeightPixels,
		},
		Warning = {
			Edge = "Right",
			Offset = margin,
			Top = noticesTop + GameConfig.UI.CoverBreak.BannerHeightPixels + gap,
			Width = graphics.ActionWidthPixels,
			Height = gap * 3,
		},
		Clock = {
			Edge = "Center",
			Offset = 0,
			Top = match.TimerTopPixels,
			Width = match.TimerWidthPixels,
			Height = match.TimerHeightPixels,
		},
		Vault = {
			Edge = "Center",
			Offset = 0,
			Top = match.TimerTopPixels + match.TimerHeightPixels + match.PaddingPixels,
			Width = match.PanelWidthPixels,
			Height = GameConfig.Vault.ActiveVaults * (match.BodySize + match.PaddingPixels) + match.PaddingPixels,
		},
	}
end

function HudLayout.position(region: Region): UDim2
	local along = if region.Edge == "Left" then 0 elseif region.Edge == "Right" then 1 else 0.5
	return UDim2.new(along, if region.Edge == "Right" then -region.Offset else region.Offset, 0, region.Top)
end

function HudLayout.anchor(region: Region): Vector2
	return Vector2.new(if region.Edge == "Left" then 0 elseif region.Edge == "Right" then 1 else 0.5, 0)
end

return HudLayout
