// Actual DownedController source; deterministic geometry, input, animation and scheduling fixtures.
const fs=require('node:fs'),path=require('node:path'),os=require('node:os'),cp=require('node:child_process');
const read=p=>fs.readFileSync(path.join(__dirname,'..',p),'utf8');
const source=read('src/client/Controllers/DownedController.luau');const start=source.indexOf('local DownedController =');if(start<0)throw Error('Module boundary missing');
const base=read('tools/check-package-input.cjs');const shared=base.slice(base.indexOf('local checks=0'),base.indexOf('local terminals='));
const harness=`
${shared}
Vector3.zero=v(0,0,0)
vm.__div=function(a,b)return v(a.X/b,a.Y/b,a.Z/b)end
vm.__index=function(a,k)
 if k=="Magnitude"then return math.sqrt(a.X*a.X+a.Y*a.Y+a.Z*a.Z)
 elseif k=="Unit"then local m=math.sqrt(a.X*a.X+a.Y*a.Y+a.Z*a.Z)return v(a.X/m,a.Y/m,a.Z/m)
 elseif k=="Dot"then return function(b,c)return b.X*c.X+b.Y*c.Y+b.Z*c.Z end end
end
local now=0 local os={clock=function()return now end}
local jobs={}
local task={delay=function(seconds,fn)local job={at=now+seconds,fn=fn}table.insert(jobs,job)return job end,cancel=function(job)job.cancelled=true end}
local function advance(seconds)now+=seconds for _,j in jobs do if not j.cancelled and not j.done and now>=j.at then j.done=true j.fn()end end end
local animationTracks={}
local animator={LoadAnimation=function(_,name)
 local t={name=name,plays=0,stops=0}
 function t:Play()self.plays+=1 end
 function t:Stop()self.stops+=1 end
 function t:Destroy()self.destroyed=true end
 table.insert(animationTracks,t)return t
end}
function humanoid:FindFirstChildOfClass()return animator end
local PoseAnimation={registerAll=function()return setmetatable({},{__index=function(_,k)return k end})end}
local Knockdown={animation=function(stage,fall,posture,moving)return stage..fall..posture..tostring(moving)end}
local want=Vector3.zero
local MovementController={wantedDirection=function()return want end}
RunService.RenderStepped=signal()
local RaycastParams={new=function()return {}end}
local bodyRoot=part(v(2,0,0))bodyRoot.CFrame={UpVector=v(1,0,0)}
local body={Name="ExistingRig",IsA=function(_,kind)return kind=="Model"end,FindFirstChild=function()return bodyRoot end}
local children={body}
local hit=nil
local sound={Name="Died",Volume=1,IsA=function(_,kind)return kind=="Sound"end}
local workspace={CurrentCamera={CFrame={Position=v(0,0,0),LookVector=v(1,0,0)}},DescendantAdded=signal(),GetChildren=function()return children end,GetDescendants=function()return {sound}end,Raycast=function()return hit end}
local events={}local sent={}
local RemoteController={fire=function(...)table.insert(sent,{...})end}
function RemoteController.connect(name,fn)local s=signal()events[name]=function(...)s:Fire(...)end return s:Connect(fn)end
local Janitor={new=function()local j={items={}}
 function j:Add(i)table.insert(self.items,i)return i end
 function j:Destroy()for n=#self.items,1,-1 do local i=self.items[n]if type(i)=="function"then i()else i:Disconnect()end end table.clear(self.items)end
 return j end}
local GameConfig={Controls={Interact="E",InteractPad="A"},Rig={CollisionGroup="Bodies"},Downed={BodyAimDegrees=20,InteractStuds=5,CrawlRequestHz=10,Knockdown={Seconds=.5}},NPC={AnimationFadeSeconds=.1,WalkAnimationMinSpeed=.1}}
local Controller=(function()
${source.slice(start)}
end)()
local action="CoverStoryInteractBody"
local function tick()RunService.RenderStepped:Fire(.1)end
local function press(state)return actions[action](action,state)end
local function blocked(msg)check(actions[action]==nil and not Controller.hasBodyTarget(),msg)end
local function last(name)check(sent[#sent][1]==name,"Expected "..name)end
local function cancelOnce(fn,msg)press("Begin")last("RequestInteract")local n=#sent fn()check(#sent==n+1,msg)last("RequestInteractCancel")tick()tick()check(#sent==n+1,"No repeated cancel")blocked("No gated body action")end
local down={Fall="Forward",Posture="Prone"}
local dead={Fall="Forward",Posture="Prone",FromStanding=true}
Controller.Init()Controller.Start()tick()blocked("Lobby cannot target bodies")check(sound.Volume==0,"Default death sound remains silenced")
events.PhaseChanged("Insertion")blocked("Insertion cannot target bodies")
events.PhaseChanged("Infiltration")check(Controller.hasBodyTarget()and actions[action]~=nil,"Generic lying rig is targetable")
press("Begin")check(sent[#sent][1]=="RequestInteract"and sent[#sent][2]=="Body"and sent[#sent][3]==body.Name,"Only generic Body request; server decides revive or execute")press("End")last("RequestInteractCancel")local count=#sent
check(press("Cancel")=="Pass"and #sent==count,"Duplicate release cannot cancel another action")
local stale=actions[action]bodyRoot.Position=v(20,0,0)check(stale(action,"Begin")=="Pass"and #sent==count,"Key press rechecks reach")tick()blocked("Out of range binding released")bodyRoot.Position=v(2,0,0)tick()
bodyRoot.CFrame.UpVector=v(0,1,0)check(stale(action,"Begin")=="Pass","Standing rig rejected before refresh")bodyRoot.CFrame.UpVector=v(1,0,0)
workspace.CurrentCamera.CFrame.LookVector=v(-1,0,0)check(stale(action,"Begin")=="Pass","Facing revalidated")workspace.CurrentCamera.CFrame.LookVector=v(1,0,0)
hit={}check(stale(action,"Begin")=="Pass","LOS revalidated")hit=nil
cancelOnce(function()events.Downed(down)end,"Going down cancels held interaction")
want=v(1,0,0)tick()last("RequestCrawl")check(sent[#sent][2]==want,"Crawl request retained")count=#sent tick()check(#sent==count,"Unchanged crawl direction not resent")
want=Vector3.zero tick()last("RequestCrawl")check(sent[#sent][2]==Vector3.zero,"Stopping crawl still sends zero")
events.PhaseChanged("Results")count=#sent want=v(1,0,0)tick()check(#sent==count,"No crawl traffic outside active phases")
events.PhaseChanged("VaultBreach")blocked("Phase change does not revive")events.Revived()check(actions[action]~=nil,"Revival restores eligibility")
cancelOnce(function()events.Eliminated(dead)end,"Elimination cancels held interaction")
events.Revived()blocked("Late revive cannot clear eliminated state")
player.CharacterAdded:Fire(character)check(actions[action]~=nil,"Respawn resets life state")
cancelOnce(function()textbox={}UserInputService.TextBoxFocused:Fire(textbox)end,"Text focus cancels hold")textbox=nil tick()
cancelOnce(function()UserInputService.WindowFocusReleased:Fire()end,"Window focus loss cancels hold")UserInputService.WindowFocused:Fire()
cancelOnce(function()events.PhaseChanged("Results")end,"Results cancels hold")events.PhaseChanged("PackageHeist")
cancelOnce(function()humanoid.Health=0 tick()end,"Dead humanoid cannot interact")humanoid.Health=100 tick()
local getRoot=character.FindFirstChild cancelOnce(function()character.FindFirstChild=function()return nil end tick()end,"Missing root cancels hold")character.FindFirstChild=getRoot tick()
cancelOnce(function()events.ExtractionState({State="Extracted"})end,"Extraction freeze cancels hold")events.ExtractionState({State="Idle"})
press("Begin")count=#sent events.InteractState({Kind="Hack",Active=false})check(press("End")=="Sink"and #sent==count+1,"Other interaction acknowledgement cannot release body hold")
for _,kind in {"Revive","Execute"}do press("Begin")count=#sent events.InteractState({Kind=kind,Active=false})check(press("End")=="Pass"and #sent==count,"Server-completed "..kind.." does not send cancellation")end
events.Eliminated(dead)local fallTrack=animationTracks[#animationTracks]local pending=jobs[#jobs]advance(.6)
check(animationTracks[#animationTracks].name:sub(1,4)=="Dead","Elimination settles to death pose")check(pending.done,"Death callback executed")
player.CharacterAdded:Fire(character)
events.Eliminated(dead)pending=jobs[#jobs]player.CharacterAdded:Fire(character)count=#animationTracks advance(1)
check(pending.cancelled and #animationTracks==count,"Respawn cancels delayed death pose")
events.Eliminated(dead)pending=jobs[#jobs]events.PhaseChanged("Lobby")count=#animationTracks advance(1)
check(pending.cancelled and #animationTracks==count,"Round end cancels delayed death pose")
player.CharacterAdded:Fire(character)events.PhaseChanged("Overtime")check(actions[action]~=nil,"Overtime supports body interactions")
events.Eliminated(dead)pending=jobs[#jobs]script.Destroying:Fire()count=#animationTracks advance(1)
check(pending.cancelled and #animationTracks==count,"Teardown cancels delayed death pose")blocked("Teardown releases targeting and action")
for _,t in animationTracks do check(t.destroyed,"Animation tracks destroyed")end
for _,s in signals do for _,c in s.listeners do check(not c.live,"Every subscription disconnected")end end
count=#sent events.PhaseChanged("Infiltration")tick()check(#sent==count and actions[action]==nil,"Destroyed controller cannot reactivate")
print("Body input: "..checks.." actual-source assertions passed")
`;
const out=path.join(os.tmpdir(),'cover-story-body-input.luau');fs.writeFileSync(out,harness);const result=cp.spawnSync(process.argv[2]||'luau',[out],{encoding:'utf8'});process.stdout.write(result.stdout||'');process.stderr.write(result.stderr||'');if(result.error)throw result.error;process.exitCode=result.status??1;
