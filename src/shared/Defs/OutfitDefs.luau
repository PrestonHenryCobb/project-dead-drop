--!strict
-- Every NPC and every player disguise is one of these outfits (spec 5.1, 6, 25.3).
--
-- Each role has a uniform signature so the tier is readable at a glance, and matches its zone colour (GameConfig.Zones):
--   Guest      varied colourful formalwear, never navy, black or cream, and no hat
--   Staff      light navy suits with green ties and lapels, and a black hat: green
--   Security   black suits with dark purple accessories (lapels, tie) and sunglasses: dark purple
--   Executive  cream suits with gold accessories (lapels, tie, pocket square, pin): gold
-- Outfits are generated from small palettes so every role has well over GameConfig.NPC.MinOutfitsPerRole of them
-- and no two share an OutfitId. Colors, accessories and hair are the only things that differ; the rig is shared.
--
--   OutfitDefs.byId["Guest01"] -> OutfitDef
--   OutfitDefs.byRole.Guest -> { OutfitDef }
--   OutfitDefs.random("Guest", rng) -> OutfitDef

local Shared = script.Parent.Parent
local DeepFreeze = require(Shared.Util.DeepFreeze)
local Enums = require(Shared.Enums)
local GameConfig = require(Shared.GameConfig)
local Types = require(Shared.Types)

type OutfitDef = Types.OutfitDef
type AccessoryDef = Types.AccessoryDef
type Role = Types.Role

-- Owner 2026-11-22: the crowd looked too alike. Ninety-six outfits a role, drawn from wide palettes of skin, hair, jackets, trousers and accessories; the tier
-- signatures (zone colours) are unchanged so a role still reads at a glance.
local OUTFITS_PER_ROLE = 96

local SKIN = {
	Color3.fromRGB(255, 224, 189),
	Color3.fromRGB(246, 208, 170),
	Color3.fromRGB(241, 194, 143),
	Color3.fromRGB(224, 172, 105),
	Color3.fromRGB(198, 134, 66),
	Color3.fromRGB(160, 100, 55),
	Color3.fromRGB(141, 85, 36),
	Color3.fromRGB(90, 56, 37),
}
local HAIR_COLORS = {
	Color3.fromRGB(20, 18, 16),
	Color3.fromRGB(40, 30, 28),
	Color3.fromRGB(60, 38, 24),
	Color3.fromRGB(105, 66, 36),
	Color3.fromRGB(140, 60, 40),
	Color3.fromRGB(176, 92, 50),
	Color3.fromRGB(214, 180, 110),
	Color3.fromRGB(235, 225, 200),
	Color3.fromRGB(170, 170, 170),
	Color3.fromRGB(232, 232, 232),
}
local HAIR_STYLES: { Types.HairStyle } =
	{ "Short", "Long", "Bun", "Crop", "Bald", "Afro", "Curly", "Ponytail", "SlickBack" }
local SHOES = {
	Color3.fromRGB(25, 25, 28),
	Color3.fromRGB(70, 45, 30),
	Color3.fromRGB(110, 20, 30),
	Color3.fromRGB(90, 90, 95),
	Color3.fromRGB(150, 110, 70),
}
local FRAMES = {
	Color3.fromRGB(30, 30, 34),
	Color3.fromRGB(120, 85, 50),
	Color3.fromRGB(190, 160, 90),
	Color3.fromRGB(150, 40, 50),
}
local JEWELLERY = { Color3.fromRGB(215, 180, 90), Color3.fromRGB(205, 208, 215) }

-- Formal jackets and trousers for guests (never navy, black or cream: those are other roles' colours).
local GUEST_JACKETS = {
	Color3.fromRGB(110, 25, 45),
	Color3.fromRGB(35, 110, 75),
	Color3.fromRGB(95, 45, 120),
	Color3.fromRGB(180, 140, 40),
	Color3.fromRGB(200, 110, 140),
	Color3.fromRGB(30, 110, 120),
	Color3.fromRGB(140, 90, 50),
	Color3.fromRGB(110, 100, 150),
	Color3.fromRGB(215, 100, 85),
	Color3.fromRGB(95, 110, 50),
	Color3.fromRGB(170, 60, 60),
	Color3.fromRGB(60, 140, 100),
	Color3.fromRGB(125, 60, 95),
	Color3.fromRGB(220, 170, 80),
	Color3.fromRGB(80, 150, 170),
	Color3.fromRGB(180, 90, 60),
	Color3.fromRGB(150, 130, 180),
	Color3.fromRGB(90, 120, 90),
	Color3.fromRGB(200, 80, 120),
	Color3.fromRGB(140, 150, 60),
}
local GUEST_PANTS = {
	Color3.fromRGB(20, 20, 24),
	Color3.fromRGB(45, 45, 52),
	Color3.fromRGB(32, 38, 60),
	Color3.fromRGB(85, 70, 55),
	Color3.fromRGB(60, 50, 45),
	Color3.fromRGB(95, 95, 105),
	Color3.fromRGB(50, 60, 50),
	Color3.fromRGB(120, 100, 80),
}
local ACCENTS = {
	Color3.fromRGB(190, 40, 50),
	Color3.fromRGB(230, 200, 80),
	Color3.fromRGB(230, 140, 60), -- not green: green ties and lapels are the Staff signature
	Color3.fromRGB(240, 240, 240),
	Color3.fromRGB(200, 120, 160),
	Color3.fromRGB(70, 110, 190),
}

local STAFF_SUITS = {
	Color3.fromRGB(62, 88, 138),
	Color3.fromRGB(56, 80, 128),
	Color3.fromRGB(68, 95, 145),
	Color3.fromRGB(74, 100, 150),
	Color3.fromRGB(58, 84, 134),
	Color3.fromRGB(66, 92, 126),
}
local STAFF_TROUSERS = {
	Color3.fromRGB(48, 66, 108),
	Color3.fromRGB(44, 60, 100),
	Color3.fromRGB(52, 72, 116),
	Color3.fromRGB(56, 76, 120),
	Color3.fromRGB(46, 64, 104),
	Color3.fromRGB(50, 68, 98),
}
local SECURITY_SUITS = {
	Color3.fromRGB(16, 16, 20),
	Color3.fromRGB(22, 22, 26),
	Color3.fromRGB(28, 28, 32),
	Color3.fromRGB(20, 22, 28),
	Color3.fromRGB(26, 24, 30),
}
local EXECUTIVE_SUITS = {
	Color3.fromRGB(236, 228, 208),
	Color3.fromRGB(228, 222, 206),
	Color3.fromRGB(240, 234, 218),
	Color3.fromRGB(232, 224, 200),
	Color3.fromRGB(244, 238, 224),
	Color3.fromRGB(226, 218, 198),
}
local BLACK = Color3.fromRGB(14, 14, 16)

local tierColors = GameConfig.Zones.TierColors

local function pick<T>(list: { T }, index: number, step: number): T
	return list[(index * step) % #list + 1]
end

-- Scale stays inside GameConfig.Rig for every outfit: height in its range, width and depth in theirs.
local rig = GameConfig.Rig
local function scaleFor(index: number): { Height: number, Width: number, Depth: number, Head: number }
	local function at(min: number, max: number, step: number, offset: number): number
		return min + (max - min) * (((index * step + offset) % 11) / 10)
	end
	return {
		Height = at(rig.HeightScaleMin, rig.HeightScaleMax, 3, 0),
		Width = at(rig.WidthScaleMin, rig.WidthScaleMax, 4, 5),
		Depth = at(rig.WidthScaleMin, rig.WidthScaleMax, 9, 2),
		Head = 1,
	}
end

local function inRange(value: number, min: number, max: number): boolean
	return value >= min - 1e-6 and value <= max + 1e-6
end

local function outfit(
	role: Role,
	tier: number,
	index: number,
	shirt: Color3,
	longSleeves: boolean,
	pants: Color3,
	accessories: { AccessoryDef },
	scale: { Height: number, Width: number, Depth: number, Head: number }?
): OutfitDef
	return {
		OutfitId = string.format("%s%02d", role, index + 1),
		Role = role,
		Tier = tier,
		BodyColors = { Skin = pick(SKIN, index, 3), Shoes = pick(SHOES, index, 2) },
		Shirt = { Color = shirt, LongSleeves = longSleeves },
		Pants = { Color = pants },
		Accessories = accessories,
		Hair = { Style = pick(HAIR_STYLES, index, 5), Color = pick(HAIR_COLORS, index, 3) },
		Face = "Default",
		Scale = scale or scaleFor(index),
	}
end

-- Facial hair and glasses are chosen from the index too; they match the outfit's hair colour.
local function hairColorOf(index: number): Color3
	return pick(HAIR_COLORS, index, 3)
end

local function extras(index: number, glasses: number, mustache: number, beard: number): { AccessoryDef }
	local list: { AccessoryDef } = {}
	if index % glasses == 0 then
		table.insert(list, { Kind = "Glasses", Color = pick(FRAMES, index, 1) })
	end
	if index % mustache == 1 then
		table.insert(list, { Kind = "Mustache", Color = hairColorOf(index) })
	end
	if index % beard == 2 then
		table.insert(list, { Kind = "Beard", Color = hairColorOf(index) })
	end
	return list
end

local builders: { [Role]: (number) -> OutfitDef } = {
	Guest = function(index)
		local accessories: { AccessoryDef } = {}
		local accent = pick(ACCENTS, index, 5)
		local kind = index % 9
		if kind == 0 then
			table.insert(accessories, { Kind = "Tie", Color = accent })
		elseif kind == 1 then
			table.insert(accessories, { Kind = "BowTie", Color = accent })
		elseif kind == 2 then
			table.insert(accessories, { Kind = "Tie", Color = accent })
			table.insert(accessories, { Kind = "Glasses", Color = pick(FRAMES, index, 1) })
		elseif kind == 3 then
			table.insert(accessories, { Kind = "BowTie", Color = accent })
			table.insert(accessories, { Kind = "Mustache", Color = hairColorOf(index) })
		elseif kind == 4 then
			table.insert(accessories, { Kind = "Scarf", Color = accent })
		elseif kind == 5 then
			table.insert(accessories, { Kind = "Necklace", Color = pick(JEWELLERY, index, 1) })
		elseif kind == 6 then
			table.insert(accessories, { Kind = "Tie", Color = accent })
			table.insert(accessories, { Kind = "Beard", Color = hairColorOf(index) })
		elseif kind == 7 then
			table.insert(accessories, { Kind = "Glasses", Color = pick(FRAMES, index, 1) })
		end
		return outfit(
			"Guest",
			Enums.Tier.Public,
			index,
			pick(GUEST_JACKETS, index, 7),
			true,
			pick(GUEST_PANTS, index, 3),
			accessories
		)
	end,
	Staff = function(index)
		local suit = pick(STAFF_SUITS, index, 1)
		local green = tierColors[Enums.Tier.Staff]
		local accessories: { AccessoryDef } = {
			{ Kind = "Tie", Color = green },
			{ Kind = "Lapels", Color = green },
		}
		-- Most staff wear the black fedora; a few go bare-headed so a hat is not the only tell.
		if index % 4 ~= 3 then
			table.insert(accessories, { Kind = "Fedora", Color = BLACK })
		end
		for _, extra in extras(index, 5, 7, 9) do
			table.insert(accessories, extra)
		end
		return outfit("Staff", Enums.Tier.Staff, index, suit, true, pick(STAFF_TROUSERS, index, 1), accessories)
	end,
	Security = function(index)
		local suit = pick(SECURITY_SUITS, index, 1)
		local purple = tierColors[Enums.Tier.Security] -- dark purple
		local accessories: { AccessoryDef } = {
			{ Kind = "Tie", Color = purple },
			{ Kind = "Lapels", Color = purple },
			{ Kind = "Sunglasses", Color = BLACK },
		}
		if index % 4 == 0 then
			table.insert(accessories, { Kind = "Beard", Color = hairColorOf(index) })
		elseif index % 5 == 1 then
			table.insert(accessories, { Kind = "Mustache", Color = hairColorOf(index) })
		end
		return outfit("Security", Enums.Tier.Security, index, suit, true, suit, accessories)
	end,
	Executive = function(index)
		local suit = pick(EXECUTIVE_SUITS, index, 1)
		local gold = tierColors[Enums.Tier.Executive]
		local accessories: { AccessoryDef } = {
			{ Kind = "Tie", Color = gold },
			{ Kind = "Lapels", Color = gold },
			{ Kind = "PocketSquare", Color = gold },
			{ Kind = "LapelPin", Color = gold },
		}
		for _, extra in extras(index, 3, 5, 4) do
			table.insert(accessories, extra)
		end
		if index % 6 == 2 then
			table.insert(accessories, { Kind = "Scarf", Color = gold })
		end
		return outfit("Executive", Enums.Tier.Executive, index, suit, true, suit, accessories)
	end,
	-- The Tier 4 NPCs wear crimson with gold (one outfit each, so a scan copies exactly it).
	Warden = function(index)
		local crimson = tierColors[Enums.Tier.Sanctum]
		local gold = tierColors[Enums.Tier.Executive]
		return outfit("Warden", Enums.Tier.Sanctum, index, crimson, true, BLACK, {
			{ Kind = "Tie", Color = gold },
			{ Kind = "Lapels", Color = gold },
			{ Kind = "LapelPin", Color = gold },
			{ Kind = "Sunglasses", Color = BLACK },
		}, rig.WardenScale)
	end,
	Curator = function(index)
		local crimson = tierColors[Enums.Tier.Sanctum]
		local gold = tierColors[Enums.Tier.Executive]
		return outfit("Curator", Enums.Tier.Sanctum, index, BLACK, true, crimson, {
			{ Kind = "Tie", Color = gold },
			{ Kind = "Lapels", Color = crimson },
			{ Kind = "PocketSquare", Color = gold },
			{ Kind = "LapelPin", Color = gold },
		})
	end,
}

-- Roles with a single outfit (the Tier 4 NPCs); every other role has OUTFITS_PER_ROLE.
local SINGLE_OUTFIT: { [string]: boolean } = { Warden = true, Curator = true }

local byId: { [string]: OutfitDef } = {}
local byRole: { [Role]: { OutfitDef } } = {}

for role in Enums.Role do
	local build = builders[role :: Role]
	local list: { OutfitDef } = {}
	local single = SINGLE_OUTFIT[role]
	for index = 0, (if single then 1 else OUTFITS_PER_ROLE) - 1 do
		local def = build(index)
		assert(not byId[def.OutfitId], `Duplicate outfit id {def.OutfitId}`)
		-- Tier 4 is the one exception to the size ranges (SPEC_CHANGES 8.2)
		assert(
			def.Tier == Enums.Tier.Sanctum
				or inRange(def.Scale.Height, rig.HeightScaleMin, rig.HeightScaleMax)
					and inRange(def.Scale.Width, rig.WidthScaleMin, rig.WidthScaleMax)
					and inRange(def.Scale.Depth, rig.WidthScaleMin, rig.WidthScaleMax),
			"Outfit scale out of range"
		)
		byId[def.OutfitId] = def
		table.insert(list, def)
	end
	assert(
		single or #list >= GameConfig.NPC.MinOutfitsPerRole,
		`Role {role} needs at least {GameConfig.NPC.MinOutfitsPerRole} outfits`
	)
	byRole[role :: Role] = list
end

-- What an Exposed agent looks like (spec 6.1, 7.2). Agents get their own True Form in Step 16; until then everyone
-- shares this plain dark look, with no weapon and no uniform signature, so it reads as "not an NPC" at a glance.
local DARK = Color3.fromRGB(14, 14, 16)
local trueForm: OutfitDef = {
	OutfitId = "TrueForm",
	Role = "Guest", -- only to give it a walk speed class; Exposed players use GameConfig.Speeds.ExposedWalk
	Tier = Enums.Tier.Public, -- no clearance: any Tier 1+ zone is a trespass (spec 6.2)
	BodyColors = { Skin = SKIN[3], Shoes = DARK },
	Shirt = { Color = DARK, LongSleeves = true },
	Pants = { Color = DARK },
	Accessories = {},
	Hair = { Style = "Crop", Color = HAIR_COLORS[1] },
	Face = "Default",
	Scale = {
		Height = (rig.HeightScaleMin + rig.HeightScaleMax) / 2,
		Width = (rig.WidthScaleMin + rig.WidthScaleMax) / 2,
		Depth = (rig.WidthScaleMin + rig.WidthScaleMax) / 2,
		Head = 1,
	},
}
byId[trueForm.OutfitId] = trueForm

local byTier: { [number]: { OutfitDef } } = {}
for _, list in byRole do
	for _, def in list do
		byTier[def.Tier] = byTier[def.Tier] or {}
		table.insert(byTier[def.Tier], def)
	end
end

local OutfitDefs = {
	byId = byId,
	byRole = byRole,
	trueForm = trueForm,
}

function OutfitDefs.random(role: Role, rng: Random): OutfitDef
	local list = byRole[role]
	return list[rng:NextInteger(1, #list)]
end

-- A random outfit with this clearance tier (spec 6.2); used when an Exposed agent re-covers.
function OutfitDefs.randomForTier(tier: number, rng: Random): OutfitDef
	local list = byTier[tier]
	assert(list, `No outfits for tier {tier}`)
	return list[rng:NextInteger(1, #list)]
end

return DeepFreeze(OutfitDefs)
