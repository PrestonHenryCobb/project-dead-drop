--!strict
-- Draws one themed loading screen (owner 2026-11-25). Client only; all words come from Defs/LoadingDefs, all numbers from GameConfig.Loading.
--
--   local screen = LoadingScreen.show("Boot")      builds it over everything and fades it in
--   screen.setProgress(0.4)                        a real fraction 0..1: the bar chases it and the status lines follow it
--   screen.setProgress(nil)                        no measurable progress: a sliding bar, status lines on a timer (the default)
--   screen.gui                                     the ScreenGui (TeleportService:SetTeleportGui carries it across a teleport)
--   screen.close()                                 fades out and removes it; screen.destroy() removes it at once
--
-- The look is a case file: dark ground, a gold hairline frame, a rubber stamp, a briefing with redaction bars that wipe in, a bar with a status line
-- under it, and a tip that changes now and then.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")

local GameConfig = require(script.Parent.Parent.GameConfig)
local LoadingDefs = require(script.Parent.Parent.Defs.LoadingDefs)
local HudTheme = require(script.Parent.HudTheme)
local Janitor = require(script.Parent.Janitor)

local config = GameConfig.Loading

export type LoadingScreen = {
	gui: ScreenGui,
	sceneId: string,
	setProgress: (fraction: number?) -> (),
	close: () -> (),
	destroy: () -> (),
}

local LoadingScreen = {}

local FRAME_INSET = 20 -- gap between the screen edge and the hairline frame
local COLUMN_PADDING = 14
local REDACTION_WIPE_SECONDS = 0.45
local REDACTION_STAGGER_SECONDS = 0.35
local REDACTION_HEIGHT_FRACTION = 0.9 -- bar height against the body text height
local SLIDER_WIDTH_FRACTION = 0.3 -- width of the sliding segment of an indeterminate bar
local SLIDER_SECONDS = 1.4 -- one pass of the sliding segment
local STAMP_ROTATION = -8
local STAMP_PADDING = 8
local STAMP_MARGIN = 64
local TIP_BOTTOM = 56
local RULE_THICKNESS = 1
local HAIRLINE_TRANSPARENCY = 0.55
local BAR_RESERVE = 0.02 -- an indeterminate bar never claims to be done; the last part of a real one belongs to the final handoff

local function label(
	parent: Instance,
	text: string,
	font: Enum.Font,
	size: number,
	color: Color3,
	order: number
): TextLabel
	local item = Instance.new("TextLabel")
	item.BackgroundTransparency = 1
	item.Font = font
	item.Text = text
	item.TextSize = size
	item.TextColor3 = color
	item.TextXAlignment = Enum.TextXAlignment.Left
	item.TextWrapped = true
	item.Size = UDim2.new(1, 0, 0, 0)
	item.AutomaticSize = Enum.AutomaticSize.Y
	item.LayoutOrder = order
	item.Parent = parent
	return item
end

-- "Plain [[hidden]] plain" -> { {text, false}, {text, true}, {text, false} }
local function segments(line: string): { { any } }
	local list: { { any } } = {}
	local position = 1
	while position <= #line do
		local open = string.find(line, "[[", position, true)
		if not open then
			table.insert(list, { string.sub(line, position), false })
			break
		end
		if open > position then
			table.insert(list, { string.sub(line, position, open - 1), false })
		end
		local close = string.find(line, "]]", open + 2, true)
		if not close then
			table.insert(list, { string.sub(line, open), false })
			break
		end
		table.insert(list, { string.sub(line, open + 2, close - 1), true })
		position = close + 2
	end
	return list
end

-- One briefing line: plain words and black bars laid out in a row. The bars wipe in one after another.
local function briefingLine(parent: Instance, line: string, order: number, delay: number, janitor: any)
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 0)
	row.AutomaticSize = Enum.AutomaticSize.Y
	row.LayoutOrder = order
	row.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Wraps = true
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = row
	local font = HudTheme.get().Font
	local height = config.BodySize + 4
	for index, part in segments(line) do
		local text: string, hidden: boolean = part[1], part[2]
		if hidden then
			local width = TextService:GetTextSize(text, config.BodySize, font, Vector2.new(10000, 100)).X
			local slot = Instance.new("Frame")
			slot.BackgroundTransparency = 1
			slot.Size = UDim2.fromOffset(width, height)
			slot.LayoutOrder = index * 1000
			slot.Parent = row
			local bar = Instance.new("Frame")
			bar.BackgroundColor3 = config.RedactionColor
			bar.BorderSizePixel = 0
			bar.AnchorPoint = Vector2.new(0, 0.5)
			bar.Position = UDim2.fromScale(0, 0.5)
			bar.Size = UDim2.new(0, 0, REDACTION_HEIGHT_FRACTION, 0)
			bar.Parent = slot
			local tween = TweenService:Create(
				bar,
				TweenInfo.new(REDACTION_WIPE_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, delay),
				{ Size = UDim2.new(1, 0, REDACTION_HEIGHT_FRACTION, 0) }
			)
			tween:Play()
			janitor:Add(function()
				tween:Cancel()
			end)
		else
			-- Words are split so a long line can wrap between them.
			local words = string.split(text, " ")
			for wordIndex, word in words do
				if word ~= "" then
					local item = Instance.new("TextLabel")
					item.BackgroundTransparency = 1
					item.Font = font
					item.Text = word .. " "
					item.TextSize = config.BodySize
					item.TextColor3 = config.InkColor
					item.TextXAlignment = Enum.TextXAlignment.Left
					item.AutomaticSize = Enum.AutomaticSize.X
					item.Size = UDim2.fromOffset(0, height)
					item.LayoutOrder = index * 1000 + wordIndex
					item.Parent = row
				end
			end
		end
	end
end

function LoadingScreen.show(sceneId: string): LoadingScreen
	local scene = LoadingDefs.scene(sceneId)
	local janitor = Janitor.new()
	local theme = HudTheme.get()

	local gui = Instance.new("ScreenGui")
	gui.Name = "LoadingScreen_" .. sceneId
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = config.DisplayOrder
	gui.ScreenInsets = Enum.ScreenInsets.None
	gui:SetAttribute("AlwaysVisible", true) -- the menu switches every other ScreenGui off; a loading screen must stay
	janitor:Add(gui)

	-- A CanvasGroup so the whole screen fades as one.
	local root = Instance.new("CanvasGroup")
	root.Name = "Root"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundColor3 = config.BackgroundColor
	root.BorderSizePixel = 0
	root.GroupTransparency = 1
	root.Parent = gui

	local frame = Instance.new("Frame")
	frame.Name = "Hairline"
	frame.BackgroundTransparency = 1
	frame.Position = UDim2.fromOffset(FRAME_INSET, FRAME_INSET)
	frame.Size = UDim2.new(1, -FRAME_INSET * 2, 1, -FRAME_INSET * 2)
	frame.Parent = root
	local stroke = Instance.new("UIStroke")
	stroke.Color = scene.Accent
	stroke.Transparency = HAIRLINE_TRANSPARENCY
	stroke.Thickness = 1
	stroke.Parent = frame

	local column = Instance.new("Frame")
	column.Name = "Column"
	column.AnchorPoint = Vector2.new(0.5, 0.5)
	column.Position = UDim2.fromScale(0.5, 0.46)
	column.Size = UDim2.fromOffset(config.PanelWidthPixels, 0)
	column.AutomaticSize = Enum.AutomaticSize.Y
	column.BackgroundTransparency = 1
	column.Parent = root
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, COLUMN_PADDING)
	list.Parent = column

	local kicker = label(column, scene.Kicker, Enum.Font.GothamBold, config.KickerSize, scene.Accent, 1)
	kicker.TextXAlignment = Enum.TextXAlignment.Left
	label(column, scene.Title, Enum.Font.Garamond, config.TitleSize, config.InkColor, 2)
	local rule = Instance.new("Frame")
	rule.BackgroundColor3 = scene.Accent
	rule.BackgroundTransparency = HAIRLINE_TRANSPARENCY
	rule.BorderSizePixel = 0
	rule.Size = UDim2.new(1, 0, 0, RULE_THICKNESS)
	rule.LayoutOrder = 3
	rule.Parent = column
	label(column, scene.Subtitle, theme.Font, config.SubtitleSize, config.DimInkColor, 4)

	local briefing = Instance.new("Frame")
	briefing.BackgroundTransparency = 1
	briefing.Size = UDim2.new(1, 0, 0, 0)
	briefing.AutomaticSize = Enum.AutomaticSize.Y
	briefing.LayoutOrder = 5
	briefing.Parent = column
	local briefingList = Instance.new("UIListLayout")
	briefingList.SortOrder = Enum.SortOrder.LayoutOrder
	briefingList.Padding = UDim.new(0, COLUMN_PADDING / 2)
	briefingList.Parent = briefing
	for index, line in scene.Briefing do
		briefingLine(briefing, line, index, config.FadeInSeconds + REDACTION_STAGGER_SECONDS * index, janitor)
	end

	-- Progress bar with the status line under it.
	local barBlock = Instance.new("Frame")
	barBlock.BackgroundTransparency = 1
	barBlock.Size = UDim2.new(1, 0, 0, config.BarHeightPixels + config.BodySize + COLUMN_PADDING)
	barBlock.LayoutOrder = 6
	barBlock.Parent = column
	local track = Instance.new("Frame")
	track.BackgroundColor3 = config.BarTrackColor
	track.BorderSizePixel = 0
	track.ClipsDescendants = true
	track.Size = UDim2.new(1, 0, 0, config.BarHeightPixels)
	track.Parent = barBlock
	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = scene.Accent
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0, 1)
	fill.Parent = track
	local status = Instance.new("TextLabel")
	status.BackgroundTransparency = 1
	status.Font = theme.Font
	status.TextSize = config.BodySize - 2
	status.TextColor3 = config.DimInkColor
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.Position = UDim2.fromOffset(0, config.BarHeightPixels + COLUMN_PADDING / 2)
	status.Size = UDim2.new(0.8, 0, 0, config.BodySize)
	status.Text = scene.Steps[1]
	status.Parent = barBlock
	local percent = Instance.new("TextLabel")
	percent.BackgroundTransparency = 1
	percent.Font = Enum.Font.GothamBold
	percent.TextSize = config.BodySize - 2
	percent.TextColor3 = scene.Accent
	percent.TextXAlignment = Enum.TextXAlignment.Right
	percent.AnchorPoint = Vector2.new(1, 0)
	percent.Position = UDim2.new(1, 0, 0, config.BarHeightPixels + COLUMN_PADDING / 2)
	percent.Size = UDim2.new(0.2, 0, 0, config.BodySize)
	percent.Text = ""
	percent.Parent = barBlock

	-- The stamp.
	local stamp = Instance.new("Frame")
	stamp.BackgroundTransparency = 1
	stamp.AnchorPoint = Vector2.new(1, 0)
	stamp.Position = UDim2.new(1, -STAMP_MARGIN, 0, STAMP_MARGIN)
	stamp.Size = UDim2.fromOffset(0, 0)
	stamp.AutomaticSize = Enum.AutomaticSize.XY
	stamp.Rotation = STAMP_ROTATION
	stamp.Parent = root
	local stampStroke = Instance.new("UIStroke")
	stampStroke.Color = scene.Accent
	stampStroke.Thickness = 2
	stampStroke.Transparency = 0.2
	stampStroke.Parent = stamp
	local stampPadding = Instance.new("UIPadding")
	stampPadding.PaddingLeft = UDim.new(0, STAMP_PADDING)
	stampPadding.PaddingRight = UDim.new(0, STAMP_PADDING)
	stampPadding.PaddingTop = UDim.new(0, STAMP_PADDING / 2)
	stampPadding.PaddingBottom = UDim.new(0, STAMP_PADDING / 2)
	stampPadding.Parent = stamp
	local stampText = Instance.new("TextLabel")
	stampText.BackgroundTransparency = 1
	stampText.Font = Enum.Font.GothamBlack
	stampText.Text = scene.Stamp
	stampText.TextSize = config.StampSize
	stampText.TextColor3 = scene.Accent
	stampText.AutomaticSize = Enum.AutomaticSize.XY
	stampText.Size = UDim2.fromOffset(0, 0)
	stampText.Parent = stamp

	-- The tip, near the bottom.
	local tipBlock = Instance.new("Frame")
	tipBlock.BackgroundTransparency = 1
	tipBlock.AnchorPoint = Vector2.new(0.5, 1)
	tipBlock.Position = UDim2.new(0.5, 0, 1, -TIP_BOTTOM)
	tipBlock.Size = UDim2.fromOffset(config.PanelWidthPixels, 0)
	tipBlock.AutomaticSize = Enum.AutomaticSize.Y
	tipBlock.Parent = root
	local tipList = Instance.new("UIListLayout")
	tipList.Padding = UDim.new(0, COLUMN_PADDING / 2)
	tipList.SortOrder = Enum.SortOrder.LayoutOrder
	tipList.Parent = tipBlock
	label(tipBlock, "FIELD NOTE", Enum.Font.GothamBold, config.KickerSize - 2, scene.Accent, 1)
	local tipText = label(tipBlock, "", theme.Font, config.TipSize, config.InkColor, 2)

	-- Behaviour ------------------------------------------------------------------------------------------------------------------------------
	local target: number? = nil
	local shown = 0
	local alive = true
	local startedAt = os.clock()
	local tipIndex = if #scene.Tips > 0 then math.random(1, #scene.Tips) else 0
	local tipChangedAt = startedAt
	local stepIndex = 1
	local stepChangedAt = startedAt
	local tipTween: Tween? = nil

	local function showTip(instant: boolean)
		if tipIndex == 0 then
			return
		end
		if instant then
			tipText.Text = scene.Tips[tipIndex]
			tipText.TextTransparency = 0
			return
		end
		local out = TweenService:Create(tipText, TweenInfo.new(config.TipFadeSeconds), { TextTransparency = 1 })
		tipTween = out
		out.Completed:Connect(function(state)
			if state ~= Enum.PlaybackState.Completed or not alive then
				return
			end
			tipText.Text = scene.Tips[tipIndex]
			local back = TweenService:Create(tipText, TweenInfo.new(config.TipFadeSeconds), { TextTransparency = 0 })
			tipTween = back
			back:Play()
		end)
		out:Play()
	end
	showTip(true)

	janitor:Add(RunService.RenderStepped:Connect(function(dt: number)
		local now = os.clock()
		-- Bar.
		local goal = target
		if goal then
			shown += (math.max(0, math.min(1, goal)) * (1 - BAR_RESERVE) - shown) * math.min(
				1,
				config.BarSettleSpeed * dt
			)
			fill.Position = UDim2.fromScale(0, 0)
			fill.Size = UDim2.fromScale(shown, 1)
			percent.Text = string.format("%d%%", math.floor(shown / (1 - BAR_RESERVE) * 100 + 0.5))
			stepIndex = math.clamp(math.floor(shown / (1 - BAR_RESERVE) * #scene.Steps) + 1, 1, #scene.Steps)
		else
			local phase = ((now - startedAt) % SLIDER_SECONDS) / SLIDER_SECONDS
			fill.Size = UDim2.fromScale(SLIDER_WIDTH_FRACTION, 1)
			fill.Position = UDim2.fromScale(-SLIDER_WIDTH_FRACTION + phase * (1 + SLIDER_WIDTH_FRACTION), 0)
			percent.Text = ""
			if now - stepChangedAt >= config.StepSeconds then
				stepChangedAt = now
				stepIndex = stepIndex % #scene.Steps + 1
			end
		end
		status.Text = scene.Steps[stepIndex] .. "…"
		-- Tip.
		if #scene.Tips > 1 and now - tipChangedAt >= config.TipSeconds then
			tipChangedAt = now
			tipIndex = tipIndex % #scene.Tips + 1
			showTip(false)
		end
	end))

	local fadeIn = TweenService:Create(root, TweenInfo.new(config.FadeInSeconds), { GroupTransparency = 0 })
	fadeIn:Play()
	janitor:Add(function()
		fadeIn:Cancel()
		if tipTween then
			tipTween:Cancel()
		end
	end)

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local self = {} :: LoadingScreen
	self.gui = gui
	self.sceneId = sceneId
	function self.setProgress(fraction: number?)
		target = fraction
	end
	function self.destroy()
		if alive then
			alive = false
			janitor:Destroy()
		end
	end
	function self.close()
		if not alive then
			return
		end
		alive = false
		target = 1
		local fade = TweenService:Create(root, TweenInfo.new(config.FadeOutSeconds), { GroupTransparency = 1 })
		fade.Completed:Once(function()
			janitor:Destroy()
		end)
		fade:Play()
	end
	return self
end

return LoadingScreen
