--!strict
-- Picture slots for the menu (owner 2026-11-25). Every slot starts empty, and the menu draws a code-made placeholder in its place; put a Roblox image id
-- (rbxassetid://...) in a slot and that picture shows instead, with no code change. The pictures are meant to be replaced by generated art later.
--
--   MenuArtDefs.portrait(agentId) -> string?      a bust of the agent, for the roster thumbnail and the agent card
--   MenuArtDefs.hardware(hardwareId) -> string?   a picture of one Hardware item
--   MenuArtDefs.kit(itemId) -> string?            an icon for one Talent or Instinct

local portraits: { [string]: string } = {
	Guise = "",
	Parapet = "",
	Lattice = "",
	Reticle = "",
	Suture = "",
	Feint = "",
}

-- Hardware and kit items are listed by id as their art arrives; an id that is missing here has no picture yet.
local hardware: { [string]: string } = {}
local kit: { [string]: string } = {}

local function slot(list: { [string]: string }, id: string): string?
	local image = list[id]
	return if image and image ~= "" then image else nil
end

local MenuArtDefs = {}

function MenuArtDefs.portrait(agentId: string): string?
	return slot(portraits, agentId)
end

function MenuArtDefs.hardware(hardwareId: string): string?
	return slot(hardware, hardwareId)
end

function MenuArtDefs.kit(itemId: string): string?
	return slot(kit, itemId)
end

return MenuArtDefs
