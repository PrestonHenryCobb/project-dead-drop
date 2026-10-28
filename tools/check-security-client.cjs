// Execute actual 14b feed/HUD/alarm source with engine datatype and service fixtures.
const fs=require('node:fs'),path=require('node:path'),os=require('node:os'),cp=require('node:child_process');
const read=p=>fs.readFileSync(path.join(__dirname,'..',p),'utf8');
function between(s,a,b){const i=s.indexOf(a),j=s.indexOf(b,i);if(i<0||j<0)throw Error(a);return s.slice(i,j);}
function after(s,a){const i=s.indexOf(a);if(i<0)throw Error(a);return s.slice(i);}
const uiFixture=between(read('tools/check-match-client.cjs'),'local objects={}','local Accessibility=');
const config=between(read('src/shared/GameConfig.luau'),'\tSecurityHud = {','\n\t-- Spec 18: security systems.');
const feed=after(read('src/client/Combat/SecurityFeeds.luau'),'local SecurityFeeds =');
const hud=after(read('src/client/Controllers/SecurityHudController.luau'),'local SecurityHudController =');
const cover=read('src/client/Controllers/CoverController.luau');
const alarmBuild=between(cover,'\tlocal alarmPanel =','\n\t-- Ticket HUD refresh:');
const alarmRefresh=between(cover,'\tif alarmLabel then','\n\tlocal lockout =');
for(const [file,label]of [['CameraService','Hack camera'],['CameraService','Camera Room'],['LaserService','Cut power'],['SecurityService','Pick lock']])if(!read('src/server/Services/'+file+'.luau').includes('label = "'+label+'"'))throw Error('Server label changed: '+label);
const harness=`
local checks=0 local function check(v,msg)assert(v,msg)checks+=1 end
local now=100 local os={clock=function()return now end}
local vm={}local function v(x,y,z)return setmetatable({X=x,Y=y,Z=z},vm)end
vm.__sub=function(a,b)return v(a.X-b.X,a.Y-b.Y,a.Z-b.Z)end
vm.__add=function(a,b)return v(a.X+b.X,a.Y+b.Y,a.Z+b.Z)end
vm.__index=function(a,k)if k=="Magnitude"then return math.sqrt(a.X*a.X+a.Y*a.Y+a.Z*a.Z)end end
local Vector3={new=v}local Vector2={new=function(...)return {...}end,zero={}}
local cm={}local function cf(x,y,z)return setmetatable({Position=v(x or 0,y or 0,z or 0)},cm)end
cm.__mul=function(a,b)return cf(a.Position.X+b.Position.X,a.Position.Y+b.Position.Y,a.Position.Z+b.Position.Z)end
local CFrame={new=cf}
local UDim2={new=function(...)return {...}end,fromScale=function(...)return {...}end,fromOffset=function(...)return {...}end}
local Color3={fromRGB=function(...)return {...}end}
local Enum={KeyCode={F6={Name="F6"},DPadRight={Name="DPadRight"}},TextXAlignment={Left=1},UserInputState={Begin="Begin"},ContextActionResult={Sink="Sink",Pass="Pass"}}
local GameConfig={Security={Camera={ConeDegrees=60},CameraRoom={Feeds=4,InteractStuds=8},Alarm={MaxLevel=3}},Rig={CollisionGroup="Bodies"},Controls={Interact={Name="E"},InteractPad={Name="X"}}}
GameConfig.SecurityHud=({${config}}).SecurityHud
${uiFixture}
theme.PaddingPixels=12 theme.MarginPixels=16 theme.CaptionSize=12 theme.ActionWidthPixels=252 theme.ActionHeightPixels=58 theme.ActionOffsetPixels=112 theme.Font=1 theme.PanelColor={} theme.PanelTransparency=.2 theme.AccentColor={} theme.IconPixels=18 theme.VitalsWidthPixels=248 theme.CoverHeightPixels=60
local graphics=theme local ui={WarningColor={},ScanRingDimColor={}}
local layout={Alarm={Width=248,Height=60}}
local HudLayout={position=function()return {}end,anchor=function()return {}end}
HudKit.icon=function()end
local oldText=HudKit.text
HudKit.text=function(parent,name,position,anchor,size)local o=oldText(parent,name)o.Position=position o.Size=size return o end
local originalNew=Instance.new
Instance.new=function(class)
 local o=originalNew(class)o.Activated=signal()o.attrs={}o.tags={}o.Enabled=true
 function o:GetAttributes()return table.clone(self.attrs)end
 function o:GetAttribute(k)return self.attrs[k]end
 function o:SetAttribute(k,value)assert(self.copy,"Must not decorate source parts")self.attrs[k]=value end
 function o:GetChildren()return self.children end
 function o:GetDescendants()local out={}local function scan(p)for _,c in p.children do table.insert(out,c)scan(c)end end scan(self)return out end
 function o:ClearAllChildren()for _,c in self.children do c:Destroy()end self.children={}end
 function o:IsDescendantOf(p)local cursor=self.Parent while cursor do if cursor==p then return true end cursor=cursor.Parent end return false end
 function o:IsA(k)return self.ClassName==k or (k=="BasePart"and self.ClassName=="Part")end
 function o:Clone()
  local out=Instance.new(self.ClassName)out.copy=true out.Name=self.Name out.attrs=table.clone(self.attrs)out.tags=table.clone(self.tags)
  for _,k in {"Position","CFrame","Size","Color","Material","Transparency"}do out[k]=self[k]end
  for _,child in self.children do child:Clone().Parent=out end return out
 end
 return o
end
local root=Instance.new("Part")root.Position=v(0,0,0)
local humanoid={Health=100}
local player={Character={FindFirstChild=function()return root end,FindFirstChildOfClass=function()return humanoid end},CharacterAdded=signal()}
local Players={LocalPlayer=player}
local script={Destroying=signal()}
local events={}local RemoteController={connect=function(name,fn)events[name]=fn return {Disconnect=function()events[name]=nil end}end,fire=function()error("HUD must not send requests")end}
local RunService={Heartbeat=signal()}
local textbox=nil local UserInputService={GetFocusedTextBox=function()return textbox end}
local bindings={}local ContextActionService={BindAction=function(_,name,fn)bindings[name]=fn end,UnbindAction=function(_,name)bindings[name]=nil end}
local reduced=false local Accessibility={reducedMotion=function()return reduced end}
local targetKind="Camera"local targetPart={}
local Targets={currentTarget=function()return targetPart,targetKind end}
local map={children={}}
local function part(x,id,state)
 local p=Instance.new("Part")p.Position=v(x,0,0)p.CFrame=cf(x,0,0)p.Size=v(1,1,1)p.Transparency=0 p.Color={}p.Material=1 p.Parent=map p.attrs={SecurityId=id,CameraState=state}return p
end
local terminal=part(2,"terminal",nil)
local cameras={}for i=1,6 do cameras[i]=part(i,"C"..i,"Sweep")end
local surface=part(1,"PrivateSource",nil)surface.tags={"SecretTag"}surface.attrs={Private="removed"}
local scriptChild=Instance.new("Script")scriptChild.Parent=surface
local decal=Instance.new("Decal")decal.Parent=surface
local actor=part(2,"SameVisualForEveryone",nil)
local model={IsA=function(_,k)return k=="Model"end,GetPivot=function()return cf(2,0,0)end,GetDescendants=function()return {actor}end}
local geometry={surface}local occluded=false
local workspace={CurrentCamera={},GetPartBoundsInRadius=function()return geometry end,GetChildren=function()return {model}end,Raycast=function(_,_,offset)if occluded and offset.X>1.5 then return {Instance=surface}end return nil end}
local CollectionService={GetTagged=function(_,tag)return if tag=="terminal"then {terminal}else cameras end,GetTags=function(_,p)return p.tags end,RemoveTag=function(_,p,tag)assert(p.copy,"Source tags must stay untouched")for i,t in p.tags do if t==tag then table.remove(p.tags,i)break end end end}
local Enums={Tag={CameraTerminal="terminal",SecurityCamera="camera"}}
local OverlapParams={new=function()return {}end}local RaycastParams={new=function()return {}end}
local Feeds=(function()local config=GameConfig.SecurityHud ${feed}end)()
check(#Feeds.cameras(cameras)==6,"Working camera filter")cameras[1].attrs.CameraState="Disabled"cameras[2].attrs.CameraState="Destroyed"cameras[3].attrs.CameraState="Locked"
check(#Feeds.cameras(cameras)==4 and Feeds.cameras(cameras)[1]==cameras[3],"Stable working-only camera order")
cameras[1].attrs.CameraState="Sweep"cameras[2].attrs.CameraState="Sweep"
local testViewport=Instance.new("ViewportFrame")local scene=Feeds.new(testViewport)
scene.update(cameras[1],.1)
local function copies()local out={}for _,o in objects do if o.copy and o.ClassName=="Part"and not o.destroyed then table.insert(out,o)end end return out end
check(#copies()==2,"Queryable geometry plus identical nonqueryable model visuals")
for _,p in copies()do check(p.Name=="FeedSurface"and next(p.attrs)==nil and #p.tags==0,"Clone name/tags/attributes sanitized")for _,c in p.children do check(c.ClassName~="Script"or c.destroyed,"Scripts stripped before parenting")end end
check(surface.attrs.Private=="removed"and #surface.tags==1 and not scriptChild.destroyed,"Source parts and children untouched")
actor.CFrame=cf(5,0,0)actor.Position=v(5,0,0)occluded=true scene.update(cameras[1],.1)
local hidden=false for _,p in copies()do if p.CFrame==actor.CFrame then hidden=p.Transparency==1 end end check(hidden,"Occluder budget cannot reveal hidden actors")
cameras[1].attrs.CameraState="Disabled"scene.update(cameras[1],.1)check(#copies()==0,"Disabled signal clears geometry")cameras[1].attrs.CameraState="Sweep"
scene.update(cameras[1],.1)scene.update(nil,.1)check(#copies()==0,"Leaving feed releases geometry")
local priorLimit=GameConfig.SecurityHud.MaxPartsPerFeed GameConfig.SecurityHud.MaxPartsPerFeed=1 scene.update(cameras[1],1)check(#copies()==1,"Scene allocations obey hard part cap")local allocated=#objects scene.update(cameras[1],1)check(#objects==allocated,"Unchanged feed reuses cloned surfaces")GameConfig.SecurityHud.MaxPartsPerFeed=priorLimit
scene.Destroy()check(testViewport.CurrentCamera==nil,"Feed teardown clears camera")occluded=false
local Controller=(function()${hud}end)()Controller.Init()Controller.Start()
local function tick()RunService.Heartbeat:fire(.1)end
tick()check(not find("CameraRoomFeeds").Visible and not find("SecurityAction").Visible,"No pre-match panels")
events.PhaseChanged("Infiltration")tick()check(find("CameraRoomFeeds").Visible,"Feed screen only near match terminal")
check(find("Action").Text:find("Hack camera",1,true)~=nil,"Camera target prompt")
for kind,label in {FuseBox="Cut power",CameraTerminal="Camera Room",Lockpick="Pick lock"}do targetKind=kind tick()check(find("Action").Text:find(label,1,true)~=nil,"Exact target prompt "..kind)end
events.InteractState({Kind="Cut power",Active=true,Seconds=3})now+=1.5 tick()check(find("Action").Text=="CUT POWER"and find("SecurityHoldProgress").Size[1]==.5,"Server acknowledgement drives hold bar")
events.PhaseChanged("VaultBreach")tick()check(find("SecurityHoldProgress").Size[1]==.5,"Active-phase transition preserves acknowledged hold")
events.InteractState({Kind="Cut power",Active=false,Seconds=3})tick()check(find("SecurityHoldProgress").Size[1]==0,"Server cancellation clears hold progress")
events.InteractState({Kind="Hack",Active=true,Seconds=4})tick()check(not find("SecurityAction").Visible,"Other hold labels suppress target prompt and duplicate bars")events.InteractState({Kind="Hack",Active=false,Seconds=4})
now+=8 tick()check(find("Title").Text:find("2/2",1,true)~=nil,"Timed camera pages cycle")
reduced=true now+=20 tick()check(find("Title").Text:find("2/2",1,true)~=nil,"Reduced motion stops automatic paging")
check(bindings.SecurityNextFeeds(nil,"Begin")=="Sink","Contextual manual page binding")tick()check(find("Title").Text:find("1/2",1,true)~=nil,"Manual paging works with Reduce Motion")
textbox={}check(bindings.SecurityNextFeeds(nil,"Begin")=="Pass","Typing cannot page feeds")textbox=nil
find("SecurityHud").Enabled=false tick()check(#copies()==0 and not find("CameraRoomFeeds").Visible,"Hidden menu HUD does no scene work")find("SecurityHud").Enabled=true tick()
root.Position=v(100,0,0)tick()check(not find("CameraRoomFeeds").Visible and #copies()==0,"Leaving terminal clears all feed scenes")check(bindings.SecurityNextFeeds(nil,"Begin")=="Pass","Page key passes outside terminal")root.Position=v(0,0,0)
events.Downed({})tick()check(not find("CameraRoomFeeds").Visible and not find("SecurityAction").Visible,"Downed suppresses security HUD")events.Revived()tick()
events.Eliminated({})events.Revived()tick()check(not find("CameraRoomFeeds").Visible,"Revive cannot clear elimination")player.CharacterAdded:fire()tick()
for _,p in cameras do p.attrs.CameraState="Disabled"end tick()check(find("Title").Text:find("NO WORKING SIGNAL",1,true)~=nil and #copies()==0,"No working cameras shows explicit empty state")
cameras[1].attrs.CameraState="Locked"tick()check(find("Feed1").Visible,"Recovered camera returns")
events.ExtractionState({State="Extracted"})tick()check(not find("CameraRoomFeeds").Visible,"Extraction freeze clears feeds")events.PhaseChanged("Results")tick()check(not find("SecurityAction").Visible,"Results suppresses prompts")
script.Destroying:fire()check(next(events)==nil and #RunService.Heartbeat.listeners==0 and bindings.SecurityNextFeeds==nil,"HUD connections and manual binding cleaned up")check(#copies()==0,"All feed clones released")
-- Execute the actual alarm build/refresh fragments in their original scope.
local screen=Instance.new("ScreenGui")local alarmLabel=nil local lockdownBanner=nil local alarmPips={}local alarm=0
${alarmBuild}
local function refreshAlarm()${alarmRefresh}end
check(#alarmPips==4,"Exactly four pips represent levels zero through three")
for level=0,3 do alarm=level refreshAlarm()local lit=0 for _,pip in alarmPips do if pip.BackgroundColor3==ui.WarningColor then lit+=1 end end check(lit==level+1,"Cumulative alarm pips level "..level)check(lockdownBanner.Visible==(level==3),"Persistent Lockdown banner only at three")end
alarm=2 refreshAlarm()check(not lockdownBanner.Visible and alarmLabel.Visible,"Lockdown end restores alarm label")
print("Security client: "..checks.." actual-source assertions passed")
`;
const out=path.join(os.tmpdir(),'cover-story-security-client.luau');fs.writeFileSync(out,harness);const result=cp.spawnSync(process.argv[2]||'luau',[out],{encoding:'utf8'});process.stdout.write(result.stdout||'');process.stderr.write(result.stderr||'');if(result.error)throw result.error;process.exitCode=result.status??1;
