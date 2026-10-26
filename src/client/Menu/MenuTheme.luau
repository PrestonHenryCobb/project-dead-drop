--!strict
-- Ticket menu-phase0: the menu's shared components, so every screen (Claude Code's and Codex's) looks and behaves the
-- same. Colours, fonts and sizes come from GameConfig.Menu; sizes are pixels at the 1280 x 720 reference, and the menu's
-- root scales them with Util/HudScale. Decorative motion follows Roblox's Reduce Motion setting (Util/UiAccessibility).
--
--   local button = MenuTheme.primaryButton({ Name = "Deploy", Text = "DEPLOY", Parent = rail, OnActivated = deploy })
--   button.SetEnabled(false)
--   local panel = MenuTheme.infoPanel({ Name = "Briefing", Accent = "Brass", Parent = rail })
--   MenuTheme.stateChip("Locked", "LOCKED · LVL 6").Parent = card
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

local function gradient(parent: Instance, top: Color3, bottom: Color3)
	local uiGradient = Instance.new("UIGradient")
	uiGradient.Color = ColorSequence.new(top, bottom)
	uiGradient.Rotation = 90
	uiGradient.Parent = parent
end

-- The shared body of the two button styles.
type ButtonStyle = {
	Height: number,
	Top: Color3,
	Bottom: Color3,
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
	button.BackgroundColor3 = Color3.new(1, 1, 1) -- the gradient supplies the colour
	button.BorderSizePixel = 0
	button.Size = props.Size or UDim2.new(1, 0, 0, style.Height)
	button.Position = props.Position or UDim2.new()
	button.AnchorPoint = props.AnchorPoint or Vector2.zero
	button.LayoutOrder = props.LayoutOrder or 0
	button.SelectionImageObject = noSelectionImage
	corner(button)
	gradient(button, style.Top, style.Bottom)
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
		Top = colors.EmeraldGradientTop,
		Bottom = colors.EmeraldGradientBottom,
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
		Top = colors.SlateGradientTop,
		Bottom = colors.SlateGradientBottom,
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

	local bar = Instance.new("Frame")
	bar.Name = "AccentBar"
	bar.BackgroundColor3 = accentColors[props.Accent or "Brass"]
	bar.BorderSizePixel = 0
	bar.Parent = panel

	local padding = Instance.new("UIPadding")
	local pad = UDim.new(0, config.PaddingPixels)
	padding.PaddingTop = pad
	padding.PaddingBottom = pad
	padding.PaddingRight = pad
	padding.PaddingLeft = UDim.new(0, config.AccentBarPixels + config.PaddingPixels)
	padding.Parent = panel
	-- The bar ignores padding by sitting at a negative offset.
	bar.Position = UDim2.new(0, -(config.AccentBarPixels + config.PaddingPixels), 0, -config.PaddingPixels)
	bar.Size = UDim2.new(0, config.AccentBarPixels, 1, config.PaddingPixels * 2)

	panel.Parent = props.Parent
	return panel
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
