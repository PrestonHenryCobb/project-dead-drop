--!strict
-- Ticket menu-phase0: the menu's shared components, so every screen (Claude Code's and Codex's) looks and behaves the
-- same. Colours, fonts and sizes come from GameConfig.Menu; sizes are pixels at the 1280 x 720 reference, and the menu's
-- root scales them with Util/HudScale. Decorative motion follows Roblox's Reduce Motion setting (Util/UiAccessibility).
--
--   local button = MenuTheme.primaryButton({ Name = "Deploy", Text = "DEPLOY", Parent = rail, OnActivated = deploy })
--   button.SetEnabled(false)
--   local panel = MenuTheme.infoPanel({ Name = "Briefing", Accent = "Brass", Parent = rail })
--   MenuTheme.stateChip("Locked", "LOCKED · LVL 6").Parent = card
--   MenuTheme.label({ Name = "Title", Text = "THE GALA", Style = "Title", Parent = panel })
--   MenuTheme.stack(panel)                      -- children top to bottom in LayoutOrder
--   local left = MenuTheme.rail(stage, "Left", "Left", 420)   -- a scrolling column down one side
--
-- Every interactive component shows hover, pressed, selected, disabled and a cyan controller/keyboard focus ring, and
-- states are always spelled out in text as well as colour. Connections belong to the instances they are made on, so
-- destroying a component (or its parent) cleans it up.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local UiAccessibility = require(Shared:WaitForChild("Util"):WaitForChild("UiAccessibility"))

local config = GameConfig.Menu
local colors = config.Colors

export type Accent = "Brass" | "Emerald" | "Focus"
export type ChipKind = "Equipped" | "Owned" | "Available" | "Locked" | "Active" | "Select"

export type ButtonProps = {
	Name: string,
	Text: string,
	Parent: Instance?,
	Size: UDim2?, -- defaults to full width at the component's standard height
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	OnActivated: (() -> ())?,
	Enabled: boolean?, -- default true
}

export type Button = {
	Instance: TextButton,
	SetEnabled: (enabled: boolean) -> (),
	SetSelected: (selected: boolean) -> (), -- the "chosen" look, for toggles such as SOLOS / DUOS
	SetText: (text: string) -> (),
}

export type PanelProps = {
	Name: string,
	Accent: Accent?, -- default Brass
	Parent: Instance?,
	Size: UDim2?, -- defaults to full width, height following its contents
	Position: UDim2?,
	LayoutOrder: number?,
}

local MenuTheme = {}

MenuTheme.Colors = colors
MenuTheme.Fonts = config.Fonts
MenuTheme.TextSizes = config.TextSizes

local hoverInfo = TweenInfo.new(config.HoverSeconds, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
MenuTheme.ScreenFadeInfo = TweenInfo.new(config.ScreenFadeSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
MenuTheme.CameraPanInfo = TweenInfo.new(config.CameraPanSeconds, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

local accentColors: { [Accent]: Color3 } = {
	Brass = colors.Brass,
	Emerald = colors.EmeraldBright,
	Focus = colors.Focus,
}

local chipStyles: { [ChipKind]: { Fill: Color3, FillTransparency: number, Stroke: Color3, Text: Color3, Label: string } } =
	{
		Equipped = {
			Fill = colors.EmeraldDeep,
			FillTransparency = 0,
			Stroke = colors.EmeraldBright,
			Text = colors.EmeraldBright,
			Label = "EQUIPPED",
		},
		Active = {
			Fill = colors.EmeraldDeep,
			FillTransparency = 0,
			Stroke = colors.EmeraldBright,
			Text = colors.EmeraldBright,
			Label = "ACTIVE",
		},
		Owned = {
			Fill = colors.Surface,
			FillTransparency = 0,
			Stroke = colors.Text,
			Text = colors.Text,
			Label = "OWNED",
		},
		Available = {
			Fill = colors.Surface,
			FillTransparency = 1,
			Stroke = colors.BrassBright,
			Text = colors.BrassBright,
			Label = "AVAILABLE",
		},
		Select = {
			Fill = colors.Surface,
			FillTransparency = 1,
			Stroke = colors.Brass,
			Text = colors.Brass,
			Label = "SELECT",
		},
		Locked = {
			Fill = colors.Burgundy,
			FillTransparency = 0,
			Stroke = colors.BurgundyBright,
			Text = colors.Text,
			Label = "LOCKED",
		},
	}

-- Roblox draws its own selection box unless SelectionImageObject is set; one empty frame turns that off for every
-- component, which then draws its own focus ring.
local noSelectionImage = Instance.new("Frame")
noSelectionImage.BackgroundTransparency = 1

local function setProperty(instance: Instance, goal: { [string]: any })
	if UiAccessibility.reducedMotion() then
		for key, value in goal do
			(instance :: any)[key] = value
		end
	else
		TweenService:Create(instance, hoverInfo, goal):Play()
	end
end

local function corner(parent: Instance)
	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(0, config.CornerPixels)
	uiCorner.Parent = parent
end

local function stroke(parent: Instance, color: Color3, thickness: number): UIStroke
	local uiStroke = Instance.new("UIStroke")
	uiStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	uiStroke.Color = color
	uiStroke.Thickness = thickness
	uiStroke.Parent = parent
	return uiStroke
end

-- The shared body of the two button styles.
type ButtonStyle = {
	Height: number,
	Fill: Color3,
	Stroke: Color3,
	StrokeHover: Color3,
	StrokeSelected: Color3,
	StrokeThickness: number,
	TextColor: Color3,
	TextSize: number,
}

local function makeButton(props: ButtonProps, style: ButtonStyle): Button
	local button = Instance.new("TextButton")
	button.Name = props.Name
	button.Text = props.Text
	button.Font = config.Fonts.Bold
	button.TextSize = style.TextSize
	button.TextColor3 = style.TextColor
	button.AutoButtonColor = false
	-- A flat fill: a UIGradient on a button would tint its own text as well.
	button.BackgroundColor3 = style.Fill
	button.BorderSizePixel = 0
	button.Size = props.Size or UDim2.new(1, 0, 0, style.Height)
	button.Position = props.Position or UDim2.new()
	button.AnchorPoint = props.AnchorPoint or Vector2.zero
	button.LayoutOrder = props.LayoutOrder or 0
	button.SelectionImageObject = noSelectionImage
	corner(button)
	local border = stroke(button, style.Stroke, style.StrokeThickness)

	local scale = Instance.new("UIScale")
	scale.Parent = button

	local ring = Instance.new("Frame")
	ring.Name = "FocusRing"
	ring.BackgroundTransparency = 1
	ring.Size = UDim2.new(1, config.FocusPixels * 4, 1, config.FocusPixels * 4)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Visible = false
	corner(ring)
	stroke(ring, colors.Focus, config.FocusPixels)
	ring.Parent = button

	local enabled = props.Enabled ~= false
	local selected = false
	local hovered = false

	local function restingStroke(): Color3
		if selected then
			return style.StrokeSelected
		end
		return if hovered and enabled then style.StrokeHover else style.Stroke
	end

	local function refresh()
		button.Active = enabled
		button.Selectable = enabled
		button.BackgroundTransparency = if enabled then 0 else config.DisabledTransparency
		button.TextTransparency = if enabled then 0 else config.DisabledTransparency
		border.Transparency = if enabled then 0 else config.DisabledTransparency
		setProperty(border, { Color = restingStroke() })
	end

	button.MouseEnter:Connect(function()
		hovered = true
		refresh()
	end)
	button.MouseLeave:Connect(function()
		hovered = false
		scale.Scale = 1
		refresh()
	end)
	button.MouseButton1Down:Connect(function()
		if enabled then
			scale.Scale = config.PressScale
		end
	end)
	button.MouseButton1Up:Connect(function()
		scale.Scale = 1
	end)
	button.SelectionGained:Connect(function()
		ring.Visible = true
	end)
	button.SelectionLost:Connect(function()
		ring.Visible = false
	end)
	button.Activated:Connect(function()
		if enabled and props.OnActivated then
			props.OnActivated()
		end
	end)

	refresh()
	button.Parent = props.Parent

	return {
		Instance = button,
		SetEnabled = function(value: boolean)
			enabled = value
			refresh()
		end,
		SetSelected = function(value: boolean)
			selected = value
			refresh()
		end,
		SetText = function(text: string)
			button.Text = text
		end,
	}
end

-- The 64-pixel emerald call to action (Deploy, Lock in, Equip). One per screen.
function MenuTheme.primaryButton(props: ButtonProps): Button
	return makeButton(props, {
		Height = config.PrimaryHeightPixels,
		Fill = colors.Emerald,
		Stroke = colors.EmeraldBright,
		StrokeHover = colors.Text,
		StrokeSelected = colors.Text,
		StrokeThickness = config.FocusPixels,
		TextColor = colors.Text,
		TextSize = config.TextSizes.Title,
	})
end

-- The 46-pixel slate button with brass trim, for every other action and for toggle cards.
function MenuTheme.secondaryButton(props: ButtonProps): Button
	return makeButton(props, {
		Height = config.SecondaryHeightPixels,
		Fill = colors.Slate,
		Stroke = colors.Brass,
		StrokeHover = colors.BrassBright,
		StrokeSelected = colors.EmeraldBright,
		StrokeThickness = config.TrimPixels,
		TextColor = colors.Text,
		TextSize = config.TextSizes.Button,
	})
end

-- A non-interactive panel with a thin border and an accent bar down its left edge. Put content inside it; it grows to
-- fit its contents unless a Size is given.
function MenuTheme.infoPanel(props: PanelProps): Frame
	local panel = Instance.new("Frame")
	panel.Name = props.Name
	panel.BackgroundColor3 = colors.InfoPanel
	panel.BackgroundTransparency = config.InfoPanelTransparency
	panel.BorderSizePixel = 0
	panel.Position = props.Position or UDim2.new()
	panel.LayoutOrder = props.LayoutOrder or 0
	if props.Size then
		panel.Size = props.Size
	else
		panel.Size = UDim2.fromScale(1, 0)
		panel.AutomaticSize = Enum.AutomaticSize.Y
	end
	corner(panel)
	stroke(panel, colors.Border, config.StrokePixels)

	-- The accent bar is a hard edge in the background gradient, not a child frame, so a layout the caller adds to the
	-- panel never treats it as a row. The edge is kept AccentBarPixels wide as the panel resizes.
	panel.BackgroundColor3 = Color3.new(1, 1, 1)
	local accent = accentColors[props.Accent or "Brass"]
	local fill = Instance.new("UIGradient")
	fill.Parent = panel
	local function fitBar()
		local width = math.max(panel.AbsoluteSize.X, config.AccentBarPixels * 2)
		local edge = math.clamp(config.AccentBarPixels / width, 0.001, 0.5)
		fill.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, accent),
			ColorSequenceKeypoint.new(edge, accent),
			ColorSequenceKeypoint.new(math.min(edge + 0.0005, 0.999), colors.InfoPanel),
			ColorSequenceKeypoint.new(1, colors.InfoPanel),
		})
	end
	panel:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitBar)
	fitBar()

	local padding = Instance.new("UIPadding")
	local pad = UDim.new(0, config.PaddingPixels)
	padding.PaddingTop = pad
	padding.PaddingBottom = pad
	padding.PaddingRight = pad
	padding.PaddingLeft = UDim.new(0, config.AccentBarPixels + config.PaddingPixels)
	padding.Parent = panel

	panel.Parent = props.Parent
	return panel
end

export type LabelProps = {
	Name: string,
	Text: string,
	Parent: Instance?,
	Style: ("Display" | "Title" | "Body" | "Small" | "Mono" | "Kicker")?, -- default Body
	Color: Color3?, -- default Text (TextDim for Small, Brass for Kicker)
	Size: UDim2?, -- defaults to full width, height following the text
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	Alignment: Enum.TextXAlignment?, -- default Left
}

local labelStyles = {
	Display = { Font = config.Fonts.Display, Size = config.TextSizes.Display, Color = colors.Text },
	Title = { Font = config.Fonts.Bold, Size = config.TextSizes.Title, Color = colors.Text },
	Body = { Font = config.Fonts.Body, Size = config.TextSizes.Body, Color = colors.Text },
	Small = { Font = config.Fonts.Body, Size = config.TextSizes.Small, Color = colors.TextDim },
	Mono = { Font = config.Fonts.Mono, Size = config.TextSizes.Body, Color = colors.Text },
	Kicker = { Font = config.Fonts.Mono, Size = config.TextSizes.Chip, Color = colors.Brass }, -- small caps line over a title
}

-- Text in one of the menu's styles. Wraps, and grows to fit unless a Size is given.
function MenuTheme.label(props: LabelProps): TextLabel
	local style = labelStyles[props.Style or "Body"]
	local text = Instance.new("TextLabel")
	text.Name = props.Name
	text.Text = props.Text
	text.Font = style.Font
	text.TextSize = style.Size
	text.TextColor3 = props.Color or style.Color
	text.TextWrapped = true
	text.TextXAlignment = props.Alignment or Enum.TextXAlignment.Left
	text.BackgroundTransparency = 1
	text.Position = props.Position or UDim2.new()
	text.AnchorPoint = props.AnchorPoint or Vector2.zero
	text.LayoutOrder = props.LayoutOrder or 0
	if props.Size then
		text.Size = props.Size
	else
		text.Size = UDim2.fromScale(1, 0)
		text.AutomaticSize = Enum.AutomaticSize.Y
	end
	text.Parent = props.Parent
	return text
end

-- Stacks a container's children top to bottom (or left to right) in LayoutOrder, GapPixels apart.
function MenuTheme.stack(container: GuiObject, horizontal: boolean?): UIListLayout
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, config.GapPixels)
	layout.Parent = container
	return layout
end

-- A scrolling column down one side of a screen (or the middle, with Side "Center" and a width), stacking its children.
-- Put content straight into the returned frame.
function MenuTheme.rail(parent: Instance, name: string, side: "Left" | "Right", width: number): ScrollingFrame
	local rail = Instance.new("ScrollingFrame")
	rail.Name = name
	rail.BackgroundTransparency = 1
	rail.BorderSizePixel = 0
	rail.ScrollBarThickness = config.StrokePixels * 3
	rail.ScrollBarImageColor3 = colors.Brass
	rail.CanvasSize = UDim2.new()
	rail.AutomaticCanvasSize = Enum.AutomaticSize.Y
	rail.ScrollingDirection = Enum.ScrollingDirection.Y
	rail.AnchorPoint = Vector2.new(if side == "Left" then 0 else 1, 0)
	rail.Position = if side == "Left"
		then UDim2.fromOffset(config.GapPixels * 2, config.GapPixels * 2)
		else UDim2.new(1, -config.GapPixels * 2, 0, config.GapPixels * 2)
	rail.Size = UDim2.new(0, width, 1, -config.GapPixels * 4)
	MenuTheme.stack(rail)
	local padding = Instance.new("UIPadding")
	padding.PaddingRight = UDim.new(0, config.StrokePixels * 4) -- room for the scroll bar
	padding.Parent = rail
	rail.Parent = parent
	return rail
end

-- A compact badge for an item's state. Label overrides the standard word, for example "LOCKED · LVL 6".
function MenuTheme.stateChip(kind: ChipKind, label: string?): Frame
	local style = chipStyles[kind]
	local chip = Instance.new("Frame")
	chip.Name = `{kind}Chip`
	chip.BackgroundColor3 = style.Fill
	chip.BackgroundTransparency = style.FillTransparency
	chip.BorderSizePixel = 0
	chip.Size = UDim2.fromOffset(0, config.ChipHeightPixels)
	chip.AutomaticSize = Enum.AutomaticSize.X
	corner(chip)
	stroke(chip, style.Stroke, config.StrokePixels)

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, config.ChipPaddingPixels)
	padding.PaddingRight = UDim.new(0, config.ChipPaddingPixels)
	padding.Parent = chip

	local text = Instance.new("TextLabel")
	text.Name = "Label"
	text.BackgroundTransparency = 1
	text.Font = config.Fonts.Mono
	text.TextSize = config.TextSizes.Chip
	text.TextColor3 = style.Text
	text.Text = label or style.Label
	text.Size = UDim2.fromScale(0, 1)
	text.AutomaticSize = Enum.AutomaticSize.X
	text.Parent = chip

	return chip
end

return table.freeze(MenuTheme)
