// Run actual Intel controller source against deterministic input, streaming and rendering fixtures.
const fs=require('node:fs'),path=require('node:path'),os=require('node:os'),cp=require('node:child_process');
const read=p=>fs.readFileSync(path.join(__dirname,'..',p),'utf8');
const text=read('src/client/Controllers/IntelController.luau');
const start=text.indexOf('local IntelController =');if(start<0)throw Error('Missing module boundary');
const body=text.slice(start);
// Reuse the existing service/input fixtures; the controller body itself is never rewritten.
const base=read('tools/check-package-input.cjs');
const shared=base.slice(base.indexOf('local checks=0'),base.indexOf('local terminals='));
if(!shared.startsWith('local checks=0'))throw Error('Missing fixture boundary');
const harness=`
${shared}
vm.__index=function(a,k)
 if k=="Magnitude"then return math.sqrt(a.X*a.X+a.Y*a.Y+a.Z*a.Z)
 elseif k=="Unit"then local m=math.sqrt(a.X*a.X+a.Y*a.Y+a.Z*a.Z)return v(a.X/m,a.Y/m,a.Z/m)
 elseif k=="Dot"then return function(b,c)return b.X*c.X+b.Y*c.Y+b.Z*c.Z end end
end
Enum.HighlightDepthMode={Occluded="Occluded"}
local RaycastParams={new=function()return {}end}
local objects={}
local Instance={new=function(class)
 local object={ClassName=class}
 function object:Destroy()self.destroyed=true for _,child in objects do if child.Parent==self then child:Destroy()end end end
 table.insert(objects,object)return object
end}
local mapParent={}
local function station(x,id)
 local p=part(v(x,0,0),id)p.Parent=mapParent return p
end
local first=station(3,"I1")
local tagged={first}
local added,removed=signal(),signal()
local CollectionService={GetTagged=function()return tagged end,GetInstanceAddedSignal=function()return added end,GetInstanceRemovedSignal=function()return removed end}
local Enums={Tag={IntelSpawn="IntelSpawn"}}
local events={}
local sent={}
local RemoteController={fire=function(...)table.insert(sent,{...})end}
function RemoteController.connect(name,fn)local s=signal()events[name]=function(...)s:Fire(...)end return s:Connect(fn)end
local Janitor={new=function()
 local j={items={}}
 function j:Add(item)table.insert(self.items,item)return item end
 function j:Destroy()for i=#self.items,1,-1 do local item=self.items[i]if type(item)=="function"then item()elseif item.Disconnect then item:Disconnect()else item:Destroy()end end table.clear(self.items)end
 return j
end}
local GameConfig={Controls={Interact="E",InteractPad="A"},Rig={CollisionGroup="Bodies"},Intel={AimDegrees=20,GlintRange=25,InteractStuds=5,GlintMax=6}}
local hit=nil
local camera={CFrame={Position=v(0,0,0),LookVector=v(1,0,0)}}
local workspace={CurrentCamera=camera,Raycast=function()return hit end}
local DroneController={part=function()return nil end} -- existing tests exercise on-foot input
local Controller=(function()
${body}
end)()
local action="CoverStoryInteractIntel"
local function tick()RunService.Heartbeat:Fire(.1)end
local function press(state)return actions[action](action,state)end
local function shown()local n=0 for _,o in objects do if o.ClassName=="Highlight"and o.Adornee and not o.destroyed then n+=1 end end return n end
local function blocked(message)check(actions[action]==nil and shown()==0,message)end
local function last(name)check(sent[#sent][1]==name,"Expected "..name)end
local function cancelOnce(trigger,message)
 press("Begin")last("RequestInteract")local count=#sent trigger()check(#sent==count+1,message)last("RequestInteractCancel")tick()tick()check(#sent==count+1,"No repeated cancel")blocked("Blocked input clears glints")
end
Controller.Init()Controller.Start()tick()blocked("Lobby has no input or glints")
check(#objects==1,"No off-phase highlight allocation")
events.PhaseChanged("Insertion")blocked("Insertion has no input or glints")
events.PhaseChanged("Infiltration")check(actions[action]~=nil and shown()==1,"Living infiltration station is usable and glints")
press("Begin")check(sent[#sent][1]=="RequestInteract"and sent[#sent][2]=="Intel"and sent[#sent][3]=="I1","Exact Intel request payload")
press("End")last("RequestInteractCancel")local count=#sent
check(press("Cancel")=="Pass"and #sent==count,"Duplicate release passes without cancel")
local stale=actions[action]
root.Position=v(50,0,0)
check(stale(action,"Begin")=="Pass"and #sent==count,"Key press rechecks reach before next refresh")tick()blocked("Out of glint range clears glints")
root.Position=v(0,0,0)tick()
camera.CFrame.LookVector=v(-1,0,0)
check(stale(action,"Begin")=="Pass"and #sent==count,"Key press rechecks facing")tick()check(actions[action]==nil and shown()==1,"Behind-camera station glints but cannot capture E")
camera.CFrame.LookVector=v(1,0,0)tick()
hit={Instance={Parent={}}}
check(stale(action,"Begin")=="Pass"and #sent==count,"Key press rechecks occlusion")tick()blocked("Occluded station clears glint")
hit={Instance={Parent=mapParent}}tick()check(actions[action]~=nil,"Own station stand preserves existing LOS rule")hit=nil
cancelOnce(function()events.PhaseChanged("Results")end,"Results cancels hold")
events.PhaseChanged("Overtime")check(actions[action]~=nil,"Overtime hack remains eligible")
cancelOnce(function()events.Downed({})end,"Downed cancels hold")
events.PhaseChanged("VaultBreach")blocked("Phase change cannot revive a downed player")events.Revived()check(actions[action]~=nil,"Revive restores eligible input")
cancelOnce(function()events.Eliminated({})end,"Elimination cancels hold")events.Revived()blocked("Revive cannot clear elimination")
player.CharacterAdded:Fire(character)check(actions[action]~=nil,"New character resets life state")
cancelOnce(function()textbox={}UserInputService.TextBoxFocused:Fire(textbox)end,"Text focus cancels hold")textbox=nil tick()
cancelOnce(function()UserInputService.WindowFocusReleased:Fire()end,"Window focus loss cancels hold")UserInputService.WindowFocused:Fire()
cancelOnce(function()humanoid.Health=0 tick()end,"Dead humanoid cancels hold")humanoid.Health=100 tick()
cancelOnce(function()workspace.CurrentCamera=nil tick()end,"Missing camera cancels hold")workspace.CurrentCamera=camera tick()
cancelOnce(function()player.Character=nil tick()end,"Missing character cancels hold")player.Character=character tick()
cancelOnce(function()events.ExtractionState({State="Extracted"})end,"Extraction freeze cancels hold")events.ExtractionState({State="Idle"})
press("Begin")count=#sent events.InteractState({Kind="Hack",Active=false,Seconds=4})
check(#sent==count,"Server-completed hold does not send spurious cancel")
check(press("End")=="Pass"and #sent==count,"Completed hold release passes through")
events.IntelUpdate({Balance=8,Used={"I1"}})check(Controller.balance()==8,"Private balance remains accessible")blocked("Used station stops glinting and targeting immediately")
events.IntelUpdate({Balance=3,Used={}})check(shown()==1 and Controller.balance()==3,"Update refreshes current private state")
press("Begin")count=#sent removed:Fire(first)
check(#sent==count+1,"Stream-out cancels a hold on removed station")last("RequestInteractCancel")blocked("Stream-out clears glint and binding")
added:Fire(first)tick()check(actions[action]~=nil and shown()==1,"Stream-in restores target")
local allocated=#objects for _=1,100 do tick()end check(#objects==allocated,"Station glints are pooled")
for i=2,10 do added:Fire(station(3,"I"..i))end tick()check(shown()==GameConfig.Intel.GlintMax,"Glint count stays bounded")
events.IntelUpdate({Balance=8,Used={"I1"}})
events.PhaseChanged("Lobby")check(Controller.balance()==0,"Lobby clears previous balance")blocked("Lobby clears glints")
events.PhaseChanged("Infiltration")check(shown()==GameConfig.Intel.GlintMax,"New round clears taken-station cache")
press("Begin")count=#sent script.Destroying:Fire()
check(#sent==count+1,"Teardown cancels active hold once")blocked("Teardown clears action and glints")
check(Controller.balance()==0,"Teardown clears balance")
for _,s in signals do for _,c in s.listeners do check(not c.live,"All subscriptions disconnected")end end
for _,o in objects do check(o.destroyed,"Client visual destroyed")end
count=#sent events.PhaseChanged("Infiltration")added:Fire(first)tick()
check(#sent==count and actions[action]==nil,"Destroyed controller cannot reactivate")
print("Intel input: "..checks.." actual-source assertions passed")
`;
const out=path.join(os.tmpdir(),'cover-story-intel-input.luau');fs.writeFileSync(out,harness);
const result=cp.spawnSync(process.argv[2]||'luau',[out],{encoding:'utf8'});process.stdout.write(result.stdout||'');process.stderr.write(result.stderr||'');if(result.error)throw result.error;process.exitCode=result.status??1;
