// Exercise the actual route variation code with floor/wall/tier rejection fixtures.
const fs = require('node:fs');
const cp = require('node:child_process');
const path = require('node:path');
const os = require('node:os');
const source = fs.readFileSync(path.join(__dirname, '../src/server/NPC/CrowdPath.luau'), 'utf8');
const body = source.slice(source.indexOf('local config ='));
const fixture = `
local GameConfig={NPC={WalkVariation={OffsetMin=.35,OffsetMax=.8,WaveStuds={Min=18,Max=30},MaxRiseStuds=.08,StraightDot=.98}}}
local V={}
function V.new(x,y,z) return setmetatable({X=x,Y=y,Z=z},V) end
V.__add=function(a,b) return V.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
V.__sub=function(a,b) return V.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
V.__mul=function(a,b) return V.new(a.X*b,a.Y*b,a.Z*b) end
V.__index=function(a,key)
 if key=="Magnitude" then return math.sqrt(a.X*a.X+a.Y*a.Y+a.Z*a.Z) end
 if key=="Unit" then return a*(1/a.Magnitude) end
 return V[key]
end
function V:Dot(b) return self.X*b.X+self.Y*b.Y+self.Z*b.Z end
local Vector3=V
local vary=(function()\n${body}\nend)().vary
local rng={NextNumber=function(_,a,b) return (a+b)/2 end,NextInteger=function() return 1 end}
local points={}
for i=0,40 do table.insert(points,V.new(i,0,0)) end
local out=vary(points,rng,function(_,to) return to end)
assert(out[1]==points[1] and out[#out]==points[#points],"Route endpoints moved")
assert(math.abs(out[6].Z)>.1,"Open-floor path stayed linear")
for i,p in out do
 assert(math.abs(p.Z)<=.8 and p.Y==0,"Bend exceeded lateral/floor budget")
 assert(points[i].Z==0,"Original cached route mutated")
end
local denied=vary(points,rng,function() return nil end)
for i,p in denied do assert(p==points[i],"Blocked/unsupported/restricted path was changed") end
local stairs={}
for i=0,20 do table.insert(stairs,V.new(i,i*.4,0)) end
local unchanged=vary(stairs,rng,function() error("Stair segment was offered a lateral bend") end)
for i,p in unchanged do assert(p==stairs[i]) end
local partial=vary(points,rng,function(_,to) if to.X>15 and to.X<25 then return nil end return to end)
for i=17,25 do assert(partial[i]==points[i],"Rejected region was entered") end
local raised=vary(points,rng,function(_,to) return to+V.new(0,1,0) end)
for i,p in raised do assert(p==points[i],"Different floor was accepted") end
print("Crowd path: open bends, immutable routes, endpoints, rejected regions, stairs and floor-height guards passed")
`;
const file = path.join(os.tmpdir(), 'cover-story-crowd-path.luau');
fs.writeFileSync(file, fixture);
const result = cp.spawnSync(process.argv[2] || 'luau', [file], { encoding: 'utf8' });
process.stdout.write(result.stdout || '');
process.stderr.write(result.stderr || '');
if (result.error) throw result.error;
process.exitCode = result.status ?? 1;
