// Runs the actual elevator controller against deterministic cab/UI/input fixtures. No Studio simulation.
const fs=require('node:fs'),path=require('node:path'),os=require('node:os'),cp=require('node:child_process');
const read=p=>fs.readFileSync(path.join(__dirname,'..',p),'utf8');
const fixture=read('tools/check-match-client.cjs');
const ui=fixture.slice(fixture.indexOf('local objects={}'),fixture.indexOf('local Accessibility='));
let body=read('src/client/Controllers/ElevatorController.luau');
body=body.slice(body.indexOf('local ElevatorController =')).replace(/local GuiService =[^\n]*\nlocal UserInputService =[^\n]*\nlocal HudKit =[^\n]*\nlocal HudTheme =[^\n]*\nlocal HeldItemController =[^\n]*\n/,'');
const harness=String.raw`
local checks=0
local function check(v,m)assert(v,m)checks+=1 end
local Vector2={new=function(...)return {...}end,zero={}}
local UDim2={new=function(...)return {...}end,fromOffset=function(...)return {...}end}
local UDim={new=function(...)return {...}end}
local Enum={SortOrder={LayoutOrder=1},UserInputState={Begin=1},ContextActionResult={Pass=0,Sink=1},ContextActionPriority={Medium={Value=1}},KeyCode={ButtonB=1,Backspace=2,Escape=3}}
`+ui+String.raw`
theme.PaddingPixels=12 theme.CaptionSize=12 theme.MarginPixels=24 theme.ActionWidthPixels=252 theme.ActionHeightPixels=58
local baseNew=Instance.new
Instance.new=function(class)
 local v=baseNew(class)
 v.Activated=signal() v.Enabled=true
 function v:IsDescendantOf(parent)local p=self.Parent while p do if p==parent then return true end p=p.Parent end return false end
 return v
end
local events={}
local sent={}
local RemoteController={connect=function(name,fn)events[name]=fn return {Disconnect=function()events[name]=nil end}end,fire=function(...)table.insert(sent,{...})end}
local GameConfig={Controls={Interact={Name="E"},InteractPad={Name="X"}},SecurityHud={RefreshSeconds=.1},Doors={Elevators={CabSlackStuds=.5,CabHeightStuds=10}},MatchHud={DisplayOrder=40},Combat={InputPriority=10}}
local Enums={Tag={ElevatorCab="Cab"}}
local GuiService={}
local blocked=false
local HeldItemController={setInterfaceBlocked=function(_,v)blocked=v end}
local UserInputService={InputBegan=signal(),GetFocusedTextBox=function()return nil end}
local actions={}
local ContextActionService={BindActionAtPriority=function(_,name,fn)actions[name]=fn end,UnbindAction=function(_,name)actions[name]=nil end}
local heartbeat=signal()
local game={GetService=function()return {Heartbeat=heartbeat}end}
local character=Instance.new("Model")
local root=Instance.new("BasePart")root.Name="HumanoidRootPart" root.Position={X=0,Y=3,Z=0}root.Parent=character
local human=Instance.new("Humanoid")human.Health=100 human.Parent=character
local Players={LocalPlayer={Character=character,CharacterAdded=signal()}}
local attrs={Stops="T:48,G:0,M:24",State="Idle",Level="G"}
local cab=Instance.new("BasePart")cab.Parent={}cab.CFrame={PointToObjectSpace=function(_,pos)return pos end}
cab.Size=setmetatable({},{__div=function()return {X=4,Y=.5,Z=4}end})
function cab:GetAttribute(name)return attrs[name]end
local CollectionService={GetTagged=function()return {cab}end}
local Controller=(function()
`+body+String.raw`
end)()
Controller.Init()Controller.Start()
local function tick()heartbeat:fire(.2)end
local function interact()actions.CoverStoryElevatorFloor("",Enum.UserInputState.Begin)end
local function click(name)find(name).Activated:fire()end
tick()check(not find("ElevatorLevels").Visible,"hidden outside match")
events.PhaseChanged("Infiltration")tick()
check(find("ElevatorLevels").Visible,"cab hint visible")
check(not blocked,"hint leaves combat available")
interact()
check(blocked,"selector blocks accidental firing")
check(#sent==0,"Interact opens selector without requesting a floor")
check(find("G").LayoutOrder==1 and find("M").LayoutOrder==2 and find("T").LayoutOrder==3,"stops sorted by height")
check(not find("G").Active and find("M").Active,"current floor disabled")
check(find("M").Modal,"mouse released while selecting")
click("M")
check(#sent==1 and sent[1][1]=="RequestElevatorFloor" and sent[1][2]=="M","exact level name requested")
check(not blocked and attrs.Level=="G","request never predicts arrival")
tick()interact()attrs.State="Moving"attrs.Level=""tick()
check(find("CabStatus").Text=="ELEVATOR · MOVING","replicated moving status")
check(not find("M").Active and not find("T").Active,"moving disables requests")
click("T")check(#sent==1,"disabled floor cannot send")
attrs.State="Open"attrs.Level="M"tick()
check(not find("M").Active and find("T").Active,"arrival updates enabled floors")
click("T")check(sent[2][2]=="T","second destination selected")
tick()interact()root.Position.X=20 tick()
check(not find("ElevatorLevels").Visible and not blocked,"leaving cab closes/releases input")
root.Position.X=0 tick()interact()
events.Downed()tick()check(not find("ElevatorLevels").Visible and not blocked,"downed closes")
events.Revived()tick()interact()
events.PhaseChanged("Results")tick()check(not find("ElevatorLevels").Visible and not blocked,"results closes")
events.PhaseChanged("Infiltration")tick()interact()
UserInputService.InputBegan:fire({KeyCode=Enum.KeyCode.Escape})check(not blocked,"Escape closes")
interact()actions.CloseElevatorSelector("",Enum.UserInputState.Begin)check(not blocked,"gamepad back closes")
attrs.Stops="invalid,G:0,X:.,M:24"tick()interact()
check(not find("M").Active and find("G").Active and not pcall(function()find("X")end),"malformed stop ignored")
check(#sent==2,"no unsolicited requests")
interact()
find("ElevatorSelector").Destroying:fire()
check(not blocked and actions.CoverStoryElevatorFloor==nil and actions.CloseElevatorSelector==nil,"teardown releases input and bindings")
check(#heartbeat.listeners==0,"teardown disconnects polling")
print("Elevator client: "..checks.." actual-source assertions passed")
`;
const file=path.join(os.tmpdir(),'cover-story-elevator-client.luau');fs.writeFileSync(file,harness);process.stdout.write(cp.execFileSync(process.argv[2]||'luau',[file],{encoding:'utf8'}));
