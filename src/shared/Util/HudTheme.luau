--!strict
-- Map-specific presentation over one shared HUD. Layout, timing and semantic colors stay in the base config.
local GameConfig = require(script.Parent.Parent.GameConfig)
local ui = GameConfig.UI
export type Theme = typeof(ui.GraphicHud)
local HudTheme = {}
local cache: { [string]: Theme } = {}
local allowed = {
	PanelColor = true,
	PanelTransparency = true,
	BorderColor = true,
	BorderTransparency = true,
	ShadowTransparency = true,
	CornerPixels = true,
	AccentColor = true,
}

function HudTheme.get(id: string?): Theme
	local name = id or ui.HudThemeId
	local existing = cache[name]
	if existing then
		return existing
	end
	local result = table.clone(ui.GraphicHud)
	local values = result :: any
	local skins = ui.HudThemes :: { [string]: { [string]: any } }
	local skin = skins[name]
	if skin then
		for key, value in skin do
			assert((allowed :: { [string]: boolean })[key], `HUD skin {name} cannot override {key}`)
			assert(typeof(values[key]) == typeof(value), `Invalid HUD skin value {name}.{key}`)
			values[key] = value
		end
	end -- Unregistered maps use the neutral base, without inventing a map-specific skin.
	table.freeze(result)
	cache[name] = result
	return result
end

return HudTheme
