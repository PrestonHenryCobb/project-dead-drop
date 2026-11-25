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
local Types = require(Shared:WaitForChild("Types"))

local config = GameConfig.Menu
local icons = config.Icons
local colors = config.Colors

export type Stat = { Icon: string, Text: string }

-- Normalised strokes (x1, y1, x2, y2) on a 0..1 square. HudKit already draws Shield and Bullet; the rest are here.
local DRAWINGS: { [string]: { { number } } } = {
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
}
-- HudKit's own drawings, used by name when this module has none.
local HUDKIT_ICONS: { [string]: boolean } = { Shield = true, Bullet = true }

local MenuIcons = {}

-- The icon for an agent class.
function MenuIcons.classIcon(class: string): string
	return if class == "Enforcer" then "Shield" elseif class == "Deceiver" then "Deceiver" else "Specialist"
end

function MenuIcons.icon(parent: Instance, name: string, position: UDim2, pixels: number, color: Color3): Frame
	local drawing = DRAWINGS[name]
	assert(drawing or HUDKIT_ICONS[name], `Unknown menu icon {name}`)
	return HudKit.icon(parent, name, position, pixels, color, drawing, icons.StrokeFraction)
end

function MenuIcons.lead(button: TextButton, icon: string)
	MenuIcons.icon(
		button,
		icon,
		UDim2.new(0, icons.EdgePixels, 0.5, -icons.RowIconPixels / 2),
		icons.RowIconPixels,
		colors.BrassBright
	)
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

-- What a weapon shows, whatever its kind: damage, then the numbers that matter for that kind.
function MenuIcons.weaponStats(def: Types.WeaponDef): { Stat }
	local melee = def.Melee
	if melee then
		return {
			{ Icon = "Swing", Text = tostring(melee.SwingDamage) },
			{ Icon = "Range", Text = tostring(melee.SwingReach) },
			{ Icon = "Clock", Text = `{melee.SwingSeconds}s` },
		}
	end
	if def.Projectile and def.Projectile.Kind == "Knife" then
		return {
			{ Icon = "Bullet", Text = tostring(def.Damage) },
			{ Icon = "Ammo", Text = tostring(def.MagSize) },
		}
	end
	local stats: { Stat } = {}
	if def.Burst then
		table.insert(stats, { Icon = "Bullet", Text = `{def.Damage}×{def.Burst.Count}` })
	elseif def.Pellets then
		table.insert(stats, { Icon = "Bullet", Text = `{def.Pellets}×{def.Damage}` })
	else
		table.insert(stats, { Icon = "Bullet", Text = tostring(def.Damage) })
	end
	if def.Taser then
		table.insert(stats, { Icon = "Range", Text = tostring(def.MaxRange) })
	elseif not def.Burst then
		table.insert(stats, { Icon = "Rate", Text = tostring(def.RPM) })
	end
	table.insert(stats, { Icon = "Ammo", Text = `{def.MagSize}/{def.ReserveAmmo}` })
	table.insert(stats, { Icon = "Reload", Text = `{def.ReloadSeconds}s` })
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

return MenuIcons
