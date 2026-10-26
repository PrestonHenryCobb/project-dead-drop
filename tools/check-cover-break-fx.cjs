// Exercise actual effect construction/timing/lifecycle with small GUI dependency fixtures; no Roblox app changes.
const fs = require('node:fs');
const cp = require('node:child_process');
const os = require('node:os');
const path = require('node:path');
const source = fs.readFileSync(path.join(__dirname, '../src/client/Combat/CoverBreakFx.luau'), 'utf8');
const body = source.slice(source.indexOf('local config ='));
const fixture = `
local GameConfig={UI={CoverBreak={Seconds=.2,StartTransparency=.2,EdgeInsetFraction=.16,ArmPixels=34,StrokePixels=3},CoverColors={Exposed="red"}}}
local HudScale={bind=function() end}
local allocated=0
local Instance={new=function(class)
 allocated+=1
 return {ClassName=class,Destroy=function(self) self.destroyed=true end}
end}
local Vector2={new=function(x,y) return {X=x,Y=y} end}
local UDim2={fromScale=function(x,y) return {X=x,Y=y} end,fromOffset=function(x,y) return {X=x,Y=y} end}
local fx=(function()\n${body}\nend)()
assert(fx.transparency(-1,false)==1)
assert(fx.transparency(0,false)==.2)
assert(math.abs(fx.transparency(.1,false)-.6)<.00001)
assert(fx.transparency(.2,false)==1 and fx.transparency(5,false)==1)
assert(fx.transparency(0,true)==1)
local effect=fx.new({})
assert(#effect.bars==8 and effect.root.BackgroundTransparency==1 and not effect.root.Visible,"Effect filled the aiming area")
local initial=allocated
for i=1,100 do
 effect:trigger(i)
 effect:update(i,false)
 assert(effect.root.Visible and effect.bars[1].BackgroundTransparency==.2)
 effect:update(i+.1,true)
 assert(not effect.root.Visible,"Reduce Motion did not hide geometry")
 effect:update(i+.3,false)
 assert(not effect.root.Visible,"Effect did not expire")
end
assert(allocated==initial,"Per-event/frame GUI allocation")
effect:trigger(200); effect:update(200,false); effect:reset()
assert(not effect.root.Visible and effect.startedAt==-math.huge,"Respawn reset retained feedback")
effect:destroy(); assert(effect.root.destroyed)
print("Cover-break FX: actual-source timeline, eight prebuilt fragments, 100 allocation-free pulses, reduced motion, expiry and reset passed")
`;
const file = path.join(os.tmpdir(), 'cover-story-cover-break-fx.luau');
fs.writeFileSync(file, fixture);
const result = cp.spawnSync(process.argv[2] || 'luau', [file], { encoding: 'utf8' });
process.stdout.write(result.stdout || '');
process.stderr.write(result.stderr || '');
if (result.error) throw result.error;
process.exitCode = result.status ?? 1;
