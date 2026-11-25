--!strict
-- How each of the six agents looks on the menu stage and in their menu portrait (owner 2026-11-25: every agent gets their own outfit). The looks are
-- derived from each agent's epithet, class and role in AgentDefs. This is the MENU look only: in a match every player is disguised as a guest, member
-- of staff, security or an executive, and an Exposed player wears the plain True Form, so none of this reaches the game world (identity secrecy).
--
--   AgentLooks.outfit(agentId) -> OutfitDef       the outfit for the stage rig (OutfitApplier.apply)
--   AgentLooks.accent(agentId) -> Color3          the agent's colour on cards and portraits

local GameConfig = require(script.Parent.Parent.GameConfig)
local OutfitDefs = require(script.Parent.OutfitDefs)
local Types = require(script.Parent.Parent.Types)

type OutfitDef = Types.OutfitDef

local rig = GameConfig.Rig
local middleWidth = (rig.WidthScaleMin + rig.WidthScaleMax) / 2
local middleHeight = (rig.HeightScaleMin + rig.HeightScaleMax) / 2

local function color(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local function look(
	id: string,
	skin: Color3,
	hairStyle: Types.HairStyle,
	hair: Color3,
	jacket: Color3,
	trousers: Color3,
	shoes: Color3,
	accessories: { Types.AccessoryDef },
	height: number,
	width: number
): OutfitDef
	return {
		OutfitId = "Agent" .. id,
		Role = "Guest", -- only a walk-speed class, as for the True Form; never used in a match
		Tier = OutfitDefs.trueForm.Tier,
		BodyColors = { Skin = skin, Shoes = shoes },
		Shirt = { Color = jacket, LongSleeves = true },
		Pants = { Color = trousers },
		Accessories = accessories,
		Hair = { Style = hairStyle, Color = hair },
		Face = "Default",
		Scale = { Height = height, Width = width, Depth = width, Head = 1 },
	}
end

local accents: { [string]: Color3 } = {
	Guise = color(0, 170, 150), -- teal: the chameleon
	Parapet = color(120, 150, 190), -- steel blue: the bulwark
	Lattice = color(0, 205, 225), -- cyan: the technician
	Reticle = color(150, 160, 90), -- olive: the marksman
	Suture = color(190, 60, 80), -- crimson: the medic
	Feint = color(150, 100, 215), -- violet: the illusionist
}

local outfits: { [string]: OutfitDef } = {
	-- The Chameleon: a quiet charcoal suit in a teal that can pass for anything, a fedora, a pocket square for a change of face.
	Guise = look(
		"Guise",
		color(224, 172, 105),
		"SlickBack",
		color(20, 18, 16),
		color(40, 58, 62),
		color(26, 32, 34),
		color(20, 20, 22),
		{
			{ Kind = "Fedora", Color = color(56, 64, 68) },
			{ Kind = "Tie", Color = accents.Guise },
			{ Kind = "Lapels", Color = color(30, 44, 48) },
			{ Kind = "PocketSquare", Color = accents.Guise },
		},
		middleHeight,
		middleWidth
	),
	-- The Bulwark: the widest build, a steel-blue coat, no hair and a heavy beard.
	Parapet = look(
		"Parapet",
		color(141, 85, 36),
		"Bald",
		color(20, 18, 16),
		color(44, 56, 78),
		color(30, 36, 50),
		color(24, 24, 28),
		{
			{ Kind = "Beard", Color = color(20, 18, 16) },
			{ Kind = "Lapels", Color = accents.Parapet },
			{ Kind = "Tie", Color = color(120, 140, 170) },
			{ Kind = "LapelPin", Color = accents.Parapet },
		},
		middleHeight,
		rig.WidthScaleMax
	),
	-- The Technician: slim and short, glasses, a cyan scarf over a dark hoodie-grey jacket.
	Lattice = look(
		"Lattice",
		color(246, 208, 170),
		"Ponytail",
		color(60, 38, 24),
		color(36, 40, 50),
		color(28, 30, 38),
		color(240, 240, 244),
		{
			{ Kind = "Glasses", Color = accents.Lattice },
			{ Kind = "Scarf", Color = accents.Lattice },
		},
		rig.HeightScaleMin,
		rig.WidthScaleMin
	),
	-- The Marksman: the tallest, olive drab, sunglasses and a moustache.
	Reticle = look(
		"Reticle",
		color(198, 134, 66),
		"Crop",
		color(40, 30, 28),
		color(66, 72, 50),
		color(42, 46, 34),
		color(28, 24, 20),
		{
			{ Kind = "Sunglasses", Color = color(14, 14, 16) },
			{ Kind = "Mustache", Color = color(40, 30, 28) },
			{ Kind = "Tie", Color = color(40, 44, 30) },
			{ Kind = "Lapels", Color = color(54, 60, 42) },
		},
		rig.HeightScaleMax,
		middleWidth
	),
	-- The Field Medic: a burgundy coat, a pale scarf, a gold chain, red hair in a bun.
	Suture = look(
		"Suture",
		color(255, 224, 189),
		"Bun",
		color(140, 60, 40),
		color(124, 30, 50),
		color(44, 28, 32),
		color(30, 22, 24),
		{
			{ Kind = "Scarf", Color = color(232, 226, 214) },
			{ Kind = "Necklace", Color = color(215, 180, 90) },
			{ Kind = "LapelPin", Color = accents.Suture },
		},
		middleHeight,
		middleWidth
	),
	-- The Illusionist: a violet coat, gold bow tie, a fedora and curls, a moustache for the trick.
	Feint = look(
		"Feint",
		color(160, 100, 55),
		"Curly",
		color(20, 18, 16),
		color(72, 42, 112),
		color(30, 22, 44),
		color(20, 18, 24),
		{
			{ Kind = "Fedora", Color = color(46, 28, 74) },
			{ Kind = "BowTie", Color = color(215, 180, 90) },
			{ Kind = "Mustache", Color = color(20, 18, 16) },
			{ Kind = "PocketSquare", Color = color(215, 180, 90) },
		},
		middleHeight,
		middleWidth
	),
}

local AgentLooks = {}

function AgentLooks.outfit(agentId: string): OutfitDef
	return outfits[agentId] or OutfitDefs.trueForm
end

function AgentLooks.accent(agentId: string): Color3
	return accents[agentId] or color(182, 154, 103)
end

return AgentLooks
