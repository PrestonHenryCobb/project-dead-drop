// Cold-loads the entire real config/agent/weapon modules, then checks HUD regions using actual config and scale math.
// Roblox datatype constructors are structural fixtures. Usage: node tools/check-client-data.cjs <official-luau-cli>
const fs=require('node:fs'),path=require('node:path'),os=require('node:os'),cp=require('node:child_process');
const root=path.resolve(__dirname,'..'),read=p=>fs.readFileSync(path.join(root,p),'utf8');
function importsRemoved(source){return source.replace(/^local Shared = .*\r?\n/gm,'').replace(/^local ReplicatedStorage = game:GetService\([^\n]+\)\r?\n/gm,'').replace(/^local (?:DeepFreeze|Types|GameConfig|AgentDefs|HudTheme|Janitor) = require\([^\n]+\)\r?\n/gm,'');}
const config=importsRemoved(read('src/shared/GameConfig.luau'));
const agents=importsRemoved(read('src/shared/Defs/AgentDefs.luau'));
const weapons=importsRemoved(read('src/shared/Defs/WeaponDefs.luau'));
const theme=importsRemoved(read('src/shared/Util/HudTheme.luau'));
const layout=importsRemoved(read('src/client/Combat/HudLayout.luau'));
const scale=importsRemoved(read('src/shared/Util/HudScale.luau'));
const disguise=read('src/client/Controllers/DisguiseController.luau');
const toastStart=disguise.indexOf('local function showToast('),toastEnd=disguise.indexOf('local function roleOf(',toastStart);
if(toastStart<0||toastEnd<0)throw Error('Toast function boundary changed');
const view=read('src/client/Combat/ViewModel.luau');
const builderStart=view.indexOf('local builders:'),builderEnd=view.indexOf('function ViewModel.new(',builderStart);
if(builderStart<0||builderEnd<0)throw Error('ViewModel registry changed');
const builders=[...view.slice(builderStart,builderEnd).matchAll(/^\t(\w+) =/gm)].map(m=>`["${m[1]}"]=true`).join(',');
const badCases=[['ParapetPump','ParapetShotgun'],['SutureFlare','SutureFlarePistol']].map(([good,bad])=>{
 if(!agents.includes(`Id = "${good}"`))throw Error('Regression fixture anchor changed');
 return `do local correct=AgentDefs AgentDefs=(function()${agents.replace(`Id = "${good}"`,`Id = "${bad}"`)}end)()
 local ok=pcall(function()return (function()${weapons}end)()end)
 check(not ok,"Former boot-breaking ID ${bad} must fail the cold-load check") AgentDefs=correct end`;
}).join('\n');
const harness=`
local count=0
local function check(value,message)assert(value,message)count+=1 end
local function enum(path)
 return setmetatable({_path=path},{__index=function(t,key)local value=enum(path.."."..key)rawset(t,key,value)return value end})
end
local Enum=enum("Enum")
local Color3={new=function(...)return {...}end,fromRGB=function(...)return {...}end,fromHex=function(s)return {Hex=s}end}
local Vector3={new=function(x,y,z)return {X=x,Y=y,Z=z}end,zero={X=0,Y=0,Z=0}}
local Vector2={new=function(x,y)return {X=x,Y=y}end}
local CFrame={new=function(...)return {Position={...}}end}
local UDim2={new=function(...)return {...}end,fromOffset=function(...)return {...}end}
local NumberRange={new=function(a,b)return {Min=a,Max=b}end}
local Types={}
local DeepFreeze=(function()${read('src/shared/Util/DeepFreeze.luau')}end)()
local GameConfig=(function()${config}end)()
local AgentDefs=(function()${agents}end)()
local WeaponDefs=(function()${weapons}end)()
local Pending=(function()${read('src/server/Tools/PendingWeaponDefs.luau')}end)()
local models={${builders}}
local built,missing=0,0
local allowedMissing={LatticeBurstRifle=true,LatticeTaser=true}
check(#AgentDefs.order==6,"Six defined agents")
for _,agentId in AgentDefs.order do
 local hardware=WeaponDefs.getForAgent(agentId)
 check(#hardware==3,"Three Hardware slots per agent")
 check(hardware[1].Def~=nil,"Default Hardware must be playable")
 for slot,item in hardware do
  check(item.Slot==slot and item.Agent==agentId,"Slot/agent contract")
  check(item.UnlockMasteryLevel==GameConfig.Mastery.HardwareUnlockLevels[slot],"Mastery from actual config")
  if item.Def then
   local def=item.Def built+=1
   check(def.Id==item.Id and def==WeaponDefs.get(item.Id),"Menu and combat share the same definition")
   check(WeaponDefs.isValidForAgent(agentId,item.Id),"Own Hardware valid")
   check(models[def.Id]==true,"Every selectable weapon has a shaped model")
   check(def.PostMeleeFireDelay~=nil and def.PostMeleeFireDelay>=0,"Per-weapon recovery")
   if def.Melee then check(def.MagSize==0 and def.ReserveAmmo==0 and def.ReloadSeconds==0,"No melee ammo/reload")end
   if def.Projectile then check(not def.Pellets and def.Projectile.Speed>0 and def.Projectile.MaxSeconds>0,"Projectile contract")end
   if def.Pellets then check(def.Pellets>=1 and def.Pellets%1==0,"Integral pellet request size")end
   for _,other in AgentDefs.order do if other~=agentId then check(not WeaponDefs.isValidForAgent(other,item.Id),"No cross-agent equip")end end
  else missing+=1 check(allowedMissing[item.Id]==true,"Unexpected unavailable Hardware")end
 end
end
check(missing==2,"Only the two server-pending Lattice weapons remain unavailable")
check(next(Pending)==nil,"Migrated six weapons are not still pending")
check(#WeaponDefs.getForAgent("unknown")==0 and WeaponDefs.get("unknown")==nil,"Unknown lookup is safe")
check(not WeaponDefs.isValidForAgent("Guise","unknown"),"Unknown Hardware cannot be equipped")
check(table.isfrozen(WeaponDefs.byId) and table.isfrozen(WeaponDefs.getForAgent("Guise")),"Cold load freezes registries")
local immutable=pcall(function()WeaponDefs.get("GuiseSMG").Damage=999 end)
check(not immutable,"Definitions cannot be mutated")
${badCases}
local HudTheme=(function()${theme}end)()
local HudLayout=(function()${layout}end)()
local Janitor={}
local HudScale=(function()${scale}end)()
local function rectangle(region,w,h,factor)
 local width,height=region.Width*factor,region.Height*factor
 local x=if region.Edge=="Left"then region.Offset*factor elseif region.Edge=="Right"then w-(region.Offset+region.Width)*factor else w/2-width/2
 return {x=x,y=region.Top*factor,w=width,h=height}
end
local function overlap(a,b)return a.x<b.x+b.w and b.x<a.x+a.w and a.y<b.y+b.h and b.y<a.y+a.h end
for _,skin in {"Gala","neutral"}do
 local regions=HudLayout.regions(HudTheme.get(skin))
 for _,size in {{1280,720},{1600,900},{1920,1080},{2560,1440},{3440,1440}}do
  local factor=HudScale.factor({X=size[1],Y=size[2]})
  local rects={}
  for name,region in regions do
   local r=rectangle(region,size[1],size[2],factor)rects[name]=r
   check(r.x>=0 and r.y>=0 and r.x+r.w<=size[1] and r.y+r.h<=size[2],"HUD region in viewport: "..name)
  end
  for name,a in rects do for other,b in rects do
   if name<other then check(not overlap(a,b),"HUD collision: "..name.." / "..other)end
  end end
  local position=HudLayout.position(regions.Exposure)
  check(position[1]==1 and position[2]<0,"Exposure uses right-column anchor")
 end
end
local toast={Parent={},Visible=false}
local toastToken=0
local ui=GameConfig.UI
local callbacks={}
local task={delay=function(_,callback)table.insert(callbacks,callback)end}
${disguise.slice(toastStart,toastEnd)}
showToast("First scan")check(toast.Visible and toast.TextTransparency==0,"Toast becomes visible")
showToast("Disguise stored")callbacks[1]()
check(toast.Visible and toast.Text=="Disguise stored","Old expiry cannot hide new toast")
callbacks[2]()check(not toast.Visible,"Toast backdrop hides with the text")
showToast("Late notification")toast.Parent=nil
local before=toast.TextTransparency callbacks[3]()
check(toast.TextTransparency==before,"Expired UI callback ignores removed toast")
print("Client data: "..count.." actual-source assertions passed; "..built.." registered weapons cold-loaded")
`;
const out=path.join(os.tmpdir(),'cover-story-client-data.luau');fs.writeFileSync(out,harness);
const result=cp.spawnSync(process.argv[2]||'luau',[out],{encoding:'utf8'});process.stdout.write(result.stdout||'');process.stderr.write(result.stderr||'');if(result.error)throw result.error;process.exitCode=result.status??1;
