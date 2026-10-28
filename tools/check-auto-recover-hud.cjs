// Execute actual controller state, Cover HUD progress, Settings panel and menu entry/back functions.
const fs=require('node:fs'),path=require('node:path'),os=require('node:os'),cp=require('node:child_process');
const read=p=>fs.readFileSync(path.join(__dirname,'..',p),'utf8');
function between(s,a,b){const i=s.indexOf(a),j=s.indexOf(b,i);if(i<0||j<0)throw Error(a);return s.slice(i,j);}
function after(s,a){const i=s.indexOf(a);if(i<0)throw Error(a);return s.slice(i);}
const fixture=between(read('tools/check-match-client.cjs'),'local objects={}','local Accessibility=');
const controller=after(read('src/client/Controllers/AutoRecoverController.luau'),'local AutoRecoverController =');
const settings=after(read('src/client/Menu/Components/SettingsPanel.luau'),'local SettingsPanel =');
const cover=read('src/client/Controllers/CoverController.luau');
const progress=between(cover,'local function updateAutoRecover(','\n-- Cosmetic feedback');
const menu=read('src/client/Controllers/MenuController.luau');
const footer=between(menu,'local function buildFooter(','\nlocal function bindInput(');
const back=between(menu,'local function back()','\nnavigator =');
const harness=`
local checks=0 local function check(v,msg)assert(v,msg)checks+=1 end
local now=10 local os={clock=function()return now end}
local UDim2={new=function(...)return {...}end,fromScale=function(...)return {...}end,fromOffset=function(...)return {...}end}
local UDim={new=function(...)return {...}end}local Vector2={new=function(...)return {...}end,zero={}}
local Enum={TextXAlignment={Right=1},UserInputState={Begin="Begin"},ContextActionResult={Pass="Pass"}}
local GameConfig={Cover={AutoRecoverDefault=true,AutoRecoverSeconds=999},Controls={Disguise={Name="G"},ToggleAutoRecover={Name="H"}},Security={Alarm={MaxLevel=3}},MatchHud={PanelWidthPixels=560},Menu={DisplayOrder=50,SurfaceTransparency=.1,SecondaryHeightPixels=44,PaddingPixels=12,GapPixels=12,FooterPixels=44,TabWidthPixels=104,TextSizes={Small=14}}}
${fixture}
local originalNew=Instance.new
Instance.new=function(class)
 local o=originalNew(class)
 function o:IsA(name)return self.ClassName==name or (name=="GuiObject"and (self.ClassName=="Frame"or self.ClassName=="TextLabel"or self.ClassName=="TextButton"))end
 function o:GetDescendants()local out={}local function visit(p)for _,c in p.children do table.insert(out,c)visit(c)end end visit(self)return out end
 function o:Destroy()if self.destroying or self.destroyed then return end self.destroying=true self.Destroying:fire()for _,c in self.children do c:Destroy()end self.destroyed=true self.Parent=nil end
 return o
end
local events={}local requests={}
local RemoteController={connect=function(name,fn)events[name]=fn return {Disconnect=function()events[name]=nil end}end,fire=function(name,value)assert(name=="RequestAutoRecover"and type(value)=="boolean","Only boolean option requests allowed")table.insert(requests,value)end}
local script={Destroying=signal()}
local bindings={}local ContextActionService={BindAction=function(_,name,fn)bindings[name]=fn end,UnbindAction=function(_,name)bindings[name]=nil end}
local UserInputService={GetFocusedTextBox=function()return nil end}
local RunService={Heartbeat=signal()}
local AutoRecoverController=(function()${controller}end)()AutoRecoverController.Init()AutoRecoverController.Start()
local GuiService={SelectedObject=nil}
local colors={Canvas={},TextDim={}}
local MenuTheme={Colors=colors,stack=function()return {}end}
function MenuTheme.infoPanel(p)local f=named("Frame",p.Parent,p.Name)f.Position=p.Position f.Size=p.Size return f end
function MenuTheme.label(p)local t=named("TextLabel",p.Parent,p.Name)t.Text=p.Text t.Position=p.Position t.Size=p.Size return t end
function MenuTheme.secondaryButton(p)
 local b=named("TextButton",p.Parent,p.Name)b.Text=p.Text b.Position=p.Position b.Size=p.Size
 b.click=p.OnActivated
 return {Instance=b,SetText=function(t)b.Text=t end,SetSelected=function(v)b.selected=v end}
end
local SettingsPanel=(function()${settings}end)()
local config=GameConfig.Menu
local root=Instance.new("Frame")local previous=Instance.new("TextButton")previous.Parent=root GuiService.SelectedObject=previous
SettingsPanel.open(root)check(SettingsPanel.isOpen(),"Settings opens")
check(find("AutoRecoverToggle").Text=="AUTO RE-COVER · ON"and find("AutoRecoverToggle").selected,"Default enabled before first message")
check(GuiService.SelectedObject==find("AutoRecoverToggle"),"Gamepad starts on setting toggle")
find("AutoRecoverToggle").click()check(requests[#requests]==false,"Default-on toggle requests false")
check(find("AutoRecoverToggle").Text=="AUTO RE-COVER · ON","No optimistic Enabled change")
events.AutoRecoverState({Enabled=false,Active=false,Seconds=0})RunService.Heartbeat:fire()
check(find("AutoRecoverToggle").Text=="AUTO RE-COVER · OFF"and not find("AutoRecoverToggle").selected,"Confirmed false never falls back to default true")
find("AutoRecoverToggle").click()check(requests[#requests]==true,"Confirmed off requests true")
check(find("AutoRecoverToggle").Text=="AUTO RE-COVER · OFF","Pending request preserves confirmed off")
events.AutoRecoverState({Enabled=true,Active=false,Seconds=0})RunService.Heartbeat:fire()check(find("AutoRecoverToggle").Text=="AUTO RE-COVER · ON","State from existing H toggle also refreshes menu")
-- Actual Cover refresh includes the re-cover bar while preserving normal suspicion and cover feedback.
local meterFill={}local autoRecoverFill={}
local stateLabel={}local panel={Visible=false}local warning={}local prompt={}local coverRoot={}
local alive=true local coverState="Exposed"local suspicion={Value=0,Security=0,Npc=0,Camera=0}
local trespass={Restricted=false,ZoneTier=0,Clearance=0}
local ui={CoverColors={Exposed={},Covered={}},ScanRingDimColor={},WarningColor={}}
local graphics={TextColor={},DimTextColor={}}local cover={SuspicionMax=100}
local alarmLabel=nil local lockdownBanner=nil local alarm=0 local alarmPips={}
local lockoutEndsAt=0 local exposedMinEndsAt=0 local canRecover=true local blocker=""
${progress}
refreshText(now)check(not autoRecoverFill.Visible and meterFill.Visible,"Inactive ring hidden; suspicion meter remains")
events.AutoRecoverState({Enabled=true,Active=true,Seconds=2})local info,received=AutoRecoverController.state()
check(received==now,"Actual controller timestamps receipt with os.clock")
refreshText(now)check(autoRecoverFill.Visible and autoRecoverFill.Size[1]==0 and not meterFill.Visible,"Active receipt starts bar at zero")
check(stateLabel.Text=="RE-COVERING","Cover indicator labels active recovery")
now=11 refreshText(now)check(autoRecoverFill.Size[1]==.5,"Uses reported Seconds and receipt time, not config duration")
now=9 refreshText(now)check(autoRecoverFill.Size[1]==0,"Progress clamps below receipt time")
now=50 refreshText(now)check(autoRecoverFill.Size[1]==1 and autoRecoverFill.Visible,"Elapsed duration cannot invent a server cancellation")
events.AutoRecoverState({Enabled=true,Active=false,Seconds=0})refreshText(now)
check(not autoRecoverFill.Visible and meterFill.Visible and stateLabel.Text=="EXPOSED","Server end restores existing cover/suspicion display")
events.AutoRecoverState({Enabled=true,Active=true,Seconds=4})now=51 refreshText(now)check(autoRecoverFill.Size[1]==.25,"New message resets receipt anchor")
events.AutoRecoverState({Enabled=true,Active=true,Seconds=0})refreshText(now)check(autoRecoverFill.Size[1]==1,"Zero server duration needs no invented fallback")
events.AutoRecoverState({Enabled=false,Active=false,Seconds=0})refreshText(now)check(not autoRecoverFill.Visible,"Turning off ends bar only from confirmed state")
local connections=#RunService.Heartbeat.listeners
SettingsPanel.open(root)check(#RunService.Heartbeat.listeners==connections,"Repeated opens replace rather than leak subscriptions")
find("CloseSettings").click()check(not SettingsPanel.isOpen()and #RunService.Heartbeat.listeners==0,"Close unsubscribes setting refresh")
-- Actual menu footer makes the settings screen reachable without adding a main section.
local footerLabel=nil ${footer}
buildFooter(root)find("OpenSettings").click()check(SettingsPanel.isOpen(),"Menu footer opens Settings")
local inPreDeploy=true local history={}local MAIN_TABS={}local views={}local current=nil
local mounts=0 local mount=function()mounts+=1 end local navigateTo=function()mounts+=1 end
${back}
cycleTab(1)check(SettingsPanel.isOpen()and mounts==0,"Section cycling cannot navigate behind modal")
back()check(not SettingsPanel.isOpen()and mounts==0,"B/Back closes modal before selection back guard")
local footerRoot=find("Footer")local button=find("OpenSettings")
for _,width in {1280,1920,2560}do
 local buttonLeft=width+button.Position[2]-button.Size[2]
 local labelRight=width+footerLabel.Position[2]
 check(labelRight<buttonLeft,"Footer screen label clears Settings button")
end
find("OpenSettings").click()root:Destroy()check(not SettingsPanel.isOpen()and #RunService.Heartbeat.listeners==0,"Parent teardown cleans modal")
script.Destroying:fire()check(next(events)==nil and next(bindings)==nil,"Existing state controller cleanup")
print("Auto re-cover HUD: "..checks.." actual-source assertions passed")
`;
const out=path.join(os.tmpdir(),'cover-story-auto-recover-hud.luau');fs.writeFileSync(out,harness);const result=cp.spawnSync(process.argv[2]||'luau',[out],{encoding:'utf8'});process.stdout.write(result.stdout||'');process.stderr.write(result.stderr||'');if(result.error)throw result.error;process.exitCode=result.status??1;
