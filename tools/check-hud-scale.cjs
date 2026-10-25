// Run actual scale-factor source with Luau. Native layout/spacing assertions are in CheckHudScale.luau.
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const cp = require('node:child_process');
const root = path.join(__dirname, '..');
const source = fs.readFileSync(path.join(root, 'src/shared/Util/HudScale.luau'), 'utf8');
const start = source.indexOf('function HudScale.factor(');
const end = source.indexOf('-- A container reference');
if (start < 0 || end < start) throw new Error('HudScale source extraction failed');
const configSource = fs.readFileSync(path.join(root, 'src/shared/GameConfig.luau'), 'utf8');
const config = configSource.match(/PanelScale\s*=\s*\{([\s\S]*?)\n\s*\},/);
if (!config) throw new Error('Missing canonical panel scale config');
const harness = `
local config={${config[1]}}
local HudScale={}
${source.slice(start, end)}
local count=0
for _,case in {
    {1280,720,1}, {1600,900,1.25}, {1920,1080,1.5}, {2560,1440,2},
    {3840,2160,2}, {3440,1440,2}, {2560,720,1}, {1280,1080,1},
    {960,540,1}, {0,0,1},
} do
    local actual=HudScale.factor({X=case[1],Y=case[2]})
    assert(math.abs(actual-case[3])<0.0001,"Wrong HUD factor")
    count+=1
end
print("HUD scale: "..count.." actual-source viewport assertions passed")
`;
const file = path.join(os.tmpdir(), 'cover-story-hud-scale-check.luau');
fs.writeFileSync(file, harness);
const result = cp.spawnSync(process.argv[2] || 'luau', [file], { encoding: 'utf8' });
process.stdout.write(result.stdout || '');
process.stderr.write(result.stderr || '');
if (result.error) throw result.error;
process.exitCode = result.status ?? 1;
