// Run: node tools/check-melee.cjs <path-to-official-luau-cli>
// Executes actual shared rules and server action bodies; fixtures replace engine/services, not combat decisions.
const fs = require('fs');
const path = require('path');
const os = require('os');
const { execFileSync } = require('child_process');

const runtime = process.argv[2];
if (!runtime) throw new Error('Usage: node tools/check-melee.cjs <path-to-luau>');
const root = path.resolve(__dirname, '..');
const read = name => fs.readFileSync(path.join(root, name), 'utf8');
const output = fs.mkdtempSync(path.join(os.tmpdir(), 'cover-story-melee-'));
const write = (name, value) => fs.writeFileSync(path.join(output, name), value);
function between(source, start, end) {
  const a = source.indexOf(start);
  const b = source.indexOf(end, a);
  if (a < 0 || b < 0) throw new Error(`Source boundary changed: ${start}`);
  return source.slice(a, b);
}
const config = between(read('src/shared/GameConfig.luau'), '\tCombat = {', '\t-- Spec 24: Interact is held');
write('MeleeConfig.luau', `local Vector3={new=function(...)return {...}end,zero={}}
local Color3={fromRGB=function(...)return {...}end}
return {
${config}
}
`);
const importText = 'require(script.Parent.Parent.GameConfig)';
const rules = read('src/shared/Util/MeleeRules.luau');
if (!rules.includes(importText)) throw new Error('MeleeRules config import changed');
write('MeleeRulesActual.luau', rules.replace(importText, 'require("./MeleeConfig")'));
const server = read('src/server/Services/CombatService.luau');
const helpers = between(server, 'local function sendMelee(', 'local function isDowned(');
const damage = between(server, 'local function damagePlayer(', 'local function falloffMult(');
const actions = between(server, '\n-- Melee and takedowns ', '\n-- Spawning and falling ');
const imports = `local e=require("./MeleeFixture")
local MeleeRules=require("./MeleeRulesActual")
local config=e.config.Combat
local states=e.states
local workspace=e.workspace
local RemoteService=e.RemoteService
local TeamService=e.TeamService
local CoverService=e.CoverService
local NPCService=e.NPCService
local DisguiseService=e.DisguiseService
local History=e.History
local Vector3=e.Vector3
local os=e.os
local typeof=e.typeof
local aliveParts=e.aliveParts
local isDowned=e.isDowned
local downedHooks=nil
local mapParams={}
local function sendHealth() end
`;
write('MeleeServiceActual.luau', imports + helpers + damage + actions +
  '\nreturn{request=onMelee,check=checkTakedowns,damage=applyDamage}\n');
write('MeleeFixture.luau', read('tools/tests/melee/Fixture.luau'));
write('run-melee.luau', read('tools/tests/melee/Assertions.luau'));
execFileSync(runtime, ['run-melee.luau'], { cwd: output, stdio: 'inherit' });
