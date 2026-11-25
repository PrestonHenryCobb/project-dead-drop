--!strict
-- The Never Seen Swag logo, drawn from frames and text so it has no background and needs no uploaded image (owner 2026-11-25): "N$$" in marker
-- letters, a red serif bar standing through each dollar sign, and a wifi sign struck out ("never seen"). Client only.
--
--   local logo = StudioLogo.build(parent, pixels)    pixels = the letter height on screen; everything else scales from it (root.Size is the unscaled size)
--   logo.root                                        the Frame holding the logo (transparent), sized to fit it
--   logo.letters / logo.bars / logo.rings / logo.dot / logo.slash   the parts, so a caller can animate them

local GameConfig = require(script.Parent.Parent.GameConfig)

local config = GameConfig.StudioIntro

export type Logo = {
	root: Frame,
	letters: { TextLabel },
	bars: { Frame }, -- the red bars; they start with no height and grow from the top to barHeights
	barHeights: { number },
	rings: { { Frame } }, -- the wifi rings from the inside out, each a list of line segments
	dot: Frame,
	slash: Frame,
	slashLength: number,
	slashCenter: UDim2, -- where the slash's centre ends up; it grows from its start by moving there while it lengthens
}

local StudioLogo = {}

-- Proportions, as fractions of the letter height. These are drawing shapes, not gameplay tunables.
local CELL_WIDTH = 0.78
local LETTER_GROW = 1.7
local LETTER_CENTER = 0.62
local BAR_WIDTH = 0.07
local BAR_HEIGHT = 1.0
local BAR_LEAN = 12 -- degrees: the bars lean with the dollar signs' streak
local BAR_CENTER = 0.62 -- the bars' centre, down the letter height
local SERIF_WIDTH = 0.42
local SERIF_HEIGHT = 0.07
local WIFI_WIDTH = 1.0
local WIFI_GAP = 0.18
local WIFI_STROKE = 0.075
local WIFI_RINGS = { 0.3, 0.55, 0.8 } -- ring radii against the wifi sign's half width
local WIFI_SWEEP = math.rad(50) -- each ring covers this angle either side of straight up
local WIFI_SEGMENTS = 8
local WIFI_DOT = 0.1
local WIFI_BASE = 0.88 -- where the sign's point sits, down the letter height
local STRIKE_ANGLE = 40 -- degrees from straight up
local STRIKE_OVER = 0.14 -- how far the slash runs past the outer ring, against the letter height
local STRIKE_TAIL = 0.18 -- how far it runs past the dot
local WIFI_REACH = 1.6 -- ring radius multiplier against the half width

local function line(parent: Instance, a: Vector2, b: Vector2, thickness: number, color: Color3): Frame
	local delta = b - a
	local part = Instance.new("Frame")
	part.AnchorPoint = Vector2.new(0.5, 0.5)
	part.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
	part.Size = UDim2.fromOffset(delta.Magnitude + thickness * 0.5, thickness)
	part.Rotation = math.deg(math.atan2(delta.Y, delta.X))
	part.BackgroundColor3 = color
	part.BackgroundTransparency = 1
	part.BorderSizePixel = 0
	part.Parent = parent
	return part
end

-- Text stops growing at size 100, so the logo is always drawn at that size and scaled up as a whole.
local BASE_PIXELS = 100

function StudioLogo.build(parent: Instance, letterPixels: number): Logo
	local pixels = BASE_PIXELS
	local cell = pixels * CELL_WIDTH
	local wifi = pixels * WIFI_WIDTH
	local width = cell * 3 + pixels * WIFI_GAP + wifi
	local root = Instance.new("Frame")
	root.Name = "StudioLogo"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromOffset(width, pixels * 1.25)
	local scale = Instance.new("UIScale")
	scale.Scale = letterPixels / BASE_PIXELS
	scale.Parent = root
	root.Parent = parent

	local letters: { TextLabel } = {}
	local bars: { Frame } = {}
	local barHeights: { number } = {}
	for index, glyph in { "N", "$", "$" } do
		local letter = Instance.new("TextLabel")
		letter.Name = "Letter" .. index
		letter.BackgroundTransparency = 1
		letter.Font = Enum.Font.PermanentMarker
		letter.Text = glyph
		letter.TextSize = pixels
		letter.TextColor3 = config.InkColor
		letter.TextTransparency = 1
		letter.AnchorPoint = Vector2.new(0.5, 0.5)
		letter.Position = UDim2.fromOffset((index - 0.5) * cell, pixels * LETTER_CENTER)
		letter.Size = UDim2.fromOffset(cell, pixels * 1.25)
		local grow = Instance.new("UIScale") -- the marker font's glyphs are small for their size
		grow.Scale = LETTER_GROW
		grow.Parent = letter
		letter.Parent = root
		table.insert(letters, letter)
		if glyph == "$" then
			-- A red "I": a vertical bar with a serif at each end, standing through the sign.
			local group = Instance.new("Frame")
			group.Name = "Bar" .. index
			group.BackgroundTransparency = 1
			group.AnchorPoint = Vector2.new(0.5, 0.5)
			group.Position = UDim2.fromOffset((index - 0.5) * cell, pixels * BAR_CENTER)
			group.Rotation = BAR_LEAN
			group.Size = UDim2.fromOffset(pixels * SERIF_WIDTH, 0)
			group.Parent = root
			local stem = Instance.new("Frame")
			stem.BackgroundColor3 = config.RedColor
			stem.BorderSizePixel = 0
			stem.AnchorPoint = Vector2.new(0.5, 0)
			stem.Position = UDim2.fromScale(0.5, 0)
			stem.Size = UDim2.new(0, pixels * BAR_WIDTH, 1, 0)
			stem.Parent = group
			for _, top in { true, false } do
				local serif = Instance.new("Frame")
				serif.BackgroundColor3 = config.RedColor
				serif.BorderSizePixel = 0
				serif.AnchorPoint = Vector2.new(0.5, if top then 0 else 1)
				serif.Position = UDim2.fromScale(0.5, if top then 0 else 1)
				serif.Size = UDim2.fromOffset(pixels * SERIF_WIDTH, pixels * SERIF_HEIGHT)
				serif.Parent = group
			end
			table.insert(bars, group)
			table.insert(barHeights, pixels * BAR_HEIGHT)
		end
	end

	-- The wifi sign, in its own box to the right.
	local box = Instance.new("Frame")
	box.Name = "Wifi"
	box.BackgroundTransparency = 1
	box.Position = UDim2.fromOffset(cell * 3 + pixels * WIFI_GAP, 0)
	box.Size = UDim2.fromOffset(wifi, pixels * 1.25)
	box.Parent = root
	local origin = Vector2.new(wifi / 2, pixels * WIFI_BASE)
	local stroke = pixels * WIFI_STROKE
	local rings: { { Frame } } = {}
	for _, radius in WIFI_RINGS do
		local segments: { Frame } = {}
		local r = radius * wifi / 2 * WIFI_REACH
		for step = 0, WIFI_SEGMENTS - 1 do
			local a1 = -WIFI_SWEEP + 2 * WIFI_SWEEP * step / WIFI_SEGMENTS
			local a2 = -WIFI_SWEEP + 2 * WIFI_SWEEP * (step + 1) / WIFI_SEGMENTS
			local p1 = origin + Vector2.new(math.sin(a1), -math.cos(a1)) * r
			local p2 = origin + Vector2.new(math.sin(a2), -math.cos(a2)) * r
			table.insert(segments, line(box, p1, p2, stroke, config.InkColor))
		end
		table.insert(rings, segments)
	end
	local dot = Instance.new("Frame")
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromOffset(origin.X, origin.Y)
	dot.Size = UDim2.fromOffset(pixels * WIFI_DOT, pixels * WIFI_DOT)
	dot.BackgroundColor3 = config.InkColor
	dot.BackgroundTransparency = 1
	dot.BorderSizePixel = 0
	dot.Parent = box
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = dot

	-- The strike: a line through the dot that crosses every ring, from just past the outer ring down to a short tail under the dot.
	local angle = math.rad(STRIKE_ANGLE)
	local direction = Vector2.new(-math.sin(angle), -math.cos(angle)) -- up and to the left, from the dot
	local outer = WIFI_RINGS[#WIFI_RINGS] * wifi / 2 * WIFI_REACH
	local start = origin + direction * (outer + pixels * STRIKE_OVER)
	local finish = origin - direction * (pixels * STRIKE_TAIL)
	local length = (finish - start).Magnitude
	local slash = Instance.new("Frame")
	slash.Name = "Slash"
	slash.AnchorPoint = Vector2.new(0.5, 0.5) -- a rotated frame turns about its centre, so it grows from the start by centre and length together
	slash.Position = UDim2.fromOffset(start.X, start.Y)
	slash.Size = UDim2.fromOffset(0, stroke * 1.1)
	slash.Rotation = math.deg(math.atan2(finish.Y - start.Y, finish.X - start.X))
	slash.BackgroundColor3 = config.RedColor
	slash.BorderSizePixel = 0
	slash.Parent = box

	return {
		root = root,
		letters = letters,
		bars = bars,
		barHeights = barHeights,
		rings = rings,
		dot = dot,
		slash = slash,
		slashLength = length,
		slashCenter = UDim2.fromOffset((start.X + finish.X) / 2, (start.Y + finish.Y) / 2),
	}
end

return StudioLogo
