--!strict
-- The player settings that are saved with the profile (owner 2026-11-25), and how each is checked. The server uses it to accept only valid values from a
-- client; the client uses it to read them back. Stored values are plain numbers, booleans and strings so the profile saves as data: a colour is a table
-- { R, G, B } of 0 to 255.
--
--   SettingsSchema.sanitize(raw) -> { [string]: any }     only the known keys, each checked and bounded; anything else is dropped
--   SettingsSchema.colorToStored(Color3) -> { R, G, B }
--   SettingsSchema.storedToColor(any) -> Color3?

local GameConfig = require(script.Parent.Parent.GameConfig)

type Entry = {
	Key: string,
	Kind: "number" | "boolean" | "color" | "choice",
	Min: number?,
	Max: number?,
	Choices: { string }?,
}

local clientSettings = GameConfig.ClientSettings

local entries: { Entry } = {
	{ Key = "Fov", Kind = "number", Min = GameConfig.UI.FovMin, Max = GameConfig.UI.FovMax },
	{ Key = "Sensitivity", Kind = "number", Min = clientSettings.SensitivityMin, Max = clientSettings.SensitivityMax },
	{
		Key = "AdsSensitivity",
		Kind = "number",
		Min = clientSettings.AdsSensitivityMin,
		Max = clientSettings.AdsSensitivityMax,
	},
	{ Key = "ReducedMotion", Kind = "boolean" },
	{ Key = "CameraShake", Kind = "boolean" },
	{ Key = "CombatVolume", Kind = "number", Min = 0, Max = 1 },
	{ Key = "WorldVolume", Kind = "number", Min = 0, Max = 1 },
	{ Key = "ExposedOutline", Kind = "boolean" },
	{ Key = "ExposedOutlineColor", Kind = "color" },
	{ Key = "ShowFps", Kind = "boolean" },
	{ Key = "CrosshairColor", Kind = "color" },
	{
		Key = "CrosshairScale",
		Kind = "number",
		Min = clientSettings.CrosshairScaleMin,
		Max = clientSettings.CrosshairScaleMax,
	},
	{ Key = "GraphicsMode", Kind = "choice", Choices = { "Auto", "Low", "Medium", "High" } },
	{ Key = "Shadows", Kind = "choice", Choices = { "Auto", "On", "Off" } },
	{ Key = "Bloom", Kind = "choice", Choices = { "Auto", "On", "Off" } },
}

local SettingsSchema = {}

function SettingsSchema.colorToStored(color: Color3): { R: number, G: number, B: number }
	return {
		R = math.floor(color.R * 255 + 0.5),
		G = math.floor(color.G * 255 + 0.5),
		B = math.floor(color.B * 255 + 0.5),
	}
end

local function channel(value: any): number?
	if type(value) ~= "number" or value ~= value then
		return nil
	end
	return math.clamp(math.floor(value + 0.5), 0, 255)
end

function SettingsSchema.storedToColor(stored: any): Color3?
	if type(stored) ~= "table" then
		return nil
	end
	local r, g, b = channel(stored.R), channel(stored.G), channel(stored.B)
	if r and g and b then
		return Color3.fromRGB(r, g, b)
	end
	return nil
end

function SettingsSchema.sanitize(raw: any): { [string]: any }
	local clean: { [string]: any } = {}
	if type(raw) ~= "table" then
		return clean
	end
	for _, entry in entries do
		local value = raw[entry.Key]
		if entry.Kind == "number" then
			if type(value) == "number" and value == value and math.abs(value) ~= math.huge then
				clean[entry.Key] = math.clamp(value, entry.Min :: number, entry.Max :: number)
			end
		elseif entry.Kind == "boolean" then
			if type(value) == "boolean" then
				clean[entry.Key] = value
			end
		elseif entry.Kind == "color" then
			local color = SettingsSchema.storedToColor(value)
			if color then
				clean[entry.Key] = SettingsSchema.colorToStored(color)
			end
		elseif entry.Kind == "choice" then
			if type(value) == "string" and table.find(entry.Choices :: { string }, value) then
				clean[entry.Key] = value
			end
		end
	end
	return clean
end

return SettingsSchema
