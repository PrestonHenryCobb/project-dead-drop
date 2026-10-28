// Actual GadgetCard/HUD/PreDeployView source with narrow GUI, state and transport fixtures.
const fs=require('node:fs'),path=require('node:path'),os=require('node:os'),cp=require('node:child_process');
const read=p=>fs.readFileSync(path.join(__dirname,'..',p),'utf8');
function between(s,a,b){const i=s.indexOf(a),j=s.indexOf(b,i);if(i<0||j<0)throw Error(a);return s.slice(i,j);}
function after(s,a){const i=s.indexOf(a);if(i<0)throw Error(a);return s.slice(i);}
const ui=between(read('tools/check-match-client.cjs'),'local objects={}','local Accessibility=');
const config=read('src/shared/GameConfig.luau');
const graphic=between(config,'\t\tGraphicHud = {','\n\t\t-- Ticket 19-traversal-warnings:');
const gadgetConfig=between(config,'\tGadgetHud = {','\n\t-- Supply Caches for intel');
const defs=after(read('src/shared/Defs/GadgetDefs.luau'),'local defs:');
const card=after(read('src/client/Combat/GadgetCard.luau'),'local GadgetCard =');
const hud=after(read('src/client/Controllers/GadgetHudController.luau'),'local GadgetHudController =');
const picker=after(read('src/client/Menu/LobbyViews/PreDeployView.luau'),'local PreDeployView =');
const harness=`
local checks=0 local function check(v,msg)assert(v,msg)checks+=1 end
local now=100 local os={clock=function()return now end}
local Color3={fromRGB=function(...)return {...}end,fromHex=function(x)return x end}
local Vector2={new=function(...)return {...}end,zero={}}
local UDim2={new=function(...)return {...}end,fromScale=function(...)return {...}end,fromOffset=function(...)return {...}end}
local UDim={new=function(...)return {...}end}
local Enum={Font={GothamMedium=1},TextXAlignment={Left=1},AutomaticSize={X=1,Y=2}}
local Types={}local DeepFreeze=function(v)return v end
local GameConfig={Gadgets={Slots=2,DefaultPicks={"MedInjector","PlatePack"}},Controls={Gadget1={Name="Two"},Gadget2={Name="Three"}}}
GameConfig.UI={GraphicHud=({${graphic}}).GraphicHud}
GameConfig.GadgetHud=({${gadgetConfig}}).GadgetHud
GameConfig.Menu={GapPixels=12,CornerPixels=3,TrimPixels=1,PaddingPixels=16,ChipHeightPixels=22,TextSizes={Display=28,Small=14},SecondaryHeightPixels=44,RosterCardPixels=90,LeftRailPixels=280,RightRailPixels=320}
local config=GameConfig.Menu
${ui}
theme=GameConfig.UI.GraphicHud
local originalNew=Instance.new
Instance.new=function(class)
 local o=originalNew(class)
 function o:Destroy()self.destroyed=true for _,c in self.children do c:Destroy()end end
 return o
end
local oldPanel=HudKit.panel
HudKit.panel=function(parent,name,pos,anchor,size)local p=oldPanel(parent,name)p.Parent.Position=pos p.Parent.AnchorPoint=anchor p.Parent.Size=size return p end
local oldText=HudKit.text
HudKit.text=function(parent,name,pos,anchor,size)local t=oldText(parent,name)t.Position=pos t.Size=size return t end
local HudScale={bind=function()end}
local GadgetDefs=(function()${defs}end)()
check(#GadgetDefs.order>=2 and GadgetDefs.get("MedInjector").Category=="Support","Real built gadget definitions loaded")
local fake={Id="FixtureRecon",Name="Fixture recon",Category="Recon",Charges=2}
local built=GadgetDefs local order=table.clone(built.order)table.insert(order,fake.Id)
GadgetDefs={order=order,get=function(id)return if id==fake.Id then fake else built.get(id)end}
local GadgetCard=(function()${card}end)()
for category,shape in {Recon="Circle",Infiltration="Diamond",Evasion="Chevron",Support="RoundedSquare"}do
 local emblem=GadgetCard.emblem(nil,category,20)
 check(emblem.Name==shape,"Category shape "..category)
 check(#emblem.children==(if category=="Evasion"then 2 else 1),"Category drawing structure "..category)
 for _,surface in emblem.children do check(surface.BackgroundColor3==GameConfig.GadgetHud.Categories[category].Color,"Category accent "..category)end
 emblem:Destroy()
end
local current=nil local reads=0 local GadgetController={state=function()reads+=1 return current end}
local UserInputService={GetStringForKeyCode=function(_,key)return if key.Name=="Two"then "2"else "3"end}
local events={}local requests={}
local RemoteController={connect=function(name,fn)events[name]=fn return {Disconnect=function()events[name]=nil end}end,fire=function(...)table.insert(requests,{...})end}
local RunService={RenderStepped=signal(),Heartbeat=signal()}
local workspace={GetServerTimeNow=function()return now end}
local script={Destroying=signal()}
local Hud=(function()${hud}end)()Hud.Init()Hud.Start()
local function frame()RunService.RenderStepped:fire()end
local function slot(i)return find("GadgetSlot"..i).children[1]end
local function child(parent,name)for _,o in parent.children do if o.Name==name and not o.destroyed then return o end end error(name)end
frame()check(not find("GadgetBar").Visible,"No pre-match bar")events.PhaseChanged("Infiltration")frame()check(not find("GadgetBar").Visible,"No fabricated inventory")
current={Slots={{Id="MedInjector",Charges=1},{Id="PlatePack",Charges=2}},Held=0}frame()
check(find("GadgetBar").Visible and child(slot(1),"GadgetName").Text=="[ 2 ] Med Injector","Configured key and real gadget name")
check(child(slot(2),"GadgetName").Text=="[ 3 ] Plate Pack","Second slot key/name")
check(not child(slot(1),"GadgetCharges").Text:find("HELD")and not child(slot(2),"GadgetCharges").Text:find("HELD"),"Held zero means neither gadget highlighted")
current={Slots=current.Slots,Held=2}frame()check(child(slot(2),"GadgetCharges").Text=="2 CHARGES · HELD","Confirmed held slot highlighted")
check(find("GadgetSlot2").children[2].Thickness==theme.StrokePixels*2,"Held border thickened")
current={Slots={{Id="MedInjector",Charges=0}},Held=1}frame()check(child(slot(1),"GadgetCharges").Text=="0 CHARGES · HELD","Zero charges are server-confirmed, not optimistic")check(not find("GadgetSlot2").Visible,"Absent second gadget hidden")
local before=#objects for _=1,100 do frame()end check(#objects==before,"HUD reuses category geometry")check(#requests==0,"HUD never requests equip/deploy")
events.PhaseChanged("Results")check(not find("GadgetBar").Visible,"Results hides gadget bar")events.PhaseChanged("Lobby")events.PhaseChanged("Insertion")check(not find("GadgetBar").Visible,"Stale previous inventory suppressed")
current={Slots={{Id=fake.Id,Charges=2}},Held=0}frame()check(find("GadgetBar").Visible and child(slot(1),"Circle").Name=="Circle","Fresh record replaces previous category")
check(reads>100,"HUD uses GadgetController state")
for _,viewport in {{1280,720},{1920,1080},{2560,1440}}do
 local scale=math.clamp(math.min(viewport[1]/1280,viewport[2]/720),1,2)
 local group=find("GadgetBar")local width,height=group.Size[1]*scale,group.Size[2]*scale
 local bottom=viewport[2]+group.Position[4]*scale
 check(viewport[1]/2-width/2>=0 and bottom-height>=0,"Gadget bar within viewport")
 check(bottom<viewport[2]-(theme.CoverBottomPixels+theme.CoverHeightPixels)*scale,"Gadget bar above cover badge")
 check(viewport[1]/2+width/2<viewport[1]-(theme.MarginPixels+theme.AmmoWidthPixels)*scale,"Gadget bar clears ammo/ability column")
end
-- Full PreDeploy view with mock menu primitives, real callbacks and no simulated server validation.
local player={UserId=1}local Players={LocalPlayer=player}
local state={Active=true,EndsAt=130,Members={{UserId=1,DisplayName="Me",AgentId="Guise",HardwareId="GuiseGun",LockedIn=false}}}
local snapshot={Profile={Mastery={},OwnedAgents={Guise=true,Parapet=true}},Loadout={AgentId="Guise",HardwareId="GuiseGun"}}
local lobbyListener=nil local snapshotListener=nil
local LobbyState={preDeploy=function()return state end,onChanged=function(fn)lobbyListener=fn return function()lobbyListener=nil end end}
local function agent(name)return {DisplayName=name,Class="Class",Talents={{Name="Talent",Description="Talent",CooldownSeconds=30}},Instincts={{Name="Instinct",Description="Instinct"}}}end
local AgentDefs={order={"Guise","Parapet"},byId={Guise=agent("Guise"),Parapet=agent("Parapet")}}
local WeaponDefs={getForAgent=function(id)return {{Id=id.."Gun",Name="Gun",Slot=1,Def=true,UnlockMasteryLevel=0}}end}
local colors={Burgundy={},Brass={},EmeraldBright={},Text={}}
local MenuTheme={Colors=colors}
function MenuTheme.infoPanel(p)return named("Frame",p.Parent,p.Name)end
function MenuTheme.stack()return {}end
function MenuTheme.label(p)local t=named("TextLabel",p.Parent,p.Name)t.Text=p.Text return t end
function MenuTheme.stateChip()return Instance.new("Frame")end
function MenuTheme.rail(parent,name)return named("ScrollingFrame",parent,name)end
local function button(p)
 local b=named("TextButton",p.Parent,p.Name)b.Text=p.Text b.enabled=p.Enabled~=false
 b.click=function()if b.enabled then p.OnActivated()return true end return false end
 return {Instance=b,SetSelected=function(value)b.selected=value end}
end
MenuTheme.secondaryButton=button MenuTheme.primaryButton=button
local navigator={snapshot=function()return snapshot end,focusAgent=function()end,onSnapshot=function(fn)snapshotListener=fn return function()snapshotListener=nil end end}
local AssetDraft={get=function()return {"LightFeet","QuickHands","SteadyNerves","DeepPockets"}end}
local Picker=(function()${picker}end)()
local stage=Instance.new("Frame")Picker.Mount(stage,navigator)
check(find("GadgetPick_MedInjector").selected and find("GadgetPick_PlatePack").selected,"Defaults initialize draft")
check(not find("GadgetPick_FixtureRecon").enabled,"Unselected gadget disabled at capacity")
find("GadgetPick_PlatePack").click()check(not find("GadgetPick_PlatePack").selected and find("GadgetPick_FixtureRecon").enabled,"Deselect frees capacity")
find("GadgetPick_FixtureRecon").click()find("LockIn").click()
local sent=requests[#requests]check(sent[1]=="RequestLockInPreDeploy"and #sent[2].GadgetIds==2,"Existing lock-in request includes GadgetIds")
check(sent[2].GadgetIds[1]=="MedInjector"and sent[2].GadgetIds[2]==fake.Id,"Ordered distinct draft sent")
check(current.Held==0 and current.Slots[1].Id==fake.Id,"Picker cannot optimistically change confirmed HUD inventory")
check(sent[2].AgentId=="Guise"and sent[2].HardwareId=="GuiseGun","Agent/weapon selection retained")
find("GadgetPick_MedInjector").click()check(#sent[2].GadgetIds==2,"Submitted list is detached from later edits")
state.Members[1].LockedIn=true lobbyListener()check(find("LockIn").enabled and find("LockIn").Text=="UPDATE LOADOUT","Gadget revisions remain available after agent/weapon lock-in")
find("LockIn").click()check(#requests[#requests][2].GadgetIds==1,"Revised picks resubmit")
find("GadgetPick_FixtureRecon").click()find("LockIn").click()check(#requests[#requests][2].GadgetIds==0,"Explicit empty list is sent, not default omission")
find("GadgetPick_PlatePack").click()find("Parapet").click()find("LockIn").click()check(requests[#requests][2].AgentId=="Parapet"and requests[#requests][2].GadgetIds[1]=="PlatePack","Changing agents preserves gadget draft")
snapshot.Loadout.GadgetIds={"MedInjector"}snapshotListener()check(find("GadgetPick_PlatePack").selected,"Profile refresh cannot overwrite current draft")
now=131 lobbyListener()check(not find("LockIn").enabled,"Cutoff disables lock-in")
Picker.Unmount()check(lobbyListener==nil and snapshotListener==nil and #RunService.Heartbeat.listeners==0,"Picker unmount unsubscribes")
now=100 snapshot.Loadout.GadgetIds={"bad","MedInjector","MedInjector","PlatePack",fake.Id}Picker.Mount(stage,navigator)
check(find("GadgetPick_MedInjector").selected and find("GadgetPick_PlatePack").selected and not find("GadgetPick_FixtureRecon").selected,"Initial profile list filtered/deduplicated/capped for display")Picker.Unmount()
local gui=find("GadgetHud")script.Destroying:fire()check(gui.destroyed and next(events)==nil and #RunService.RenderStepped.listeners==0,"Gadget HUD teardown")
print("Gadget HUD: "..checks.." actual-source assertions passed")
`;
const out=path.join(os.tmpdir(),'cover-story-gadget-hud.luau');fs.writeFileSync(out,harness);const result=cp.spawnSync(process.argv[2]||'luau',[out],{encoding:'utf8'});process.stdout.write(result.stdout||'');process.stderr.write(result.stderr||'');if(result.error)throw result.error;process.exitCode=result.status??1;
