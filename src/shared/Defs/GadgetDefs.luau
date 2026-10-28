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
		Id = "BriefcaseShield",
		Name = "Briefcase Shield",
		Category = "Support",
		Charges = 1,
		Description = "Hold an armoured briefcase (80 HP) in front of you for up to 5 s. You walk at 70%, can't sprint or shoot. Breaks Cover.",
	},
	{
		Id = "ScannerPulse",
		Name = "Scanner Pulse",
		Category = "Recon",
		Charges = 2,
		Description = "Shows every enemy agent within 20 studs, disguised or not, for 2 s. They are only told they were scanned.",
	},
	{
		Id = "BugCam",
		Name = "Bug Cam",
		Category = "Recon",
		Charges = 2,
		Description = "A sticky camera you can view with a key, for 60 s. Agents who break Cover in its view are tagged for your team.",
	},
	{
		Id = "Tripwire",
		Name = "Tripwire",
		Category = "Recon",
		Charges = 2,
		Description = "A thin laser across a way for 90 s. An enemy agent who crosses it is shown to your team and slowed. NPCs pass.",
	},
	{
		Id = "LongLens",
		Name = "Long Lens",
		Category = "Infiltration",
		Charges = 3,
		Description = "Hack an Intel station, camera or keycard door in sight up to 30 studs away, taking 1.5 times as long.",
	},
	{
		Id = "KeycardClone",
		Name = "Keycard Clone",
		Category = "Infiltration",
		Charges = 1,
		Description = "Opens one keycard door in reach, silently.",
	},
	{
		Id = "Jammer",
		Name = "Jammer",
		Category = "Infiltration",
		Charges = 1,
		Description = "For 20 s in a 15 stud radius, cameras and laser grids go dark and enemy deployables are disabled.",
	},
	{
		Id = "SpringPad",
		Name = "Spring Pad",
		Category = "Evasion",
		Charges = 2,
		Description = "A flat pad that throws anyone who steps on it about 25 studs up and forward. Lasts 30 s or 6 throws. Aim recalls it.",
	},
	{
		Id = "NoiseMaker",
		Name = "Noise Maker",
		Category = "Evasion",
		Charges = 2,
		Description = "After 3 s it sounds a loud alarm-like noise for 6 s. Guards within 30 studs come to look; other NPCs turn.",
	},
	{
		Id = "DisguiseKit",
		Name = "Disguise Kit",
		Category = "Evasion",
		Charges = 1,
		Description = "Instantly put on a Guest disguise without scanning anyone. Not while tracked, in combat lockout, or carrying the Package.",
	},
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
