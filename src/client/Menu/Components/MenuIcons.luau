--!strict
-- Icons for the menu screens (owner 2026-11-25: the menus had too much reading). Vector line drawings built with Util/HudKit, so there is no art to
-- upload. Every state keeps a short word next to its icon (the menu's rule: never colour or a symbol alone).
--
--   MenuIcons.icon(parent, name, position, pixels, color)         one icon
--   MenuIcons.badge(button, icon, text, color)                    an icon and a short word at the right edge of a button
--   MenuIcons.lead(button, icon)                                  an icon at the left edge of a button
--   MenuIcons.chips(parent, stats, y)                             a wrapping row of icon + value stats (see weaponStats)
--   MenuIcons.weaponStats(def) -> { Stat }                        the stats worth showing for a weapon
--   MenuIcons.pips(parent, y, filled, total, tags)                a row of pips, filled up to a level, with small tags over chosen ones

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local HudKit = require(Shared:WaitForChild("Util"):WaitForChild("HudKit"))
local AgentLooks = require(Shared:WaitForChild("Defs"):WaitForChild("AgentLooks"))
local MenuArtDefs = require(Shared:WaitForChild("Defs"):WaitForChild("MenuArtDefs"))
local Types = require(Shared:WaitForChild("Types"))

local config = GameConfig.Menu
local icons = config.Icons
local colors = config.Colors

export type Stat = { Icon: string, Text: string }

-- Normalised strokes (x1, y1, x2, y2) on a 0..1 square. HudKit already draws Shield and Bullet; the rest are here.
local DRAWINGS: { [string]: { { number } } } = {
	Squad = {
		{ 0.35, 0.1, 0.65, 0.1 },
		{ 0.65, 0.1, 0.65, 0.4 },
		{ 0.65, 0.4, 0.35, 0.4 },
		{ 0.35, 0.4, 0.35, 0.1 },
		{ 0.2, 0.9, 0.2, 0.6 },
		{ 0.2, 0.6, 0.8, 0.6 },
		{ 0.8, 0.6, 0.8, 0.9 },
	},
	Tier = { { 0.1, 0.65, 0.5, 0.25 }, { 0.5, 0.25, 0.9, 0.65 }, { 0.1, 0.9, 0.5, 0.5 }, { 0.5, 0.5, 0.9, 0.9 } },
	Currency = {
		{ 0.5, 0.1, 0.9, 0.5 },
		{ 0.9, 0.5, 0.5, 0.9 },
		{ 0.5, 0.9, 0.1, 0.5 },
		{ 0.1, 0.5, 0.5, 0.1 },
		{ 0.4, 0.4, 0.6, 0.4 },
		{ 0.6, 0.4, 0.4, 0.6 },
		{ 0.4, 0.6, 0.6, 0.6 },
	},
	Reward = {
		{ 0.15, 0.35, 0.85, 0.35 },
		{ 0.85, 0.35, 0.85, 0.9 },
		{ 0.85, 0.9, 0.15, 0.9 },
		{ 0.15, 0.9, 0.15, 0.35 },
		{ 0.5, 0.9, 0.5, 0.2 },
		{ 0.5, 0.35, 0.2, 0.1 },
		{ 0.2, 0.1, 0.2, 0.35 },
		{ 0.5, 0.35, 0.8, 0.1 },
		{ 0.8, 0.1, 0.8, 0.35 },
	},
	Package = {
		{ 0.1, 0.35, 0.9, 0.35 },
		{ 0.9, 0.35, 0.9, 0.85 },
		{ 0.9, 0.85, 0.1, 0.85 },
		{ 0.1, 0.85, 0.1, 0.35 },
		{ 0.3, 0.35, 0.3, 0.15 },
		{ 0.3, 0.15, 0.7, 0.15 },
		{ 0.7, 0.15, 0.7, 0.35 },
	},
	Extract = {
		{ 0.2, 0.15, 0.2, 0.85 },
		{ 0.2, 0.85, 0.5, 0.85 },
		{ 0.35, 0.5, 0.9, 0.5 },
		{ 0.9, 0.5, 0.65, 0.25 },
		{ 0.9, 0.5, 0.65, 0.75 },
	},
	Gadget = {
		{ 0.3, 0.35, 0.7, 0.35 },
		{ 0.7, 0.35, 0.8, 0.9 },
		{ 0.8, 0.9, 0.2, 0.9 },
		{ 0.2, 0.9, 0.3, 0.35 },
		{ 0.5, 0.35, 0.5, 0.1 },
		{ 0.5, 0.1, 0.8, 0.1 },
	},
	Deceiver = { -- a half mask
		{ 0.1, 0.3, 0.9, 0.3 },
		{ 0.9, 0.3, 0.8, 0.7 },
		{ 0.8, 0.7, 0.5, 0.9 },
		{ 0.5, 0.9, 0.2, 0.7 },
		{ 0.2, 0.7, 0.1, 0.3 },
		{ 0.25, 0.5, 0.4, 0.5 },
		{ 0.6, 0.5, 0.75, 0.5 },
	},
	Specialist = { -- a crosshair
		{ 0.5, 0.05, 0.5, 0.35 },
		{ 0.5, 0.65, 0.5, 0.95 },
		{ 0.05, 0.5, 0.35, 0.5 },
		{ 0.65, 0.5, 0.95, 0.5 },
		{ 0.35, 0.35, 0.65, 0.35 },
		{ 0.65, 0.35, 0.65, 0.65 },
		{ 0.65, 0.65, 0.35, 0.65 },
		{ 0.35, 0.65, 0.35, 0.35 },
	},
	Lock = {
		{ 0.2, 0.45, 0.8, 0.45 },
		{ 0.8, 0.45, 0.8, 0.9 },
		{ 0.8, 0.9, 0.2, 0.9 },
		{ 0.2, 0.9, 0.2, 0.45 },
		{ 0.32, 0.45, 0.32, 0.25 },
		{ 0.32, 0.25, 0.5, 0.1 },
		{ 0.5, 0.1, 0.68, 0.25 },
		{ 0.68, 0.25, 0.68, 0.45 },
	},
	Check = { { 0.15, 0.55, 0.4, 0.8 }, { 0.4, 0.8, 0.85, 0.25 } },
	Rate = { { 0.2, 0.2, 0.2, 0.8 }, { 0.5, 0.2, 0.5, 0.8 }, { 0.8, 0.2, 0.8, 0.8 } },
	Ammo = {
		{ 0.3, 0.1, 0.7, 0.1 },
		{ 0.7, 0.1, 0.7, 0.9 },
		{ 0.7, 0.9, 0.3, 0.9 },
		{ 0.3, 0.9, 0.3, 0.1 },
		{ 0.3, 0.4, 0.7, 0.4 },
	},
	Reload = {
		{ 0.8, 0.3, 0.5, 0.15 },
		{ 0.5, 0.15, 0.2, 0.4 },
		{ 0.2, 0.4, 0.25, 0.75 },
		{ 0.25, 0.75, 0.55, 0.9 },
		{ 0.55, 0.9, 0.85, 0.7 },
		{ 0.8, 0.3, 0.95, 0.1 },
		{ 0.8, 0.3, 0.6, 0.3 },
	},
	Range = { { 0.1, 0.5, 0.9, 0.5 }, { 0.1, 0.3, 0.1, 0.7 }, { 0.9, 0.3, 0.9, 0.7 } },
	Clock = {
		{ 0.5, 0.1, 0.82, 0.25 },
		{ 0.82, 0.25, 0.9, 0.5 },
		{ 0.9, 0.5, 0.82, 0.75 },
		{ 0.82, 0.75, 0.5, 0.9 },
		{ 0.5, 0.9, 0.18, 0.75 },
		{ 0.18, 0.75, 0.1, 0.5 },
		{ 0.1, 0.5, 0.18, 0.25 },
		{ 0.18, 0.25, 0.5, 0.1 },
		{ 0.5, 0.5, 0.5, 0.28 },
		{ 0.5, 0.5, 0.68, 0.6 },
	},
	Passive = { { 0.5, 0.15, 0.85, 0.5 }, { 0.85, 0.5, 0.5, 0.85 }, { 0.5, 0.85, 0.15, 0.5 }, { 0.15, 0.5, 0.5, 0.15 } },
	Swing = { { 0.2, 0.85, 0.8, 0.15 }, { 0.35, 0.55, 0.6, 0.75 } },
	Soon = { { 0.2, 0.5, 0.8, 0.5 }, { 0.5, 0.2, 0.5, 0.8 } },
	WeaponPistol = {
		{ 0.1, 0.35, 0.8, 0.35 },
		{ 0.8, 0.35, 0.8, 0.5 },
		{ 0.8, 0.5, 0.45, 0.5 },
		{ 0.45, 0.5, 0.4, 0.85 },
		{ 0.4, 0.85, 0.25, 0.85 },
		{ 0.25, 0.85, 0.3, 0.5 },
		{ 0.3, 0.5, 0.1, 0.5 },
		{ 0.1, 0.5, 0.1, 0.35 },
	},
	WeaponLong = {
		{ 0.05, 0.45, 0.95, 0.45 },
		{ 0.05, 0.55, 0.95, 0.55 },
		{ 0.05, 0.45, 0.05, 0.55 },
		{ 0.3, 0.55, 0.35, 0.9 },
		{ 0.35, 0.9, 0.45, 0.9 },
		{ 0.45, 0.9, 0.45, 0.55 },
		{ 0.6, 0.45, 0.6, 0.3 },
		{ 0.6, 0.3, 0.8, 0.3 },
		{ 0.8, 0.3, 0.8, 0.45 },
	},
	WeaponMelee = { { 0.2, 0.85, 0.8, 0.15 }, { 0.15, 0.7, 0.4, 0.95 }, { 0.2, 0.85, 0.1, 0.95 } },
	WeaponThrown = { { 0.3, 0.8, 0.7, 0.2 }, { 0.7, 0.2, 0.75, 0.45 }, { 0.75, 0.45, 0.3, 0.8 } },
}
-- HudKit's own drawings, used by name when this module has none.
local HUDKIT_ICONS: { [string]: boolean } = { Shield = true, Bullet = true }

local MenuIcons = {}

-- The icon for an agent class.
function MenuIcons.classIcon(class: string): string
	return if class == "Enforcer" then "Shield" elseif class == "Deceiver" then "Deceiver" else "Specialist"
end

-- The icon for a Hardware item's category.
function MenuIcons.weaponIcon(category: string): string
	local name = string.lower(category)
	if string.find(name, "melee", 1, true) then
		return "WeaponMelee"
	elseif string.find(name, "thrown", 1, true) then
		return "WeaponThrown"
	elseif (string.find(name, "pistol", 1, true) and not string.find(name, "machine", 1, true)) or name == "taser" then
		return "WeaponPistol"
	end
	return "WeaponLong"
end

function MenuIcons.icon(parent: Instance, name: string, position: UDim2, pixels: number, color: Color3): Frame
	local drawing = DRAWINGS[name]
	assert(drawing or HUDKIT_ICONS[name], `Unknown menu icon {name}`)
	return HudKit.icon(parent, name, position, pixels, color, drawing, icons.StrokeFraction)
end

function MenuIcons.lead(button: TextButton, icon: string, color: Color3?)
	MenuIcons.icon(
		button,
		icon,
		UDim2.new(0, icons.EdgePixels, 0.5, -icons.RowIconPixels / 2),
		icons.RowIconPixels,
		color or colors.BrassBright
	)
end

-- A picture at the left edge of a button: the image from a MenuArtDefs slot when there is one, otherwise the icon.
function MenuIcons.leadArt(button: TextButton, image: string?, icon: string, color: Color3?)
	if not image then
		MenuIcons.lead(button, icon, color)
		return
	end
	local picture = Instance.new("ImageLabel")
	picture.Name = "LeadArt"
	picture.BackgroundTransparency = 1
	picture.Image = image
	picture.ScaleType = Enum.ScaleType.Fit
	picture.Position = UDim2.new(0, icons.EdgePixels, 0.5, -icons.RowIconPixels / 2)
	picture.Size = UDim2.fromOffset(icons.RowIconPixels, icons.RowIconPixels)
	picture.Parent = button
end

local function label(parent: Instance, text: string, size: number, color: Color3, order: number): TextLabel
	local item = Instance.new("TextLabel")
	item.BackgroundTransparency = 1
	item.Font = config.Fonts.Bold
	item.Text = text
	item.TextSize = size
	item.TextColor3 = color
	item.AutomaticSize = Enum.AutomaticSize.XY
	item.Size = UDim2.fromOffset(0, 0)
	item.LayoutOrder = order
	item.Parent = parent
	return item
end

-- An icon and a short word at the right edge of a button, for a row's state ("lock · LVL 3", "check · EQUIPPED").
function MenuIcons.badge(button: TextButton, icon: string, text: string, color: Color3?)
	local tint = color or colors.TextDim
	local holder = Instance.new("Frame")
	holder.Name = "Badge"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(1, 0.5)
	holder.Position = UDim2.new(1, -icons.EdgePixels, 0.5, 0)
	holder.AutomaticSize = Enum.AutomaticSize.XY
	holder.Size = UDim2.fromOffset(0, 0)
	holder.Parent = button
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, icons.GapPixels)
	layout.Parent = holder
	local mark = MenuIcons.icon(holder, icon, UDim2.new(), icons.BadgeIconPixels, tint)
	mark.LayoutOrder = 1
	label(holder, text, config.TextSizes.Chip, tint, 2)
end

-- A wrapping row of stats, each an icon and its value.
function MenuIcons.chips(parent: Instance, stats: { Stat }, y: number): Frame
	local row = Instance.new("Frame")
	row.Name = "Stats"
	row.BackgroundTransparency = 1
	row.Position = UDim2.fromOffset(0, y)
	row.Size = UDim2.new(1, 0, 0, 0)
	row.AutomaticSize = Enum.AutomaticSize.Y
	row.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Wraps = true
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, icons.ChipGapPixels)
	layout.Parent = row
	for index, stat in stats do
		local chip = Instance.new("Frame")
		chip.Name = stat.Icon
		chip.BackgroundTransparency = 1
		chip.AutomaticSize = Enum.AutomaticSize.X
		chip.Size = UDim2.fromOffset(0, icons.ChipIconPixels + icons.GapPixels)
		chip.LayoutOrder = index
		chip.Parent = row
		local inner = Instance.new("UIListLayout")
		inner.FillDirection = Enum.FillDirection.Horizontal
		inner.VerticalAlignment = Enum.VerticalAlignment.Center
		inner.SortOrder = Enum.SortOrder.LayoutOrder
		inner.Padding = UDim.new(0, icons.GapPixels)
		inner.Parent = chip
		MenuIcons.icon(chip, stat.Icon, UDim2.new(), icons.ChipIconPixels, colors.BrassBright).LayoutOrder = 1
		label(chip, stat.Text, config.TextSizes.Small, colors.Text, 2)
	end
	return row
end

-- The same chips inside the menus' content-measured vertical stacks.
function MenuIcons.flow(parent: Instance, stats: { Stat }, order: number): Frame
	local row = MenuIcons.chips(parent, stats, 0)
	row.LayoutOrder = order
	return row
end

-- What a weapon shows, whatever its kind: damage, then the numbers that matter for that kind.
function MenuIcons.weaponStats(def: Types.WeaponDef): { Stat }
	local melee = def.Melee
	if melee then
		return {
			{ Icon = "Swing", Text = `{melee.SwingDamage} DMG` },
			{ Icon = "Range", Text = `{melee.SwingReach} RANGE` },
			{ Icon = "Clock", Text = `{melee.SwingSeconds}s SWING` },
		}
	end
	if def.Projectile and def.Projectile.Kind == "Knife" then
		return {
			{ Icon = "Bullet", Text = `{def.Damage} DMG` },
			{ Icon = "Ammo", Text = `{def.MagSize} AMMO` },
		}
	end
	local stats: { Stat } = {}
	if def.Burst then
		table.insert(stats, { Icon = "Bullet", Text = `{def.Damage}×{def.Burst.Count} DMG` })
	elseif def.Pellets then
		table.insert(stats, { Icon = "Bullet", Text = `{def.Pellets}×{def.Damage} DMG` })
	else
		table.insert(stats, { Icon = "Bullet", Text = `{def.Damage} DMG` })
	end
	if def.Taser then
		table.insert(stats, { Icon = "Range", Text = `{def.MaxRange} RANGE` })
	elseif not def.Burst then
		table.insert(stats, { Icon = "Rate", Text = `{def.RPM} RPM` })
	end
	table.insert(stats, { Icon = "Ammo", Text = `{def.MagSize}/{def.ReserveAmmo} AMMO` })
	table.insert(stats, { Icon = "Reload", Text = `{def.ReloadSeconds}s RELOAD` })
	return stats
end

-- A row of `total` pips, the first `filled` lit. `tags` maps a pip number to a small word over it (the level a weapon unlocks at).
function MenuIcons.pips(parent: Instance, y: number, filled: number, total: number, tags: { [number]: string }): Frame
	local row = Instance.new("Frame")
	row.Name = "Pips"
	row.BackgroundTransparency = 1
	row.Position = UDim2.fromOffset(0, y)
	row.Size = UDim2.new(1, 0, 0, icons.PipPixels + config.TextSizes.Chip + icons.GapPixels)
	row.Parent = parent
	for index = 1, total do
		local left = (index - 1) * (icons.PipPixels + icons.PipGapPixels)
		local pip = Instance.new("Frame")
		pip.Name = `Pip{index}`
		pip.BackgroundColor3 = if index <= filled then colors.BrassBright else colors.Border
		pip.BackgroundTransparency = if index <= filled then 0 else 0.4
		pip.BorderSizePixel = 0
		pip.Position = UDim2.fromOffset(left, config.TextSizes.Chip + icons.GapPixels)
		pip.Size = UDim2.fromOffset(icons.PipPixels, icons.PipPixels)
		pip.Parent = row
		local tag = tags[index]
		if tag then
			local item = Instance.new("TextLabel")
			item.BackgroundTransparency = 1
			item.Font = config.Fonts.Bold
			item.Text = tag
			item.TextSize = config.TextSizes.Chip
			item.TextColor3 = if index <= filled then colors.BrassBright else colors.TextDim
			item.Position = UDim2.fromOffset(left - icons.PipGapPixels, 0)
			item.Size = UDim2.fromOffset(icons.PipPixels + icons.PipGapPixels * 2, config.TextSizes.Chip)
			item.Parent = row
		end
	end
	return row
end

-- A shape in a portrait: a box (optionally rounded) at fractions of the portrait's size.
local function shape(
	parent: Instance,
	x: number,
	y: number,
	w: number,
	h: number,
	fill: Color3,
	round: number,
	layer: number
): Frame
	local box = Instance.new("Frame")
	box.BackgroundColor3 = fill
	box.BorderSizePixel = 0
	box.Position = UDim2.fromScale(x, y)
	box.Size = UDim2.fromScale(w, h)
	box.ZIndex = layer
	box.Parent = parent
	if round > 0 then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(round, 0)
		corner.Parent = box
	end
	return box
end

-- A bust of an agent, built from the same outfit the 3D model wears so the two always match, or the agent's picture from MenuArtDefs once there is one.
function MenuIcons.portrait(parent: Instance, agentId: string, pixels: number, position: UDim2): Frame
	local frame = Instance.new("Frame")
	frame.Name = "Portrait"
	frame.Position = position
	frame.Size = UDim2.fromOffset(pixels, pixels)
	frame.BorderSizePixel = 0
	frame.BackgroundColor3 = AgentLooks.accent(agentId):Lerp(colors.Canvas, icons.PortraitPlateMix)
	frame.ClipsDescendants = true
	frame.Parent = parent
	local image = MenuArtDefs.portrait(agentId)
	if image then
		local picture = Instance.new("ImageLabel")
		picture.BackgroundTransparency = 1
		picture.Image = image
		picture.ScaleType = Enum.ScaleType.Crop
		picture.Size = UDim2.fromScale(1, 1)
		picture.Parent = frame
		return frame
	end
	local outfit = AgentLooks.outfit(agentId)
	local skin, jacket = outfit.BodyColors.Skin, outfit.Shirt.Color
	local ink = colors.Canvas
	local style = outfit.Hair.Style
	local hair = outfit.Hair.Color
	if style == "Afro" or style == "Curly" then
		shape(frame, 0.22, 0.1, 0.56, 0.42, hair, 0.5, 1)
	end
	shape(frame, 0.1, 0.74, 0.8, 0.5, jacket, 0.3, 1) -- shoulders
	shape(frame, 0.42, 0.56, 0.16, 0.22, skin, 0, 1) -- neck
	shape(frame, 0.3, 0.2, 0.4, 0.46, skin, 0.22, 2) -- head
	if style ~= "Bald" and style ~= "Afro" and style ~= "Curly" then
		shape(frame, 0.29, 0.17, 0.42, 0.16, hair, 0.4, 3)
		if style == "Long" then
			shape(frame, 0.26, 0.25, 0.07, 0.42, hair, 0.3, 3)
			shape(frame, 0.67, 0.25, 0.07, 0.42, hair, 0.3, 3)
		elseif style == "Bun" then
			shape(frame, 0.42, 0.06, 0.16, 0.16, hair, 0.5, 3)
		elseif style == "Ponytail" then
			shape(frame, 0.7, 0.24, 0.08, 0.34, hair, 0.4, 3)
		end
	end
	local hasSunglasses = false
	for _, item in outfit.Accessories do
		if item.Kind == "Sunglasses" then
			hasSunglasses = true
		end
	end
	if not hasSunglasses then
		shape(frame, 0.37, 0.4, 0.05, 0.05, ink, 0.5, 4)
		shape(frame, 0.58, 0.4, 0.05, 0.05, ink, 0.5, 4)
	end
	for _, item in outfit.Accessories do
		local kind, tint = item.Kind, item.Color
		if kind == "Glasses" then
			shape(frame, 0.33, 0.37, 0.14, 0.1, tint, 0.2, 5).BackgroundTransparency = 0.55
			shape(frame, 0.53, 0.37, 0.14, 0.1, tint, 0.2, 5).BackgroundTransparency = 0.55
		elseif kind == "Sunglasses" then
			shape(frame, 0.32, 0.37, 0.36, 0.09, tint, 0.2, 5)
		elseif kind == "Mustache" then
			shape(frame, 0.4, 0.54, 0.2, 0.04, tint, 0.5, 5)
		elseif kind == "Beard" then
			shape(frame, 0.3, 0.52, 0.4, 0.15, tint, 0.45, 4)
		elseif kind == "Fedora" then
			shape(frame, 0.2, 0.17, 0.6, 0.05, tint, 0.5, 6)
			shape(frame, 0.3, 0.05, 0.4, 0.14, tint, 0.25, 6)
		elseif kind == "Scarf" then
			shape(frame, 0.3, 0.66, 0.4, 0.11, tint, 0.3, 5)
		elseif kind == "Tie" then
			shape(frame, 0.47, 0.72, 0.06, 0.26, tint, 0, 5)
		elseif kind == "BowTie" then
			shape(frame, 0.4, 0.7, 0.2, 0.06, tint, 0.3, 5)
		elseif kind == "Necklace" then
			shape(frame, 0.38, 0.69, 0.24, 0.03, tint, 0.5, 5)
		end
	end
	return frame
end

return MenuIcons
