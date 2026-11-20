--!strict
-- Owner-only server settlement presentation. No award calculation, profile mutation or gameplay requests.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)
local Types = require(Shared.Types)
local Janitor = require(Shared.Util.Janitor)
local HudKit = require(Shared.Util.HudKit)
local HudTheme = require(Shared.Util.HudTheme)
local MatchRewardsView = {}
local config = GameConfig.MatchHud
local theme = HudTheme.get()
local names: { [string]: string } = {
	MatchPlayed = "MATCH COMPLETED",
	IntelCollected = "INTEL STATIONS",
	VaultParticipation = "VAULT PARTICIPATION",
	PackagePickedUp = "PACKAGE PICKUP",
	PackageCarried = "PACKAGE CARRIED",
	EnemyDowned = "RIVALS DOWNED",
	EnemyEliminated = "RIVALS ELIMINATED",
	TeammateRevived = "TEAMMATES REVIVED",
	TeammateRescued = "TEAMMATES RESCUED",
	ExtractionWin = "EXTRACTION WIN",
	SurvivedToEnd = "SURVIVED TO THE END",
}

function MatchRewardsView.new(parent: Instance)
	local janitor = Janitor.new()
	local content = Janitor.new()
	local root = Instance.new("Frame")
	root.Name = "OwnMatchRewards"
	root.BackgroundTransparency = 1
	root.Size = UDim2.new(1, 0, 0, 0)
	root.AutomaticSize = Enum.AutomaticSize.Y
	root.LayoutOrder = 0
	root.Visible = false
	root.Parent = parent
	janitor:Add(root)
	janitor:Add(content)
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, theme.PaddingPixels / 2)
	layout.Parent = root
	local function clear()
		content:Cleanup()
		root.Visible = false
	end
	local function show(info: Types.MatchRewardsInfo)
		clear()
		local order = 0
		local function row(name: string, value: string, accent: boolean?)
			order += 1
			local text = HudKit.text(
				root,
				name,
				UDim2.new(),
				Vector2.zero,
				UDim2.new(1, -config.PaddingPixels, 0, config.ScoreRowPixels)
			)
			text.LayoutOrder = order
			text.Text = value
			text.TextSize = config.BodySize
			text.TextXAlignment = Enum.TextXAlignment.Left
			text.TextColor3 = if accent then theme.AccentColor else theme.TextColor
			text.RichText = false
			content:Add(text)
		end
		local credits = info.LevelCredits + info.WinCredits + info.DailyCredits
		row("RewardsTotal", `MATCH REWARDS · +{info.TotalXp} XP · +{credits} CREDITS`, true)
		row(
			"AccountLevel",
			`LEVEL {info.LevelAfter}{if info.LevelAfter > info.LevelBefore then ` · UP FROM {info.LevelBefore}` else ""} · {info.XpIntoLevel} / {info.XpForLevel} XP`
		)
		order += 1
		local bar = Instance.new("Frame")
		bar.Name = "AccountXpProgress"
		bar.BackgroundColor3 = theme.BorderColor
		bar.BorderSizePixel = 0
		bar.Size = UDim2.new(1, -config.PaddingPixels, 0, theme.ReloadBarPixels)
		bar.LayoutOrder = order
		bar.Parent = root
		content:Add(bar)
		local fill = Instance.new("Frame")
		fill.Name = "ConfirmedXp"
		fill.BackgroundColor3 = theme.AccentColor
		fill.BorderSizePixel = 0
		fill.Size =
			UDim2.fromScale(if info.XpForLevel > 0 then math.clamp(info.XpIntoLevel / info.XpForLevel, 0, 1) else 0, 1)
		fill.Parent = bar
		-- Preserve the server's earned order, including repeated station/carry awards.
		for index, line in info.Lines do
			row(`XpAward{index}`, `{names[line.Event] or line.Event} · +{line.Xp} XP`)
		end
		if info.LevelCredits > 0 then
			row("LevelCredits", `LEVEL-UP · +{info.LevelCredits} CREDITS`)
		end
		if info.WinCredits > 0 then
			row("WinCredits", `WIN BONUS · +{info.WinCredits} CREDITS`)
		end
		if info.DailyCredits > 0 then
			row("DailyCredits", `FIRST WIN TODAY · +{info.DailyCredits} CREDITS`)
		end
		row("RosterHeading", "FINAL ROSTER", true)
		root.Visible = true
	end
	return {
		show = show,
		clear = clear,
		Destroy = function()
			janitor:Destroy()
		end,
	}
end

return MatchRewardsView
