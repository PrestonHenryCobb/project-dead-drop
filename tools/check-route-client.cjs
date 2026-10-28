// Actual GPS presentation, map and arrow sampling against deterministic UI/vector fixtures. No Studio playtest.
const fs=require('node:fs'),cp=require('node:child_process'),path=require('node:path'),os=require('node:os');
const read=p=>fs.readFileSync(path.join(__dirname,'..',p),'utf8');
const body=(p,m)=>{const s=read(p),i=s.indexOf(m);if(i<0)throw Error(m);return s.slice(i)};
const fixture=read('tools/check-match-client.cjs');
const ui=fixture.slice(fixture.indexOf('local objects={}'),fixture.indexOf('local Accessibility='));
const configSource=read('src/shared/GameConfig.luau');
const start=configSource.indexOf('\tRouteHud = {'),end=configSource.indexOf('\n\tRoute = {',start);
const controllerFixture=String.raw`
-- Actual controller polling/input/lifecycle.
Enum.AutomaticSize={Y=1} Enum.TextXAlignment={Left=1} Enum.TextYAlignment={Top=1}
Enum.UserInputState={Begin=1} Enum.ContextActionResult={Pass=0,Sink=1}
local now=100
local os={clock=function()return now end}
local originalNew=Instance.new
Instance.new=function(class)local v=originalNew(class)v.Enabled=true v.Activated=signal()return v end
theme.MarginPixels=24
local character=Instance.new("Model")
local playerRoot=Instance.new("BasePart")playerRoot.Name="HumanoidRootPart"playerRoot.Position=Vector3.new(0,3,0)playerRoot.Parent=character
local humanoid=Instance.new("Humanoid")humanoid.Health=100 humanoid.Parent=character
local Players={LocalPlayer={Character=character,CharacterAdded=signal()}}
local zoneG=zone(10)zoneG.Name="Zone_G_T0_test"zoneG.Parent={}
local CollectionService={GetTagged=function()return {zoneG}end,GetInstanceAddedSignal=function()return signal()end,GetInstanceRemovedSignal=function()return signal()end}
local Enums={Tag={ZoneVolume="ZoneVolume"}}
local FloorBands=(function()
@FLOOR_SOURCE@
end)()
local events={}local actions={}local pending={}local calls={}
local reply=result
local Remote={connect=function(name,fn)events[name]=fn return {Disconnect=function()events[name]=nil end}end,invoke=function(name,id)table.insert(calls,{name,id})return reply end}
local ContextActionService={BindAction=function(_,name,fn)actions[name]=fn end,UnbindAction=function(_,name)actions[name]=nil end}
local UserInputService={GetFocusedTextBox=function()return nil end}
local heartbeat=signal()
local RunService={Heartbeat=heartbeat}
local task={spawn=function(fn)table.insert(pending,fn)end}
local script={Destroying=signal()}
local RouteMap=Map
local hidden=false
local RouteArrows={new=function()return {hide=function()hidden=true end,update=function()hidden=false end,Destroy=function()end}end}
for _,key in {"MapKey","TargetKey","ModeKey","FloorUpKey","FloorDownKey","MapPad","TargetPad","ModePad"} do config[key]={Name=key} end
local Controller=(function()
@CONTROLLER_SOURCE@
end)()
Controller.Init()Controller.Start()
local function tick()now+=.2 heartbeat:fire(.2)end
local function flush()local q=table.clone(pending)table.clear(pending)for _,fn in q do fn()end end
local function press(name)return actions[name]("",Enum.UserInputState.Begin)end
tick()check(#pending==0 and not find("RoutePanel").Visible,"lobby never requests or shows GPS")
events.PhaseChanged("VaultBreach")tick()
check(#pending==1,"active match starts asynchronous request")
tick()tick()check(#pending==1,"only one outstanding request")
flush()tick()
check(#calls==1 and calls[1][1]=="RequestRoute","existing remote used")
check(find("RoutePanel").Visible,"route panel appears in match")
check(string.find(find("NextRouteTarget").Text,"Vault terminal",1,true)~=nil,"server-selected target named")
press("RouteSwitchMode")tick()
check(string.find(find("StepDescriptions").Text,"breaks Cover",1,true)~=nil,"fast flags rendered")
press("RouteNextTarget")tick()
check(string.find(find("NextRouteTarget").Text,"A < B",1,true)~=nil,"target name literal")
check(#calls==1,"cycling respects cadence")
reply={Targets=result.Targets,Selected="Mate:42",Intel=2,Clean=nil,Fast=nil}
for _=1,6 do tick()end flush()tick()
check(calls[#calls][2]=="Mate:42","exact server target id sent")
press("RouteToggleMap")tick()check(not find("RoutePanel").Visible,"M hides map")
press("RouteToggleMap")tick()check(find("RoutePanel").Visible,"M restores map")
events.Downed()tick()check(not find("RoutePanel").Visible and hidden,"downed hides map/arrows")
events.Revived()tick()flush()tick()
events.PhaseChanged("Results")flush()tick()
check(not find("RoutePanel").Visible and hidden,"results clear route")
events.PhaseChanged("Infiltration")tick()reply=false flush()tick()
check(find("RouteSummary").Text=="Waiting for route data","refusal clears stale path")
script.Destroying:fire()
check(#heartbeat.listeners==0 and next(actions)==nil,"teardown disconnects and unbinds")
`.replace("@FLOOR_SOURCE@",body("src/client/Combat/FloorBands.luau","local FloorBands =")).replace("@CONTROLLER_SOURCE@",body("src/client/Controllers/RouteHudController.luau","local RouteHudController ="));
const worldFixture=String.raw`
vec.__unm=function(v)return v*-1 end
function vec:Cross(v)return Vector3.new(self.Y*v.Z-self.Z*v.Y,self.Z*v.X-self.X*v.Z,self.X*v.Y-self.Y*v.X)end
Vector3.yAxis=Vector3.new(0,1,0)
Enum.Material={Neon=1}Enum.RaycastFilterType={Exclude=1}
local RaycastParams={new=function()return {}end}
local CFrame={lookAt=function(...)return {...}end}
local workspace={}
local ground=Instance.new("BasePart")ground.Parent=workspace
workspace.Raycast=function(_,from)return {Position=Vector3.new(from.X,0,from.Z),Instance=ground}end
-- Reload the actual module so its world dependencies resolve to these local fixtures.
local WorldArrows=(function()
@ARROW_SOURCE@
end)()
local world=WorldArrows.new()
local allocated=0
for _,object in objects do
 if object.Name=="RouteChevron" then
  allocated+=1
  check(object.Anchored and not object.CanCollide and not object.CanTouch and not object.CanQuery,"world arrows have no physics/query effects")
 end
end
check(allocated==config.ArrowMax*2,"fixed arrow pool")
world.update(route,Vector3.new(0,3,0),"G",floorAt,{})
local visible=0
for _,object in objects do if object.Name=="RouteChevron" and object.Transparency==0 then visible+=1 end end
check(visible>0 and visible<=allocated,"nearby route draws pooled chevrons")
world.hide()
for _,object in objects do if object.Name=="RouteChevron" then check(object.Transparency==1,"hide clears every arrow")end end
world.Destroy()
`.replace("@ARROW_SOURCE@",body("src/client/Combat/RouteArrows.luau","local RouteArrows ="));
const test=String.raw`
local checks=0
local function check(value,reason)assert(value,reason)checks+=1 end
local vec={}
vec.__index=function(v,k)if k=="Magnitude" then return math.sqrt(v.X*v.X+v.Y*v.Y+(v.Z or 0)^2)end return vec[k]end
vec.__add=function(a,b)return setmetatable({X=a.X+b.X,Y=a.Y+b.Y,Z=(a.Z or 0)+(b.Z or 0)},vec)end
vec.__sub=function(a,b)return setmetatable({X=a.X-b.X,Y=a.Y-b.Y,Z=(a.Z or 0)-(b.Z or 0)},vec)end
vec.__mul=function(a,b)if type(a)=="number" then a,b=b,a end return setmetatable({X=a.X*b,Y=a.Y*b,Z=(a.Z or 0)*b},vec)end
vec.__div=function(a,b)return a*(1/b)end
function vec:Dot(b)return self.X*b.X+self.Y*b.Y+(self.Z or 0)*(b.Z or 0)end
function vec:Lerp(b,t)return self+(b-self)*t end
local Vector3={new=function(x,y,z)return setmetatable({X=x,Y=y,Z=z},vec)end}
local Vector2={new=function(x,y)return setmetatable({X=x,Y=y},vec)end,zero={X=0,Y=0}}
local UDim2={new=function(...)return {...}end,fromOffset=function(...)return {...}end,fromScale=function(...)return {...}end}
local Color3={fromRGB=function(...)return {...}end}
local Enum={KeyCode={M=1,N=2,J=3,PageUp=4,PageDown=5,ButtonSelect=6,ButtonL1=7,ButtonR1=8}}
local GameConfig={UI={GraphicHud={DirectionEpsilonStuds=.001},WarningColor={}},Zones={TierColors={[0]={}}}}
local settings={
`+configSource.slice(start,end)+String.raw`
}
GameConfig.RouteHud=settings.RouteHud
local config=GameConfig.RouteHud
`+ui+String.raw`
theme.PaddingPixels=12 theme.CaptionSize=12 theme.PanelColor={}
local Presentation=(function()
`+body('src/client/Combat/RoutePresentation.luau','local RoutePresentation =')+String.raw`
end)()
local Arrows=(function()
`+body('src/client/Combat/RouteArrows.luau','local RouteArrows =')+String.raw`
end)()
local Map=(function()
`+body('src/client/Combat/RouteMap.luau','local RouteMap =')+String.raw`
end)()
local function floorAt(y)if y>=-1 and y<23 then return "G" elseif y>=23 and y<47 then return "M" end return nil end
local route={Points={Vector3.new(0,0,0),Vector3.new(48,0,0),Vector3.new(48,24,0),Vector3.new(96,24,0)},Length=120,HackIntel=3,CoverBreaks=1,Affordable=false,Steps={{Index=2,Kind="Elevator",CoverBreak=false},{Index=3,Kind="Hack",Detail="Door",Intel=3,CoverBreak=false},{Index=4,Kind="Vent",CoverBreak=true}}}
local result={Targets={{Id="Terminal@1,2",Name="Vault terminal",Kind="Terminal"},{Id="Mate:42",Name="A < B",Kind="Teammate"}},Selected="Terminal@1,2",Intel=2,Clean=nil,Fast=route}
check(Presentation.nextTarget(nil,nil)==nil,"no invented targets")
check(Presentation.nextTarget(result,result.Selected)=="Mate:42","cycle server ids")
check(Presentation.nextTarget(result,"Mate:42")=="Terminal@1,2","cycle wraps")
check(Presentation.nextTarget({Targets={}},nil)==nil,"empty list safe")
check(string.find(Presentation.step(route.Steps[2]),"3 Intel",1,true)~=nil,"hack Intel flag")
check(string.find(Presentation.step(route.Steps[3]),"breaks Cover",1,true)~=nil,"Cover flag")
check(Presentation.summary("Clean",nil)=="CLEAN · No route","missing clean is explicit")
check(string.find(Presentation.summary("Fast",route),"Not enough Intel",1,true)~=nil,"affordability shown")
local state=Presentation.new()
check(state.apply(result,state.revision()),"initial response accepted")
local old=state.revision()
state.cycle()
check(state.selected()=="Mate:42" and state.result().Fast==nil,"cycle clears old polyline immediately")
check(not state.apply(result,old),"late old-target reply rejected")
state.cycle()check(state.selected()=="Terminal@1,2","rapid cycling uses retained server list")
local beforeReset=state.revision()state.clear()
check(not state.apply(result,beforeReset) and state.result()==nil,"phase/lifecycle reset rejects outstanding reply")
check(state.apply(nil,state.revision()) and state.result()==nil,"refused request clears stale routes")
local points=Arrows.samples(route,Vector3.new(0,3,0),"G",floorAt)
check(#points>0 and #points<=config.ArrowMax,"bounded arrow samples")
for _,sample in points do check(floorAt(sample.Point.Y)=="G","no other-floor arrows") check(sample.Direction.X>0,"arrow direction follows route")end
check(#Arrows.samples(route,Vector3.new(0,3,0),nil,floorAt)==0,"unknown floor hides arrows")
check(#Arrows.samples(nil,Vector3.new(0,3,0),"G",floorAt)==0,"no route no arrows")
local huge={Points={Vector3.new(-100000,0,0),Vector3.new(100000,0,0)}}
check(#Arrows.samples(huge,Vector3.new(0,3,0),"G",floorAt)<=config.ArrowMax,"long segment work remains bounded")
check(#Arrows.samples({Points={Vector3.new(0,0,0),Vector3.new(0,0,0)}},Vector3.new(0,0,0),"G",floorAt)==0,"zero length safe")
local function zone(y)
 local part=Instance.new("BasePart")part.Position=Vector3.new(24,y,0)part.Size=Vector3.new(100,20,60)
 part.CFrame={PointToWorldSpace=function(_,p)return p+part.Position end,ToOrientation=function()return 0,0,0 end}
 function part:GetAttribute()return 0 end
 return part
end
local canvas=Instance.new("Frame")
local renderer=Map.new(canvas)
renderer.draw({zone(10),zone(34)},"G",floorAt,result,"Fast",Vector3.new(0,3,0))
local function count(name)local n=0 for _,v in objects do if v.Name==name and not v.destroyed then n+=1 end end return n end
check(count("Room")==1,"floor plan filters rooms by floor")
check(count("FastRoute")==1,"route segments never bridge floors in 2D")
check(count("StepFlag")==1,"step index mapped to matching floor")
check(count("You")==1 and count("Destination")==0,"no off-floor target dot")
renderer.draw({zone(10),zone(34)},"M",floorAt,result,"Fast",Vector3.new(0,3,0))
check(count("You")==0 and count("Destination")==1,"browse floor filters player and destination")
check(count("StepFlag")==2,"hack and Cover flags on destination floor")
renderer.draw({zone(10)},"G",floorAt,result,"Clean",Vector3.new(0,3,0))
check(count("StepFlag")==0 and count("FastRoute")==1,"alternate route visible without claiming selected flags")
renderer.Destroy()
check(count("Room")==0 and count("FastRoute")==0,"map teardown removes graphics")
`+ worldFixture +String.raw`
`+ controllerFixture +String.raw`
print("Route client: "..checks.." actual-source assertions passed")
`;
const file=path.join(os.tmpdir(),'cover-story-route-client.luau');fs.writeFileSync(file,test);process.stdout.write(cp.execFileSync(process.argv[2]||'luau',[file],{encoding:'utf8'}));
