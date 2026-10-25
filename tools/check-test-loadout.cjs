// Execute actual selector and production-guard source with Luau; no mirrored implementations.
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const cp = require('node:child_process');
const root = path.join(__dirname, '..');
const combat = fs.readFileSync(path.join(root, 'src/server/Services/CombatService.luau'), 'utf8');
const cycle = combat.slice(combat.indexOf('function CombatService.testCycle('), combat.indexOf('-- Read-only server-side Studio diagnostics'));
const getter = combat.slice(combat.indexOf('function CombatService.getTestWeaponId('), combat.indexOf('function CombatService.setDownedHooks('));
const helper = fs.readFileSync(path.join(root, 'src/shared/Util/TestLoadout.luau'), 'utf8');
const body = helper.slice(helper.indexOf('local TestLoadout ='));
if (!cycle || !getter || !body.startsWith('local TestLoadout =')) throw new Error('Source extraction failed');
const fixture = `
local RunService={IsStudio=function() return false end}
local CombatService={}
${cycle}
${getter}
for _,action in {"Agent","Weapon","Sync","ArbitraryWeaponId",{},false} do
    assert(CombatService.testCycle({},action)==false,"Non-Studio selection was accepted")
end
assert(CombatService.getTestWeaponId({})==nil,"Non-Studio diagnostics leaked state")
local GameConfig={Debug={TestLoadout={AgentOrder={"Alpha","Missing","Beta"}}}}
local WeaponDefs={byId={}}
local function def(id,agent) local value={Id=id,Agent=agent}; WeaponDefs.byId[id]=value; return value end
local a=def("AlphaA","Alpha")
local b=def("AlphaB","Alpha")
local z=def("BetaZ","Beta")
function WeaponDefs.get(id) return WeaponDefs.byId[id] end
local selector=(function()
${body}
end)()
assert(selector.nextWeapon("AlphaA","Weapon")==b)
assert(selector.nextWeapon("AlphaB","Weapon")==a)
assert(selector.nextWeapon("BetaZ","Weapon")==z)
assert(selector.nextWeapon("AlphaB","Agent")==z,"Empty kit was not skipped")
assert(selector.nextWeapon("BetaZ","Agent")==a,"Agent cycle did not wrap")
assert(selector.nextWeapon("AlphaB","Sync")==b)
assert(selector.nextWeapon("Missing","Weapon")==nil)
assert(selector.nextWeapon("AlphaA","ArbitraryWeaponId")==nil)
print("Test loadout: production guards and deterministic selector assertions passed")
`;
const file = path.join(os.tmpdir(), 'cover-story-test-loadout-regression.luau');
fs.writeFileSync(file, fixture);
const result = cp.spawnSync(process.argv[2] || 'luau', [file], { encoding: 'utf8' });
process.stdout.write(result.stdout || '');
process.stderr.write(result.stderr || '');
if (result.error) throw result.error;
process.exitCode = result.status ?? 1;
