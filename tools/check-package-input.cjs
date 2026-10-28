// Execute the actual contextual-input controller with deterministic Roblox service fixtures.
const fs = require('node:fs'), path = require('node:path'), os = require('node:os'), cp = require('node:child_process');
const source = fs.readFileSync(path.join(__dirname, '../src/client/Controllers/PackageController.luau'), 'utf8');
const body = source.slice(source.indexOf('local PackageController ='));
if (!body.startsWith('local PackageController =')) throw Error('Controller boundary missing');
const fixture = `
local checks=0
local function check(value,message)assert(value,message) checks+=1 end
local signals={}
local function signal()
 local s={listeners={}}
 function s:Connect(fn)local c={fn=fn,live=true}function c:Disconnect()self.live=false end table.insert(self.listeners,c)return c end
 function s:Fire(...)for _,c in table.clone(self.listeners)do if c.live then c.fn(...)end end end
 table.insert(signals,s)return s
end
local vm={}
local function v(x,y,z)return setmetatable({X=x,Y=y,Z=z},vm)end
vm.__sub=function(a,b)return v(a.X-b.X,a.Y-b.Y,a.Z-b.Z)end
vm.__index=function(a,k)if k=="Magnitude"then return math.sqrt(a.X*a.X+a.Y*a.Y+a.Z*a.Z)end end
local Vector3={new=v}
local function part(position,id)
 return {Position=position,IsA=function(_,kind)return kind=="BasePart"end,GetAttribute=function()return id end}
end
local root=part(v(0,0,0))
local humanoid={Health=100}
local character={FindFirstChild=function()return root end,FindFirstChildOfClass=function()return humanoid end}
local player={Character=character,CharacterAdded=signal()}
local Players={LocalPlayer=player}
local RunService={Heartbeat=signal()}
local UserInputService={TextBoxFocused=signal(),WindowFocusReleased=signal(),WindowFocused=signal()}
local textbox=nil
function UserInputService:GetFocusedTextBox()return textbox end
local script={Destroying=signal()}
local Enum={ContextActionResult={Pass="Pass",Sink="Sink"},UserInputState={Begin="Begin",End="End",Cancel="Cancel"},ContextActionPriority={High={Value=2000}}}
local actions={}
local ContextActionService={}
function ContextActionService:BindActionAtPriority(name,fn)actions[name]=fn end
function ContextActionService:UnbindAction(name)actions[name]=nil end
local terminals={part(v(1,0,0),"E1")}
local items={part(v(1,0,0))}
local Enums={Tag={ExtractionTerminal="terminal",PackageItem="package"}}
local CollectionService={GetTagged=function(_,tag)return if tag=="terminal"then terminals else items end}
local events={}
local sent={}
local RemoteController={fire=function(...)table.insert(sent,{...})end}
function RemoteController.connect(name,fn)
 local s=signal()events[name]=function(...)s:Fire(...)end return s:Connect(fn)
end
local Janitor={new=function()
 local j={items={}}
 function j:Add(item)table.insert(self.items,item)return item end
 function j:Destroy()for i=#self.items,1,-1 do local item=self.items[i]if type(item)=="function"then item()else item:Disconnect()end end table.clear(self.items)end
 return j
end}
local GameConfig={Controls={Interact="E",InteractPad="A",DropPackage="X"},Package={PassRange=6,PickupRange=4},Extraction={ZoneSize=16,ZoneHeightStuds=6,CallReachStuds=10}}
local Controller=(function()
${body}
end)()
local interact="CoverStoryInteractObjective"
local drop="CoverStoryDropPackage"
local function tick()RunService.Heartbeat:Fire(.1)end
local function packet(you,team,state)events.PackageState({YouCarry=you,TeamCarries=team,State=state or "Carried"})end
local function press(state)return actions[interact](interact,state)end
local function last(name)check(sent[#sent][1]==name,"Expected remote "..name)end
local function notBound(message)check(actions[interact]==nil and actions[drop]==nil,message)end
local function cancelledOnce(trigger,message)
 press("Begin")last("RequestInteract")local count=#sent trigger()check(#sent==count+1,message)last("RequestInteractCancel")tick()tick()check(#sent==count+1,"No repeat cancels")notBound("Gated actions unbound")
end
Controller.Init()Controller.Start()
packet(true,true)notBound("No pre-phase binding")
events.PhaseChanged("PackageHeist")check(actions[interact]~=nil and actions[drop]~=nil,"Carrier can call and drop")
press("Begin")last("RequestInteract")check(sent[#sent][2]=="ExtractionCall" and sent[#sent][3]=="E1","Actual call payload")
press("End")last("RequestInteractCancel")local count=#sent
press("Cancel")check(#sent==count,"Released hold cancels once")
packet(false,false)notBound("Unrelated terminal cannot steal E")
packet(false,true)check(actions[interact]~=nil and actions[drop]==nil,"Carrier teammate may call only")
packet(false,false,"Pedestal")press("Begin")check(sent[#sent][2]=="Package","Noncarrier at terminal can take nearby Package")press("End")
packet(true,true)
local stale=actions[interact]
packet(false,false)
check(stale(interact,"Begin")=="Pass","Stale callback passes through without valid choice")
packet(true,true)
cancelledOnce(function()events.PhaseChanged("Results")end,"Results cancels held interaction")
events.PhaseChanged("Overtime")check(actions[interact]~=nil,"Overtime eligible")
cancelledOnce(function()events.Downed({})end,"Downed cancels hold")
events.PhaseChanged("PackageHeist")notBound("Phase change cannot revive")
events.Revived()check(actions[interact]~=nil,"Revive restores eligibility")
cancelledOnce(function()events.Eliminated({})end,"Elimination cancels hold")
events.Revived()notBound("Revived cannot clear elimination")
player.CharacterAdded:Fire(character)check(actions[interact]~=nil,"New character resets life state")
cancelledOnce(function()textbox={} UserInputService.TextBoxFocused:Fire(textbox)end,"Text focus cancels hold")
textbox=nil tick()check(actions[interact]~=nil,"Text focus release recovers")
cancelledOnce(function()UserInputService.WindowFocusReleased:Fire()end,"Window focus loss cancels hold")
UserInputService.WindowFocused:Fire()check(actions[interact]~=nil,"Window focus recovers")
local dropCallback=actions[drop]
textbox={} count=#sent check(dropCallback(drop,"Begin")=="Pass" and #sent==count,"Stale drop callback respects text focus")textbox=nil
check(dropCallback(drop,"Begin")=="Sink","Valid drop consumed")last("RequestDropPackage")
cancelledOnce(function()humanoid.Health=0 tick()end,"Dead humanoid cancels hold")
humanoid.Health=100 tick()
cancelledOnce(function()events.ExtractionState({State="Extracted"})end,"Extraction cinematic cancels hold")
events.ExtractionState({State="Countdown",ByYourTeam=true})check(actions[interact]==nil and actions[drop]~=nil,"Own running extraction cannot capture E; drop remains available")
events.ExtractionState({State="Countdown",ByYourTeam=false})check(actions[interact]~=nil,"New carrier team may replace rival extraction")
events.ExtractionState({State="Open",ByYourTeam=true,SiteId="E1",Position=v(0,0,0)})
press("Begin")check(sent[#sent][2]=="ExtractionChannel","Open zone takes precedence over terminal")press("End")
root.Position=v(0,24,0)tick()check(actions[interact]==nil,"Pad on another storey cannot capture E")root.Position=v(0,0,0)tick()
events.ExtractionState({State="Idle"})
cancelledOnce(function()events.PhaseChanged("Insertion")end,"Insertion clears held actions")
check(Controller.state()==nil and Controller.extraction()==nil,"Insertion clears objective state")
events.PhaseChanged("PackageHeist")packet(true,true)
press("Begin")count=#sent script.Destroying:Fire()
check(#sent==count+1,"Destroy cancels active hold once")notBound("Destroy unbinds actions")
check(Controller.state()==nil and Controller.extraction()==nil,"Destroy clears caches")
for _,s in signals do for _,c in s.listeners do check(not c.live,"Every subscription disconnected")end end
count=#sent events.PackageState({YouCarry=true,TeamCarries=true,State="Carried"})tick()
check(#sent==count and Controller.state()==nil,"Destroyed controller cannot reactivate")
print("Package input: "..checks.." actual-source assertions passed")
`;
const out=path.join(os.tmpdir(),'cover-story-package-input.luau'); fs.writeFileSync(out,fixture);
const result=cp.spawnSync(process.argv[2]||'luau',[out],{encoding:'utf8'});
process.stdout.write(result.stdout||'');process.stderr.write(result.stderr||'');if(result.error)throw result.error;process.exitCode=result.status??1;
