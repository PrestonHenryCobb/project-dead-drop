// Execute the real optical FOV function with Luau, across supported base FOVs and legacy zooms.
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const cp = require('node:child_process');
const source = fs.readFileSync(path.join(__dirname, '../src/client/Combat/WeaponAim.luau'), 'utf8');
const harness = `local aim=(function()\n${source}\nend)()
local count=0
for _,base in {60,70,75,85,100} do
    local scoped=aim.fov(base,1/3,3)
    local ratio=math.tan(math.rad(base)/2)/math.tan(math.rad(scoped)/2)
    assert(math.abs(ratio-3)<0.00001,"Optical magnification changed with base FOV")
    for _,legacy in {0.85,0.88,0.9,1} do
        assert(aim.fov(base,legacy,nil)==base*legacy,"Legacy gun zoom changed")
        count+=1
    end
    count+=1
end
print("Weapon aim: "..count.." actual-source FOV assertions passed")`;
const file = path.join(os.tmpdir(), 'cover-story-weapon-aim-check.luau');
fs.writeFileSync(file, harness);
const result = cp.spawnSync(process.argv[2] || 'luau', [file], { encoding: 'utf8' });
process.stdout.write(result.stdout || '');
process.stderr.write(result.stderr || '');
if (result.error) throw result.error;
process.exitCode = result.status ?? 1;
