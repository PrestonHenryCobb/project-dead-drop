--!strict
-- How each of the six agents looks (owner 2026-11-25: every agent gets their own outfit, and it is what they wear when they pop out of cover). The looks
-- come from each agent's epithet, class and role in AgentDefs. The same outfit shows on the menu stage and portraits and is the agent's True Form in a
-- match (spec 6.1: while Exposed they look like their agent model). While disguised, a player still looks like an NPC, so none of this shows until they
-- are Exposed.
--
--   AgentLooks.outfit(agentId) -> OutfitDef       the agent's True Form outfit (OutfitApplier.apply); the plain True Form for an unknown id
--   AgentLooks.all() -> { OutfitDef }             every agent's outfit
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
	Guise = color(0, 160, 170), -- teal-blue: the chameleon
	Parapet = color(120, 150, 190), -- steel blue: the bulwark
	Lattice = color(90, 200, 255), -- sky cyan: the technician
	Reticle = color(150, 160, 90), -- olive: the marksman
	Suture = color(200, 70, 90), -- crimson: the medic
	Feint = color(160, 110, 225), -- violet: the illusionist
}

-- True Form must read as "an agent" at a glance (spec 6.1, 7.2), so every look is a dark tactical base with its colour in small trims, and none uses an NPC
-- signature: no green, purple or gold ties and lapels, no black fedora, no sunglasses.
local outfits: { [string]: OutfitDef } = {
	-- The Chameleon: a quiet charcoal-teal coat, slicked hair and a pocket square for a change of face.
	Guise = look(
		"Guise",
		color(224, 172, 105),
		"SlickBack",
		color(20, 18, 16),
		color(30, 44, 48),
		color(22, 28, 30),
		color(20, 20, 22),
		{
			{ Kind = "PocketSquare", Color = accents.Guise },
			{ Kind = "LapelPin", Color = accents.Guise },
			{ Kind = "Scarf", Color = color(40, 62, 66) },
		},
		middleHeight,
		middleWidth
	),
	-- The Bulwark: the widest build, a dark steel coat, no hair and a heavy beard.
	Parapet = look(
		"Parapet",
		color(141, 85, 36),
		"Bald",
		color(20, 18, 16),
		color(34, 42, 58),
		color(24, 28, 38),
		color(24, 24, 28),
		{
			{ Kind = "Beard", Color = color(20, 18, 16) },
			{ Kind = "LapelPin", Color = accents.Parapet },
			{ Kind = "Scarf", Color = color(60, 74, 100) },
		},
		middleHeight,
		rig.WidthScaleMax
	),
	-- The Technician: slim and short, glasses, a sky-cyan scarf over a dark grey jacket.
	Lattice = look(
		"Lattice",
		color(246, 208, 170),
		"Ponytail",
		color(60, 38, 24),
		color(30, 32, 40),
		color(24, 26, 32),
		color(210, 214, 220),
		{
			{ Kind = "Glasses", Color = accents.Lattice },
			{ Kind = "Scarf", Color = accents.Lattice },
		},
		rig.HeightScaleMin,
		rig.WidthScaleMin
	),
	-- The Marksman: the tallest, dark olive, a moustache and an olive scarf.
	Reticle = look(
		"Reticle",
		color(198, 134, 66),
		"Crop",
		color(40, 30, 28),
		color(40, 44, 32),
		color(32, 36, 26),
		color(28, 24, 20),
		{
			{ Kind = "Mustache", Color = color(40, 30, 28) },
			{ Kind = "Scarf", Color = accents.Reticle },
			{ Kind = "LapelPin", Color = accents.Reticle },
		},
		rig.HeightScaleMax,
		middleWidth
	),
	-- The Field Medic: a deep wine coat, a pale scarf, a gold chain, red hair in a bun.
	Suture = look(
		"Suture",
		color(255, 224, 189),
		"Bun",
		color(140, 60, 40),
		color(66, 24, 36),
		color(34, 24, 28),
		color(30, 22, 24),
		{
			{ Kind = "Scarf", Color = color(228, 222, 210) },
			{ Kind = "Necklace", Color = color(215, 180, 90) },
			{ Kind = "LapelPin", Color = accents.Suture },
		},
		middleHeight,
		middleWidth
	),
	-- The Illusionist: a dark violet coat, a violet fedora, curls and a moustache for the trick.
	Feint = look(
		"Feint",
		color(160, 100, 55),
		"Curly",
		color(20, 18, 16),
		color(42, 30, 66),
		color(26, 22, 38),
		color(20, 18, 24),
		{
			{ Kind = "Fedora", Color = color(60, 40, 100) },
			{ Kind = "Mustache", Color = color(20, 18, 16) },
			{ Kind = "PocketSquare", Color = accents.Feint },
			{ Kind = "BowTie", Color = accents.Feint },
		},
		middleHeight,
		middleWidth
	),
}

local AgentLooks = {}

function AgentLooks.outfit(agentId: string): OutfitDef
	return outfits[agentId] or OutfitDefs.trueForm
end

function AgentLooks.all(): { OutfitDef }
	local list: { OutfitDef } = {}
	for _, outfit in outfits do
		table.insert(list, outfit)
	end
	return list
end

function AgentLooks.accent(agentId: string): Color3
	return accents[agentId] or color(182, 154, 103)
end

return AgentLooks
