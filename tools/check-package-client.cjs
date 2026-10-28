// Actual Package presentation/HUD/aircraft source with clock, UI and symbolic-transform fixtures.
const fs=require('node:fs'),path=require('node:path'),os=require('node:os'),cp=require('node:child_process');
const root=path.resolve(__dirname,'..'),read=p=>fs.readFileSync(path.join(root,p),'utf8');
function after(t,m){const i=t.indexOf(m);if(i<0)throw Error(m);return t.slice(i);}
function between(t,a,b){const i=t.indexOf(a),j=t.indexOf(b,i);if(i<0||j<0)throw Error(a);return t.slice(i,j);}
const model=after(read('src/client/Combat/PackagePresentation.luau'),'local PackagePresentation =');
const hud=after(read('src/client/Controllers/PackageHudController.luau'),'local PackageHudController =');
const aircraft=after(read('src/client/Combat/ExtractionAircraft.luau'),'local ExtractionAircraft =');
const match=after(read('src/client/Combat/MatchPresentation.luau'),'local MatchPresentation =');
const fixture=between(read('tools/check-match-client.cjs'),'local objects={}','local Accessibility=');
const configSource=read('src/shared/GameConfig.luau');
const matchConfig=between(configSource,'\tMatchHud = {','\n\t-- Spec 3.1: modes.');
const visualConfig=between(configSource,'\tExtractionVisuals = {','\n\t-- Spec 19: overtime.');
// Verify the label contract from actual handlers, not from similarly named RequestInteract kinds.
for(const label of ['Take the Package','Pass the Package'])if(!read('src/server/Services/PackageService.luau').includes(`label = "${label}"`))throw Error('Package hold label changed');
for(const label of ['Call extraction','Extract'])if(!read('src/server/Services/ExtractionService.luau').includes(`label = "${label}"`))throw Error('Extraction hold label changed');
const harness=`
local checks=0
local function check(value,message)assert(value,message)checks+=1 end
local now=100
local os={clock=function()return now end}
local Color3={new=function(...)return {...}end,fromRGB=function(...)return {...}end}
local Vector2={new=function(...)return {...}end,zero={}}
local vm={}
local function v(x,y,z)return setmetatable({X=x,Y=y,Z=z},vm)end
vm.__add=function(a,b)return v(a.X+b.X,a.Y+b.Y,a.Z+b.Z)end
local Vector3={new=v,zero=v(0,0,0)}
local cm={}
local function cf(x,y,z)return setmetatable({Position=if type(x)=="table"then x else v(x or 0,y or 0,z or 0)},cm)end
cm.__mul=function(a,b)return cf(a.Position+b.Position)end
local CFrame={new=cf,identity=cf(),Angles=function()return cf()end}
local UDim2={new=function(...)return {...}end,fromScale=function(...)return {...}end,fromOffset=function(...)return {...}end}
local Enum={Material={Glass=1,SmoothPlastic=2}}
local GameConfig={Match={InsertionSeconds=8,BannerSeconds=3},Controls={DropPackage={Name="X"}},Extraction={CinematicSeconds=5}}
GameConfig.MatchHud=({${matchConfig}}).MatchHud
GameConfig.ExtractionVisuals=({${visualConfig}}).ExtractionVisuals
local Presentation=(function()${model}end)()
local Clock=(function()${match}end)()
local state=Presentation.new()
local resting={State="Pedestal",Position=v(1,2,3),YouCarry=false,TeamCarries=false}
state.package(resting)check(state.view(now,now).point==nil,"No pre-phase objective marker")
state.phase("PackageHeist")check(state.view(now,now).point==resting.Position,"Public pedestal marker")
local pulse={State="Carried",Position=v(8,2,3),PulseUntil=102,YouCarry=false,TeamCarries=false}
state.package(pulse)check(state.view(101,101).point==pulse.Position,"Server-revealed rival pulse")
check(state.view(102,102).point==nil,"Pulse expires locally even without another packet")
state.package({State="Carried",YouCarry=true,TeamCarries=true})
check(state.view(now,now).point==nil,"Do not infer carrier coordinates for own team")
state.package({State="Hidden",Position=v(1,2,3),YouCarry=false,TeamCarries=false})
check(state.view(now,now).point==nil,"Hidden state cannot retain resting position")
for _,label in {"Take the Package","Pass the Package","Call extraction","Extract"}do
 state.interaction({Kind=label,Active=true,Seconds=4},now)
 check(state.view(now,now+2).holdLabel~=nil and state.view(now,now+2).holdProgress==.5,"Actual interaction label: "..label)
end
state.interaction({Kind="Revive",Active=true,Seconds=4},now)check(state.view(now,now).holdLabel==nil,"No revive duplicate")
state.extraction({State="Extracted",ByYourTeam=true,Position=v(0,0,0),EndsAt=9999},now)
check(state.view(102,102).cinematicProgress==.4,"Cinematic ignores stale Open EndsAt")
state.extraction({State="Extracted",ByYourTeam=true,Position=v(0,0,0)},102)
check(state.view(102,102).cinematicProgress==.4,"Duplicate acknowledgement cannot restart cinematic")
state.phase("Results")check(not state.view(103,103).cinematic,"Only server phase ends presentation")
state.phase("Lobby")state.phase("PackageHeist")
check(state.view(now,now).package==nil and state.view(now,now).extraction==nil,"Round reset clears objectives")
local overtime=Clock.new()overtime.apply("Overtime",{StartedAt=100,MainEndsAt=99,EndsAt=190})
check(overtime.view(101).mainTimer=="01:29","Overtime uses capped server deadline")
${fixture}
theme.MarginPixels=16 theme.PaddingPixels=12 theme.CoverWidthPixels=248 theme.CoverHeightPixels=60 theme.CaptionSize=12
theme.ActionWidthPixels=252 theme.ActionHeightPixels=58 theme.ActionOffsetPixels=112 theme.AccentColor={}
local Accessibility={reducedMotion=function()return false end}
local events={}
local RemoteController={connect=function(name,fn)events[name]=fn return {Disconnect=function()events[name]=nil end}end}
local RunService={RenderStepped=signal()}
local workspace={GetServerTimeNow=function()return now end}
local script={Destroying=signal()}
local Aircraft=(function()local config=GameConfig.ExtractionVisuals ${aircraft}end)()
local floorCalls=0
local Floors={hint=function()floorCalls+=1 return "↑ M"end}
local Controller=(function()${hud}end)()
Controller.Init()Controller.Start()
events.PhaseChanged("PackageHeist")events.PackageState(resting)RunService.RenderStepped:fire()
check(find("PackageMarker").Enabled and find("Status").Text=="PACKAGE AVAILABLE","Resting HUD")
events.PackageState(pulse)now=101 RunService.RenderStepped:fire()check(find("PackageMarker").Enabled,"Pulse marker")
floorCalls=0
now=102 RunService.RenderStepped:fire()check(not find("PackageMarker").Enabled,"HUD does not hold expired pulse")
check(floorCalls==0,"Expired carrier pulse is not queried for floor data")
events.PackageState({State="Carried",YouCarry=true,TeamCarries=true})RunService.RenderStepped:fire()
check(find("Status").Text=="YOU HAVE THE PACKAGE" and find("Hint").Text=="[ X ] DROP PACKAGE","Carrier drop hint")
events.ExtractionState({State="Countdown",EndsAt=147,Position=v(10,0,0),ByYourTeam=true})RunService.RenderStepped:fire()
check(find("ExtractionCountdown").Text=="COUNTDOWN · 00:45" and find("ExtractionMarker").Enabled,"Extraction countdown")
events.InteractState({Kind="Extract",Active=true,Seconds=3})now+=1 RunService.RenderStepped:fire()
check(find("ObjectiveHold").Visible and find("Action").Text=="EXTRACTING","Channel acknowledgement")
events.ExtractionState({State="Hover",EndsAt=now+2,Position=v(10,0,0),ByYourTeam=true})RunService.RenderStepped:fire()
local cabin=find("Cabin")check(cabin.Transparency==0 and cabin.CanCollide==false and cabin.CanQuery==false,"Aircraft cosmetic hover")
check(find("Rotor").Parent==find("PackagePresentation"),"Aircraft lives outside characters")
events.InteractState({Kind="Extract",Active=false,Seconds=3})
events.ExtractionState({State="Extracted",Position=v(10,0,0),ByYourTeam=true})now+=2 RunService.RenderStepped:fire()
check(find("ExtractionFade").Visible and find("ExtractionResult").Text=="MISSION SUCCESS","Confirmed winning extraction")
check(cabin.CFrame.Position.Y>GameConfig.ExtractionVisuals.HoverStuds,"Departure rises during confirmed extraction")
events.PhaseChanged("Results")RunService.RenderStepped:fire()
check(not find("ExtractionFade").Visible and cabin.Transparency==1,"Results clears cinematic/aircraft")
events.PhaseChanged("Lobby")events.PhaseChanged("PackageHeist")RunService.RenderStepped:fire()
check(not find("PackageMarker").Enabled and not find("ExtractionStatus").Visible,"No stale objectives in next round")
script.Destroying:fire()check(events.PackageState==nil and events.ExtractionState==nil and #RunService.RenderStepped.listeners==0,"Package HUD teardown")
print("Package client: "..checks.." actual-source assertions passed")
`;
const out=path.join(os.tmpdir(),'cover-story-package-client.luau');fs.writeFileSync(out,harness);
const result=cp.spawnSync(process.argv[2]||'luau',[out],{encoding:'utf8'});process.stdout.write(result.stdout||'');process.stderr.write(result.stderr||'');if(result.error)throw result.error;process.exitCode=result.status??1;
