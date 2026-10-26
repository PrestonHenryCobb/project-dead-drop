--!strict
-- Original native line-work: fan vault, intaglio treasury seal and operation folio.
-- Authored normalized geometry, not an image placeholder or an unpublished reward.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local config = require(ReplicatedStorage.Shared.GameConfig).Menu
local colors = config.Colors
local Art = {}

local function shape(
	parent: Instance,
	name: string,
	x: number,
	y: number,
	w: number,
	h: number,
	color: Color3,
	angle: number?
): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(x, y)
	frame.Size = UDim2.fromScale(w, h)
	frame.BackgroundColor3 = color
	frame.BorderSizePixel = 0
	frame.Rotation = angle or 0
	frame.Parent = parent
	return frame
end
local function outline(parent: Instance, color: Color3, width: number)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = width
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end
local function circle(parent: Instance, x: number, y: number, size: number, color: Color3, filled: boolean): Frame
	local frame = shape(parent, "EngravedCircle", x, y, size, size, color)
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1
	aspect.Parent = frame
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = frame
	if not filled then
		frame.BackgroundTransparency = 1
		outline(frame, color, config.TrimPixels)
	end
	return frame
end
function Art.trim(parent: GuiObject)
	-- Each corner is an original stepped brass key; no per-frame work or external assets.
	for _, x in { 0, 1 } do
		for _, y in { 0, 1 } do
			local corner = Instance.new("Frame")
			corner.Name = "DecoCorner"
			corner.BackgroundTransparency = 1
			corner.AnchorPoint = Vector2.new(x, y)
			corner.Position = UDim2.fromScale(x, y)
			corner.Size = UDim2.fromOffset(24, 24)
			corner.Parent = parent
			local h =
				shape(corner, "Key", if x == 0 then 0.6 else 0.4, if y == 0 then 0.2 else 0.8, 0.8, 0.05, colors.Brass)
			h.BackgroundTransparency = 0.15
			shape(corner, "Key", if x == 0 then 0.2 else 0.8, if y == 0 then 0.6 else 0.4, 0.05, 0.8, colors.Brass)
		end
	end
end
function Art.insignia(parent: Instance, kind: string, color: Color3?)
	local ink = color or colors.BrassBright
	local canvas = shape(parent, "Insignia", 0.5, 0.5, 1, 1, colors.Canvas)
	canvas.BackgroundTransparency = 1
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1
	aspect.Parent = canvas
	if kind == "Mint" then
		circle(canvas, 0.5, 0.5, 0.84, ink, false)
		circle(canvas, 0.5, 0.5, 0.7, ink, false)
		for i = 0, 23 do
			local angle = math.rad(i * 15)
			shape(
				canvas,
				"IntaglioTick",
				0.5 + math.sin(angle) * 0.38,
				0.5 + math.cos(angle) * 0.38,
				0.012,
				0.035,
				ink,
				-i * 15
			)
		end
		for i = -2, 2 do
			shape(canvas, "CertificateBar", 0.5 + i * 0.065, 0.5, 0.035, 0.36 - math.abs(i) * 0.07, ink)
		end
		shape(canvas, "TreasuryBase", 0.5, 0.72, 0.4, 0.025, ink)
	elseif kind == "Archive" then
		local folio = shape(canvas, "Folio", 0.5, 0.5, 0.56, 0.72, colors.Text)
		outline(folio, ink, config.TrimPixels)
		for i = 1, 5 do
			shape(folio, "LedgerRule", 0.5, 0.25 + i * 0.09, 0.7, 0.012, colors.Walnut)
		end
		local seal = circle(canvas, 0.66, 0.68, 0.28, colors.Burgundy, true)
		shape(seal, "SealDiamond", 0.5, 0.5, 0.32, 0.32, ink, 45)
	elseif kind == "Market" then
		local box = shape(canvas, "PresentationCase", 0.5, 0.6, 0.72, 0.38, colors.EmeraldDeep)
		outline(box, ink, config.FocusPixels)
		shape(canvas, "CaseLid", 0.5, 0.36, 0.72, 0.1, ink, -9)
		shape(canvas, "Latch", 0.5, 0.58, 0.08, 0.12, ink)
		for i = -2, 2 do
			shape(canvas, "Rays", 0.5 + i * 0.1, 0.2 + math.abs(i) * 0.025, 0.018, 0.14, ink, i * 18)
		end
	else
		-- Credential / asset emblem: shield and the fan-window motif.
		shape(canvas, "Credential", 0.5, 0.48, 0.56, 0.62, colors.EmeraldDeep)
		outline(canvas:FindFirstChild("Credential") :: Frame, ink, config.TrimPixels)
		shape(canvas, "ShieldPoint", 0.5, 0.78, 0.3, 0.3, colors.EmeraldDeep, 45)
		for i = -2, 2 do
			shape(canvas, "Fan", 0.5 + i * 0.08, 0.48, 0.025, 0.36 - math.abs(i) * 0.07, ink, i * 16)
		end
	end
	return canvas
end
function Art.plate(parent: Instance, title: string, position: UDim2, size: UDim2, kind: string?): Frame
	local root = Instance.new("Frame")
	root.Name = "Illustrated" .. (kind or "Archive")
	root.Position = position
	root.Size = size
	root.BackgroundColor3 = colors.Canvas
	root.BorderSizePixel = 0
	root.ClipsDescendants = true
	root.Parent = parent
	outline(root, colors.Brass, config.TrimPixels)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(colors.Walnut, colors.Canvas)
	gradient.Rotation = 28
	gradient.Parent = root
	Art.trim(root)
	-- Engraved sunburst, confined to the illustration field above the separate title band.
	for i = 0, 16 do
		local angle = math.rad(25 + i * 8)
		local line = shape(
			root,
			"EngravedRay",
			0.5 + math.cos(angle) * 0.28,
			0.37 + math.sin(angle) * 0.12,
			0.002,
			0.58,
			colors.Brass,
			i * 8 - 65
		)
		line.BackgroundTransparency = 0.7
	end
	local field = shape(root, "MedallionField", 0.5, 0.4, 0.52, 0.64, colors.Canvas)
	field.BackgroundTransparency = 0.25
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1
	aspect.Parent = field
	Art.insignia(field, kind or "Archive")
	local band = shape(root, "IvoryTitleBand", 0.5, 0.87, 0.92, 0.2, colors.Text)
	local label = Instance.new("TextLabel")
	label.Name = "IllustrationTitle"
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromScale(0.04, 0.08)
	label.Size = UDim2.fromScale(0.92, 0.84)
	label.Font = config.Fonts.Bold
	label.TextSize = config.TextSizes.Title
	label.TextColor3 = colors.TextOnBright
	label.TextWrapped = true
	label.Text = title:gsub("\n", " / ")
	label.Parent = band
	return root
end
return Art
