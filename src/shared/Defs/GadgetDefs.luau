--!strict
-- The sub-gadgets built so far (docs/GADGETS_DRAFT.md, SPEC_CHANGES 16.1). A gadget is added here as its step lands; the
-- numbers are in GameConfig.Gadgets.
--
--   GadgetDefs.byId["MedInjector"] -> GadgetDef
--   GadgetDefs.get(id) -> GadgetDef?
--   GadgetDefs.order -> { string } in menu order

local Shared = script.Parent.Parent
local DeepFreeze = require(Shared.Util.DeepFreeze)
local Types = require(Shared.Types)

type GadgetDef = Types.GadgetDef

local defs: { GadgetDef } = {
	{
		Id = "MedInjector",
		Name = "Med Injector",
		Category = "Support",
		Charges = 1,
		Description = "Heals 35 HP over 4 s, self only. Stops if you take damage.",
	},
	{
		Id = "PlatePack",
		Name = "Plate Pack",
		Category = "Support",
		Charges = 2,
		Description = "Restore 1 armour plate to yourself or a teammate you're touching. Takes 1.5 s, and you can't shoot meanwhile.",
	},
}

local byId: { [string]: GadgetDef } = {}
local order: { string } = {}
for _, def in defs do
	assert(not byId[def.Id], `Duplicate gadget {def.Id}`)
	byId[def.Id] = def
	table.insert(order, def.Id)
end

local GadgetDefs = {
	byId = byId,
	order = order,
}

function GadgetDefs.get(id: string): GadgetDef?
	return byId[id]
end

return DeepFreeze(GadgetDefs)
