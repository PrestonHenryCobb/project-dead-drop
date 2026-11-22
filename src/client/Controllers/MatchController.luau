--!strict
-- Ticket 10b. Draws the server's phase, clocks, briefing and final roster; sends no gameplay requests.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)
local Types = require(Shared.Types)
local Janitor = require(Shared.Util.Janitor)
local HudKit = require(Shared.Util.HudKit)
local HudTheme = require(Shared.Util.HudTheme)
local InputHints = require(Shared.Util.InputHints)
local Accessibility = require(Shared.Util.UiAccessibility)
local Presentation = require(script.Parent.Parent.Combat.MatchPresentation)
local RewardsView = require(script.Parent.Parent.Combat.MatchRewardsView)
local RemoteController = require(script.Parent.RemoteController)
local HeldItemController = require(script.Parent.HeldItemController)
local MatchController = {}
local janitor = Janitor.new()
local scores = Janitor.new()
local state = Presentation.new()
local config = GameConfig.MatchHud
local theme = HudTheme.get()
local floating = GameConfig.UI.FloatingHud

local function label(parent: Instance, name: string, y: number, height: number, size: number): TextLabel
	local result = HudKit.text(
		parent,
		name,
		UDim2.fromOffset(config.PaddingPixels, y),
		Vector2.zero,
		UDim2.new(1, -config.PaddingPixels * 2, 0, height)
	)
	result.TextSize = size
	result.TextWrapped = true
	result.RichText = false
	return result
end

function MatchController.Init() end

function MatchController.Start()
	local gui = HudKit.screen("MatchHud")
	local ownTeamId: number? = nil
	gui.DisplayOrder = config.DisplayOrder
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	janitor:Add(gui)
	janitor:Add(scores)
	local blackout = Instance.new("Frame")
	blackout.Name = "InsertionFade"
	blackout.Size = UDim2.fromScale(1, 1)
	blackout.BackgroundColor3 = Color3.new(0, 0, 0)
	blackout.BorderSizePixel = 0
	blackout.Visible = false
	blackout.Parent = gui
	local brief = HudKit.panel(
		gui,
		"Briefing",
		UDim2.fromScale(0.5, 0.5),
		Vector2.new(0.5, 0.5),
		UDim2.fromOffset(config.PanelWidthPixels, config.BriefHeightPixels),
		true
	)
	local briefRoot = brief.Parent :: Frame
	briefRoot.ZIndex = 3
	briefRoot.Visible = false
	local briefTitle = label(brief, "Title", config.PaddingPixels, config.TitleSize * 2, config.TitleSize)
	briefTitle.Text = "MISSION BRIEFING"
	local briefInfo =
		label(brief, "Details", config.PaddingPixels + config.TitleSize * 2, config.BodySize * 2, config.BodySize)
	local objective = label(
		brief,
		"Objective",
		config.PaddingPixels + config.TitleSize * 2 + config.BodySize * 2,
		config.BodySize * 2,
		config.BodySize
	)
	objective.Text = "Gather Intel. Breach the Vault. Take the Package. Extract."
	local deployment = label(
		brief,
		"Countdown",
		config.BriefHeightPixels - config.PaddingPixels - config.BodySize,
		config.BodySize,
		config.BodySize
	)
	local timer = HudKit.panel(
		gui,
		"MatchClock",
		UDim2.new(0.5, 0, 0, config.TimerTopPixels),
		Vector2.new(0.5, 0),
		UDim2.fromOffset(floating.WatchPixels, floating.WatchPixels)
	)
	local caseCorner = timer:FindFirstChildOfClass("UICorner")
	if caseCorner then
		caseCorner.CornerRadius = UDim.new(0.5, 0)
	end
	for _, side in { -1, 1 } do
		local lug = Instance.new("Frame")
		lug.AnchorPoint = Vector2.new(0.5, 0.5)
		lug.Position = UDim2.new(0.5, 0, if side < 0 then 0 else 1, 0)
		lug.Size = UDim2.fromOffset(floating.WatchPixels / 4, floating.RingStrokePixels)
		lug.BorderSizePixel = 0
		lug.BackgroundColor3 = theme.TextColor
		lug.Parent = timer
	end
	local timerRoot = timer.Parent :: Frame
	timerRoot.Visible = false
	local clock = HudKit.text(
		timer,
		"Clock",
		UDim2.fromScale(0.5, 0.5),
		Vector2.new(0.5, 0.5),
		UDim2.new(1, -floating.RingInsetPixels * 4, 0, config.TitleSize)
	)
	clock.TextSize = config.BodySize
	local setRing = HudKit.ring(timer, "WatchTick", floating.WatchPixels)
	local deadline: number? = nil
	local duration = GameConfig.Match.MainTimerSeconds
	local waitPanel = HudKit.panel(
		gui,
		"LobbyWait",
		UDim2.new(0.5, 0, 1, -config.WaitBottomPixels),
		Vector2.new(0.5, 1),
		UDim2.fromOffset(config.PanelWidthPixels, config.WaitHeightPixels)
	)
	local waitRoot = waitPanel.Parent :: Frame
	waitRoot.Visible = false
	local waiting = label(waitPanel, "Waiting", 0, config.WaitHeightPixels, config.BodySize)
	local results = HudKit.panel(
		gui,
		"Results",
		UDim2.fromScale(0.5, 0.5),
		Vector2.new(0.5, 0.5),
		UDim2.fromOffset(config.PanelWidthPixels, config.ResultsHeightPixels),
		true
	)
	local resultsRoot = results.Parent :: Frame
	resultsRoot.ZIndex = 4
	resultsRoot.Visible = false
	local resultTitle = label(results, "Result", config.PaddingPixels, config.TitleSize * 2, config.TitleSize)
	local returnClock = label(
		results,
		"Return",
		config.ResultsHeightPixels - config.PaddingPixels - config.BodySize,
		config.BodySize,
		config.BodySize
	)
	local board = Instance.new("ScrollingFrame")
	board.Name = "Scoreboard"
	board.BackgroundTransparency = 1
	board.BorderSizePixel = 0
	local boardTop = config.PaddingPixels + config.TitleSize * 2
	board.Position = UDim2.fromOffset(config.PaddingPixels, boardTop)
	board.Size = UDim2.new(1, -config.PaddingPixels * 2, 1, -boardTop - config.PaddingPixels * 2 - config.BodySize)
	board.CanvasSize = UDim2.new()
	board.AutomaticCanvasSize = Enum.AutomaticSize.Y
	board.Active = true
	board.Selectable = true
	board.ScrollBarThickness = theme.ReloadBarPixels
	board.Parent = results
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = board
	local rewards = RewardsView.new(board)
	janitor:Add(rewards)
	local banner = HudKit.text(
		gui,
		"PhaseBanner",
		UDim2.fromScale(0.5, config.BannerTopFraction),
		Vector2.new(0.5, 0.5),
		UDim2.fromOffset(config.PanelWidthPixels, config.TitleSize * 3)
	)
	banner.TextSize = config.TitleSize
	banner.TextWrapped = true
	banner.RichText = false
	banner.ZIndex = 5
	banner.Visible = false

	local function onPhase(phase: Types.Phase, data: Types.PhaseData)
		state.apply(phase, data)
		deadline = if phase == "Overtime" then data.EndsAt else data.MainEndsAt
		duration = if phase == "Overtime" and data.EndsAt
			then math.max(data.EndsAt - data.StartedAt, 0.001)
			else GameConfig.Match.MainTimerSeconds
		gui.Enabled = true -- Lobby wait and Insertion must remain visible above the open menu.
		scores:Cleanup()
		board.CanvasPosition = Vector2.zero
		if phase ~= "Results" and GuiService.SelectedObject == board then
			GuiService.SelectedObject = nil
		end
		if phase == "Insertion" or phase == "Lobby" then
			rewards.clear()
		end
		if phase == "Insertion" and data.Brief then
			local info = data.Brief
			ownTeamId = info.TeamId
			local color = GameConfig.Lobby.TeamColors[info.TeamId]
			briefTitle.TextColor3 = if color then color.Color else theme.TextColor
			briefInfo.Text = `{string.upper(info.Mode)} · {info.Teams} TEAMS · {info.Players} PLAYERS`
		elseif phase == "Results" and data.Results then
			resultsRoot.Visible = true
			if InputHints.isGamepad() and not HeldItemController.isInputBlocked() then
				GuiService.SelectedObject = board
			end
			local info = data.Results
			resultTitle.Text = if info.WinnerTeamId and info.WinnerTeamId == ownTeamId
				then "MISSION SUCCESS"
				elseif info.WinnerTeamId and ownTeamId == nil then `TEAM {info.WinnerTeamId} WINS`
				else "MISSION FAILED"
			local order = 0
			local function row(text: string, color: Color3)
				order += 1
				local line = label(board, "ResultRow", 0, config.ScoreRowPixels, config.BodySize)
				line.Size = UDim2.new(1, -config.PaddingPixels, 0, config.ScoreRowPixels)
				line.Text = text
				line.TextWrapped = false
				line.TextTruncate = Enum.TextTruncate.AtEnd
				line.TextXAlignment = Enum.TextXAlignment.Left
				line.TextColor3 = color
				line.LayoutOrder = order
				scores:Add(line)
			end
			for _, team in info.Teams do
				local color = GameConfig.Lobby.TeamColors[team.TeamId]
				row(
					`TEAM {team.TeamId}{if team.Won then " · EXTRACTED" else ""}`,
					if color then color.Color else theme.TextColor
				)
				for _, member in team.Members do
					row(
						`{member.DisplayName} · {member.AgentId or "—"} · {if member.Out
							then "ELIMINATED"
							else "SURVIVED"}`,
						theme.TextColor
					)
				end
			end
		end
	end
	janitor:Add(RemoteController.connect("PhaseChanged", onPhase))
	-- Reward settlement can precede Results on its own remote; keep it until the phase exposes the results panel.
	janitor:Add(RemoteController.connect("MatchRewards", rewards.show))
	janitor:Add(RunService.RenderStepped:Connect(function()
		local view = state.view(workspace:GetServerTimeNow())
		if not view then
			return
		end
		blackout.Visible = view.insertion
		blackout.BackgroundTransparency = if Accessibility.reducedMotion() then 0 else view.fade
		briefRoot.Visible = view.brief ~= nil
		deployment.Text = `INSERTION · {view.phaseTimer}`
		banner.Visible = view.banner ~= nil
		banner.Text = view.banner or ""
		timerRoot.Visible = view.mainTimer ~= nil
		clock.Text = view.mainTimer or ""
		local remaining = if deadline then math.max(0, deadline - workspace:GetServerTimeNow()) else 0
		local urgent = view.phase == "Overtime" or (deadline ~= nil and remaining <= GameConfig.UI.TimerWarningSeconds)
		clock.TextColor3 = if urgent then GameConfig.UI.WarningColor else theme.TextColor
		setRing(remaining / duration, clock.TextColor3)
		timer.BackgroundTransparency = if urgent then floating.WarningTransparency else 1
		waitRoot.Visible = view.ready ~= nil
		waiting.Text = if view.ready then `WAITING FOR PLAYERS · {view.ready} READY · FILL {view.phaseTimer}` else ""
		resultsRoot.Visible = view.results ~= nil
		returnClock.Text = `RETURNING TO LOBBY · {view.phaseTimer}`
	end))
	janitor:Add(script.Destroying:Connect(function()
		janitor:Destroy()
	end))
end

return MatchController
