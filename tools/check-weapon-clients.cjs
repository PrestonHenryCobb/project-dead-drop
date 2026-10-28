// Runs actual client action/event bodies with deterministic clock and engine fixtures.
// Usage: node tools/check-weapon-clients.cjs <official-luau-cli>
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const cp = require('node:child_process');
const root = path.resolve(__dirname, '..');
const read = p => fs.readFileSync(path.join(root, p), 'utf8');
function between(text, a, b) {
  const start = text.indexOf(a), end = text.indexOf(b, start);
  if (start < 0 || end < 0) throw Error(`Source boundary changed: ${a}`);
  return text.slice(start, end);
}
const controller = read('src/client/Controllers/WeaponController.luau');
const definitions = read('src/shared/Defs/WeaponDefs.luau');
const ids = ['GuiseGarrote','ParapetPump','ParapetHammer','SutureFlare','FeintSmokeSMG','FeintKnives'];
const entries = ids.map(id => {
  const start = definitions.indexOf(`addFirearm({\n\tId = "${id}"`);
  if (start < 0) throw Error(`Unregistered ${id}`);
  const end = definitions.indexOf('\n})', start);
  return definitions.slice(start, end + 3);
}).join('\n');
const effects = read('src/client/Combat/WeaponEffects.luau');
const modelBuilders = between(read('src/client/Combat/ViewModel.luau'), 'local function addPart(', 'function ViewModel.new(');
const effectConfig = between(read('src/shared/GameConfig.luau'), '\t\tWeaponEffects = {', '\t\t-- The hammer');
const reload = between(controller, 'local function advanceReload(', 'local function step(');
const melee = between(controller, 'local function onMelee(', 'local function resetWeapon(');
const ammo = between(controller, 'janitor:Add(RemoteController.connect("AmmoUpdate", function(info: Types.AmmoInfo)', '\n\tjanitor:Add(RemoteController.connect("CombatStatus"')
  .replace('janitor:Add(RemoteController.connect("AmmoUpdate", function(info: Types.AmmoInfo)', 'local function onAmmo(info)')
  .replace(/end\)\)\s*$/, 'end');
const fixture = `
local checks=0
local function check(value,message) assert(value,message) checks+=1 end
local mt={}
local function v(x,y,z) return setmetatable({X=x,Y=y,Z=z},mt) end
mt.__add=function(a,b)return v(a.X+b.X,a.Y+b.Y,a.Z+b.Z)end
mt.__sub=function(a,b)return v(a.X-b.X,a.Y-b.Y,a.Z-b.Z)end
mt.__mul=function(a,b) if type(a)=="number" then a,b=b,a end return v(a.X*b,a.Y*b,a.Z*b)end
mt.__index=function(a,k)
 if k=="Magnitude" then return math.sqrt(a.X*a.X+a.Y*a.Y+a.Z*a.Z) end
 if k=="Unit" then return a*(1/a.Magnitude) end
end
local Vector3={new=v,zero=v(0,0,0),one=v(1,1,1)}
local Color3={fromRGB=function(...)return {...}end}
local UDim2={fromScale=function(...)return {...}end}
local frame={}
local function cf(x,y,z) return setmetatable({Position=v(x or 0,y or 0,z or 0)},frame) end
frame.__mul=function(a,b)local p=a.Position+b.Position return cf(p.X,p.Y,p.Z)end
local CFrame={new=cf,Angles=function()return cf()end,identity=cf(),lookAt=function(at,to)return {Position=at,LookVector=(to-at).Unit}end}
local Enum={UserInputState={Begin=1,End=2,Cancel=3},ContextActionResult={Sink=1},Material={Neon=1,Metal=2,SmoothPlastic=3},PartType={Ball=1,Cylinder=2},SurfaceType={Smooth=1},HighlightDepthMode={Occluded=1}}
local objects={}
local Instance={new=function(class)
 local obj={ClassName=class,children={},attributes={}}
 function obj:Destroy() self.destroyed=true end
 function obj:IsA(kind) return self.ClassName==kind end
 function obj:FindFirstChild(name,recursive)
  if self.children[name] then return self.children[name]end
  for _,child in self.children do
   if child.Name==name then return child end
   if recursive then local found=child:FindFirstChild(name,true) if found then return found end end
  end
 end
 function obj:GetChildren()return self.children end
 function obj:IsDescendantOf(parent) return self.Parent==parent end
 function obj:SetAttribute(key,value)check(not self.character,"No attributes on characters")self.attributes[key]=value end
 function obj:GetAttribute(key)return self.attributes[key]end
 table.insert(objects,obj)
 return setmetatable(obj,{__newindex=function(self,key,value)
  if key=="Parent" and value and value.children then table.insert(value.children,self)end
  rawset(self,key,value)
 end})
end}
local now=100
local os={clock=function()return now end}
local wall=nil
local workspace={CurrentCamera={CFrame={Position=Vector3.zero}},GetServerTimeNow=function()return now end,
 Raycast=function()return wall end,FindFirstChild=function(self,id)return self[id]end}
local Players={LocalPlayer={WaitForChild=function()return {}end},GetPlayerByUserId=function(self,id)return self[id]end}
local RaycastParams={new=function()return {}end}
local GameConfig={Rig={CollisionGroup="Character"},Combat={HeadshotMult=1.5,Projectile={KnifeSize=v(.12,.12,1.1)}}}
local effectSettings={${effectConfig}}
GameConfig.Combat.WeaponEffects=effectSettings.WeaponEffects
local defs={}
local librarySounds={Fire="fire",Reload="reload",Empty="empty"}
local function addFirearm(def)defs[def.Id]=def end
${entries}
local WeaponDefs={byId=defs,get=function(id)return defs[id]end}
local combat={FireRateToleranceSeconds=.03,Feedback={ShotVolume=1},MaxShotStuds=300}
GameConfig.Combat.Feedback=combat.Feedback
GameConfig.Audio={DefaultWeaponRadius=120}
local def=defs.ParapetPump
local mag,reserve=2,12
local reloadEndsAt,reloadStartedAt=0,0
local predictedReloadPending,shellInterruptPending=false,false
local burstRemaining,nextFireAt,lastMeleeAt,lastEmptyAt=0,0,-math.huge,-math.huge
local meleePending,takedownActive,held,aiming=false,false,true,false
local recoilPitch,recoilYaw,spreadExtra,lastFireAt=0,0,0,0
local shotDirections={}
local streak={}
local viewModel=nil
local calls,sounds,predictions={},{},{}
local RemoteController={fire=function(...)table.insert(calls,{...})end}
local SoundPlayer={play=function(...)table.insert(sounds,{...})end,playAt=function(...)table.insert(sounds,{...})end}
local WeaponEffects={predict=function(...)table.insert(predictions,{...})end}
local rng={NextNumber=function()return 0 end}
local FIRE_NOISE_PITCH,EMPTY_CLICK_GAP=.04,.3
local function isReloading(t)return reloadEndsAt>t end
local function attackBlocked()return false end
local function currentSpread()return 0 end
local function spreadDirection()return v(0,0,-1)end
local WeaponCadence={gapAfterShot=function(d)return 60/d.RPM end}
local ShotFx={mapHit=function()return nil,nil end}
local ShotVisuals={fire=function()end}
local function cancelLocalMelee()end
local function character()return {},{}end
local UserInputService={GetFocusedTextBox=function()return nil end}
local function resetWeapon()end
local aimBlend=0
${reload}
${ammo}
${melee}
local camera={CFrame={Position=Vector3.zero}}
local function reset(id,m,r)
 def=defs[id] mag,reserve=m,r reloadEndsAt,reloadStartedAt=0,0
 predictedReloadPending,shellInterruptPending=false,false
 meleePending,takedownActive=false,false lastMeleeAt=-math.huge
 nextFireAt=0 table.clear(calls) table.clear(sounds) table.clear(predictions)
end
-- Shell progress, including a due shell before a fire interrupt.
startReload(now)
advanceReload(now+.49) check(mag==2,"Shell loaded early")
now+=.5 advanceReload(now) check(mag==3 and reserve==11,"One shell, not whole magazine")
fireOnce(camera,{},now)
check(mag==2 and shellInterruptPending and reloadEndsAt==0,"Interrupt prediction")
check(#calls==2 and calls[2][1]=="FireRequest" and #calls[2][3]==8,"Eight directions in one request")
onAmmo({Mag=3,Reserve=11,ReloadSeconds=0})
check(mag==2 and not shellInterruptPending,"Pre-shot stop must not refund shell")
-- Delayed positive shell updates cannot restart a reload after firing.
reset("ParapetPump",2,12) startReload(now) fireOnce(camera,{},now+.2)
onAmmo({Mag=2,Reserve=12,ReloadSeconds=.5})
check(reloadEndsAt==0 and mag==1,"Delayed loading event must not restart interrupted reload")
onAmmo({Mag=2,Reserve=12,ReloadSeconds=0}) check(mag==1,"Stop preserves consumed shell")
-- Rejected shot correction follows the pre-shot stop and restores true server count.
onAmmo({Mag=2,Reserve=12,ReloadSeconds=0}) check(mag==2,"Server rejection corrects prediction")
reset("ParapetPump",0,12) startReload(now) fireOnce(camera,{},now+.1)
check(#calls==1 and mag==0,"Empty pump must wait for first shell")
now+=.5 fireOnce(camera,{},now)
check(mag==0 and reserve==11 and shellInterruptPending,"Due first shell may be fired")
onAmmo({Mag=1,Reserve=11,ReloadSeconds=0}) check(mag==0,"Due-shell interrupt reconciliation")
reset("ParapetPump",5,1) startReload(now) now+=.5 advanceReload(now)
check(mag==6 and reserve==0 and reloadEndsAt==0,"Stop at full/out of reserve")
fireOnce(camera,{},now) onAmmo({Mag=6,Reserve=0,ReloadSeconds=0})
check(mag==5,"Late final-shell confirmation cannot refund shot")
for _,id in {"GuiseGarrote","ParapetHammer"} do
 reset(id,0,0) fireOnce(camera,{},now) startReload(now)
 check(#calls==0 and #sounds==0,"Melee weapon must send no fire/reload or empty sound")
 check(def.Melee~=nil and def.MagSize==0,"Melee registry contract")
 workspace.CurrentCamera=camera
 lastMeleeAt=now-def.Melee.SwingSeconds+.01
 onMelee("",Enum.UserInputState.Begin)
 check(#calls==0,"Per-weapon swing cooldown: "..id)
 lastMeleeAt=now-def.Melee.SwingSeconds-.001
 onMelee("",Enum.UserInputState.Begin) onMelee("",Enum.UserInputState.End)
 check(#calls==2 and calls[1][1]=="RequestMelee" and calls[2][2]=="Release","Melee input contract: "..id)
end
reset("FeintKnives",6,0) fireOnce(camera,{},now)
check(mag==5 and #calls==1 and #sounds==0 and #predictions==1,"Silent knife prediction")
startReload(now) check(#calls==1,"Knives have no reload")
reset("SutureFlare",1,12) fireOnce(camera,{},now)
check(#predictions==1 and mag==0 and #calls==2,"Flare launch plus reload")
reset("ParapetPump",6,12) lastMeleeAt=now fireOnce(camera,{},now+.64)
check(#calls==0 and #sounds==0,"Recovery gate precedes feedback")
fireOnce(camera,{},now+.65) check(#calls==1,"Recovery expires at per-weapon delay")
-- Exercise the actual effects module with engine instances/rays replaced only.
local effectModule=(function()
local config=GameConfig.Combat.WeaponEffects
${effects.slice(effects.indexOf('type Flight')).replace('return WeaponEffects', 'return {api=WeaponEffects,flights=flights,lights=lights,clouds=clouds,glows=glows}')}
end)()
local fx=effectModule.api
local cleanup={items={},Add=function(self,item)table.insert(self.items,item)end}
fx.start(cleanup)
fx.predict(defs.SutureFlare,v(0,5,0),v(0,0,-1))
local predicted=effectModule.flights[1].part
now+=.1
fx.launched({Id=41,Kind="Flare",Origin=v(0,5,0),Velocity=v(0,0,-70),Gravity=45,StartedAt=now,Own=true})
check(#effectModule.flights==1 and effectModule.flights[1].part==predicted,"Adopt own flare without duplicate")
now+=.2 fx.step()
check(math.abs(predicted.CFrame.Position.Z+14)<1e-8,"Flight follows server time")
check(math.abs(predicted.CFrame.Position.Y-4.1)<1e-8,"Flight follows server gravity")
fx.impact({Id=41,Position=v(1,2,3),LightUntil=now+5})
check(#effectModule.flights==0 and predicted.destroyed,"Impact stops flight")
check(#effectModule.lights==1 and effectModule.lights[1].expires==now+5,"Light uses authoritative expiry")
local heardBefore=#sounds
fx.launched({Id=42,Kind="Flare",Origin=v(0,5,0),Velocity=v(0,0,-70),Gravity=45,StartedAt=now,Own=false})
check(#sounds==heardBefore+1,"Remote flare launch audio")
fx.impact({Id=42,Position=v(0,0,0)})
fx.launched({Id=43,Kind="Knife",Origin=v(0,5,0),Velocity=v(0,0,-120),Gravity=25,StartedAt=now,Own=false})
check(#sounds==heardBefore+1,"Remote knives stay silent")
fx.impact({Id=43,Position=v(0,0,0)})
fx.smoke({Position=v(0,0,0),Radius=2,ExpiresAt=now+2})
check(#effectModule.clouds==1 and effectModule.clouds[1].part.Size.X==4,"Four-stud smoke diameter")
fx.step()
local veil=nil
for _,obj in objects do if obj.ClassName=="Frame" and obj.Parent and obj.Parent.Name=="WeaponSmoke" then veil=obj end end
check(veil and veil.Visible,"Smoke obscures camera inside cloud")
workspace.CurrentCamera.CFrame.Position=v(10,0,0) fx.step()
check(not veil.Visible,"No smoke veil outside cloud")
workspace.CurrentCamera.CFrame.Position=Vector3.zero
local target=Instance.new("Model") target.character=true target.children.HumanoidRootPart=Instance.new("BasePart")
target.children.HumanoidRootPart.Position=v(1,0,0)
Players[7]={Character=target}
fx.glow({TargetId="P7",ExpiresAt=now+4}) fx.step()
check(effectModule.glows[1].highlight.Adornee==target and effectModule.glows[1].highlight.Enabled,"Team glow resolves character")
wall={Instance=Instance.new("Part"),Position=v(0,0,0)} fx.step()
check(not effectModule.glows[1].highlight.Enabled,"Glow cannot see through walls") wall=nil
local replacement=Instance.new("Model") replacement.children.HumanoidRootPart=target.children.HumanoidRootPart
Players[7].Character=replacement fx.step()
check(effectModule.glows[1].highlight.Adornee==replacement,"Glow follows replacement disguise rig")
now+=2 fx.step() check(#effectModule.clouds==0,"Smoke expiry")
now+=2 fx.step() check(#effectModule.glows==0,"Glow expiry")
now+=1 fx.step() check(#effectModule.lights==0,"Light expiry")
fx.predict(defs.FeintKnives,v(0,0,0),v(0,0,-1))
now+=GameConfig.Combat.WeaponEffects.PredictionSeconds fx.step()
check(#effectModule.flights==0,"Rejected prediction expires")
for i=1,GameConfig.Combat.WeaponEffects.MaxClouds+3 do fx.smoke({Position=v(0,0,0),Radius=2,ExpiresAt=now+2}) end
check(#effectModule.clouds==GameConfig.Combat.WeaponEffects.MaxClouds,"Bounded cosmetic lifetime allocation")
for i=#cleanup.items,1,-1 do
 local item=cleanup.items[i] if type(item)=="function" then item()else item:Destroy()end
end
check(#effectModule.flights==0 and #effectModule.clouds==0,"Janitor clears effect state")
-- Actual shaped builders; transforms are structural fixtures, not a substitute for Studio framing QA.
local builders=(function()
local config={GunColor=Color3.fromRGB(40,40,40),AccentColor=Color3.fromRGB(180,140,60)}
local ArtSurface={apply=function()end}
${modelBuilders}
return builders
end)()
for _,id in {"GuiseGarrote","ParapetPump","ParapetHammer","SutureFlare","FeintSmokeSMG","FeintKnives"}do
 local model=Instance.new("Model")
 local right,left=builders[id](model)
 check(right~=nil and left~=nil,"Both hand grips: "..id)
 check(model:FindFirstChild("Receiver")~=nil,"Primary receiver: "..id)
 check(model:FindFirstChild("Muzzle",true)~=nil,"Attachment contract: "..id)
 for _,child in model:GetChildren()do
  check(child:GetAttribute("Offset")~=nil,"Part transform: "..id)
  check(child.Anchored and not child.CanCollide and not child.CanQuery,"Cosmetic collision: "..id)
 end
end
print("Weapon clients: "..checks.." actual-source assertions passed")
`;
const out = path.join(os.tmpdir(),'cover-story-weapon-clients.luau');
fs.writeFileSync(out, fixture);
const result = cp.spawnSync(process.argv[2] || 'luau',[out],{encoding:'utf8'});
process.stdout.write(result.stdout || '');
process.stderr.write(result.stderr || '');
if(result.error) throw result.error;
process.exitCode=result.status ?? 1;
