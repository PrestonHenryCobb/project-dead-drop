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

local OUTFITS_PER_ROLE = 24

local SKIN = {
	Color3.fromRGB(255, 224, 189),
	Color3.fromRGB(241, 194, 143),
	Color3.fromRGB(224, 172, 105),
	Color3.fromRGB(198, 134, 66),
	Color3.fromRGB(141, 85, 36),
	Color3.fromRGB(90, 56, 37),
}
local HAIR_COLORS = {
	Color3.fromRGB(20, 18, 16),
	Color3.fromRGB(60, 38, 24),
	Color3.fromRGB(105, 66, 36),
	Color3.fromRGB(140, 60, 40),
	Color3.fromRGB(214, 180, 110),
	Color3.fromRGB(170, 170, 170),
}
local HAIR_STYLES: { Types.HairStyle } = { "Short", "Long", "Bun", "Crop", "Bald" }
local SHOES = { Color3.fromRGB(25, 25, 28), Color3.fromRGB(70, 45, 30), Color3.fromRGB(110, 20, 30) }

-- Formal jackets and trousers for guests.
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
}
local GUEST_PANTS =
	{ Color3.fromRGB(20, 20, 24), Color3.fromRGB(45, 45, 52), Color3.fromRGB(32, 38, 60), Color3.fromRGB(85, 70, 55) }
local ACCENTS = {
	Color3.fromRGB(190, 40, 50),
	Color3.fromRGB(230, 200, 80),
	Color3.fromRGB(230, 140, 60), -- not green: green ties and lapels are the Staff signature
	Color3.fromRGB(240, 240, 240),
	Color3.fromRGB(200, 120, 160),
}

local STAFF_SUITS = { Color3.fromRGB(62, 88, 138), Color3.fromRGB(56, 80, 128), Color3.fromRGB(68, 95, 145) }
local STAFF_TROUSERS = { Color3.fromRGB(48, 66, 108), Color3.fromRGB(44, 60, 100), Color3.fromRGB(52, 72, 116) }
local SECURITY_SUITS = { Color3.fromRGB(16, 16, 20), Color3.fromRGB(22, 22, 26), Color3.fromRGB(28, 28, 32) }
local EXECUTIVE_SUITS = { Color3.fromRGB(236, 228, 208), Color3.fromRGB(228, 222, 206), Color3.fromRGB(240, 234, 218) }
local BLACK = Color3.fromRGB(14, 14, 16)

local tierColors = GameConfig.Zones.TierColors

local function pick<T>(list: { T }, index: number, step: number): T
	return list[(index * step) % #list + 1]
end

-- Scale stays inside GameConfig.Rig for every outfit.
local function scaleFor(index: number): { Height: number, Width: number, Depth: number, Head: number }
	local span = GameConfig.Rig.ScaleMax - GameConfig.Rig.ScaleMin
	local function at(step: number, offset: number): number
		return GameConfig.Rig.ScaleMin + span * (((index * step + offset) % 5) / 4)
	end
	return { Height = at(1, 0), Width = at(2, 1), Depth = at(3, 2), Head = 1 }
end

local function outfit(
	role: Role,
	tier: number,
	index: number,
	shirt: Color3,
	longSleeves: boolean,
	pants: Color3,
	accessories: { AccessoryDef }
): OutfitDef
	return {
		OutfitId = string.format("%s%02d", role, index + 1),
		Role = role,
		Tier = tier,
		BodyColors = { Skin = pick(SKIN, index, 5), Shoes = pick(SHOES, index, 2) },
		Shirt = { Color = shirt, LongSleeves = longSleeves },
		Pants = { Color = pants },
		Accessories = accessories,
		Hair = { Style = pick(HAIR_STYLES, index, 3), Color = pick(HAIR_COLORS, index, 5) },
		Face = "Default",
		Scale = scaleFor(index),
	}
end

local builders: { [Role]: (number) -> OutfitDef } = {
	Guest = function(index)
		local accessories: { AccessoryDef } = {}
		local accent = pick(ACCENTS, index, 3)
		if index % 3 == 0 then
			table.insert(accessories, { Kind = "Tie", Color = accent })
		elseif index % 3 == 1 then
			table.insert(accessories, { Kind = "BowTie", Color = accent })
		end
		return outfit(
			"Guest",
			Enums.Tier.Public,
			index,
			pick(GUEST_JACKETS, index, 1),
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
		return outfit("Staff", Enums.Tier.Staff, index, suit, true, pick(STAFF_TROUSERS, index, 1), accessories)
	end,
	Security = function(index)
		local suit = pick(SECURITY_SUITS, index, 1)
		local purple = tierColors[Enums.Tier.Security] -- dark purple
		return outfit("Security", Enums.Tier.Security, index, suit, true, suit, {
			{ Kind = "Tie", Color = purple },
			{ Kind = "Lapels", Color = purple },
			{ Kind = "Sunglasses", Color = BLACK },
		})
	end,
	Executive = function(index)
		local suit = pick(EXECUTIVE_SUITS, index, 1)
		local gold = tierColors[Enums.Tier.Executive]
		return outfit("Executive", Enums.Tier.Executive, index, suit, true, suit, {
			{ Kind = "Tie", Color = gold },
			{ Kind = "Lapels", Color = gold },
			{ Kind = "PocketSquare", Color = gold },
			{ Kind = "LapelPin", Color = gold },
		})
	end,
}

local byId: { [string]: OutfitDef } = {}
local byRole: { [Role]: { OutfitDef } } = {}

for role in Enums.Role do
	local build = builders[role :: Role]
	local list: { OutfitDef } = {}
	for index = 0, OUTFITS_PER_ROLE - 1 do
		local def = build(index)
		assert(not byId[def.OutfitId], `Duplicate outfit id {def.OutfitId}`)
		for _, scale in def.Scale do
			assert(
				scale >= GameConfig.Rig.ScaleMin - 1e-6 and scale <= GameConfig.Rig.ScaleMax + 1e-6,
				"Outfit scale out of range"
			)
		end
		byId[def.OutfitId] = def
		table.insert(list, def)
	end
	assert(
		#list >= GameConfig.NPC.MinOutfitsPerRole,
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
	Scale = { Height = 1, Width = 1, Depth = 1, Head = 1 },
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
