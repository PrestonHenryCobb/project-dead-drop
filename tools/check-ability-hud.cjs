// Execute actual AbilityHudController and DisguiseController with engine/UI fixtures.
const fs=require('node:fs'),path=require('node:path'),os=require('node:os'),cp=require('node:child_process');
const read=p=>fs.readFileSync(path.join(__dirname,'..',p),'utf8');
function between(s,a,b){const i=s.indexOf(a),j=s.indexOf(b,i);if(i<0||j<0)throw Error(a);return s.slice(i,j);}
function after(s,a){const i=s.indexOf(a);if(i<0)throw Error(a);return s.slice(i);}
const fixture=between(read('tools/check-match-client.cjs'),'local objects={}','local Accessibility=');
const ability=after(read('src/client/Controllers/AbilityHudController.luau'),'local AbilityHudController =');
const disguise=after(read('src/client/Controllers/DisguiseController.luau'),'local DisguiseController =');
const config=read('src/shared/GameConfig.luau');
const graphic=between(config,'\t\tGraphicHud = {','\n\t\t-- Ticket 19-traversal-warnings:');
const vitalsBottom=Number(config.match(/VitalsBottomPixels = (\d+)/)[1]);
const harness=`
local checks=0 local function check(v,msg)assert(v,msg)checks+=1 end
local serverNow=100 local localNow=9000 local os={clock=function()return localNow end}
local Color3={fromRGB=function(...)return {...}end}
local Vector2={new=function(...)return {...}end,zero={}}
local Vector3={new=function(...)return {...}end,zero={}}
local UDim2={new=function(...)return {...}end,fromScale=function(...)return {...}end,fromOffset=function(...)return {...}end}
local Enum={Font={GothamMedium=1},TextXAlignment={Left=1},ContextActionResult={Pass="Pass"},UserInputState={Begin="Begin",End="End",Cancel="Cancel"}}
local GameConfig={UI={CoverColors={Exposed={}},CrosshairPixels=4,ScanRingSegments=12,ScanRingRadius=24,ScanRingDimColor={},ScanRingColor={}},Zones={TierPips={1,2,3,4},TierColors={{},{},{},{}}},Controls={Ability={Name="Q"},Disguise={Name="G"}},Cover={},NPC={}}
GameConfig.UI.GraphicHud=({${graphic}}).GraphicHud
${fixture}
theme=GameConfig.UI.GraphicHud
local originalPanel=HudKit.panel
HudKit.panel=function(parent,name,position,anchor,size)local back=originalPanel(parent,name)back.Parent.Position=position back.Parent.Size=size back.Parent.AnchorPoint=anchor return back end
local originalText=HudKit.text
HudKit.text=function(parent,name,position,anchor,size)local text=originalText(parent,name)text.Position=position text.Size=size text.AnchorPoint=anchor return text end
HudKit.icon=function()end
local HudLayout={regions=function()return {Toast={Width=224,Height=36}}end,position=function()return {}end,anchor=function()return {}end}
local HudScale={bind=function()end}
local player={CharacterAdded=signal()}
local Players={LocalPlayer=player}
local ContextActionService={BindAction=function()end,UnbindAction=function()end}
local PoseAnimation={}local Aim={}local WeaponController={getStatus=function()return {active=false}end}
local OutfitDefs={byId={Staff={Role="Staff",Tier=1},Security={Role="Security",Tier=2},Executive={Role="Executive",Tier=3}}}
local script={Destroying=signal()}
local RunService={RenderStepped=signal()}
local workspace={GetServerTimeNow=function()return serverNow end}
local events={}local RemoteController={connect=function(name,fn)events[name]=fn return {Disconnect=function()events[name]=nil end}end,fire=function()error("HUD must not send gameplay requests")end}
local current=nil local reads=0
local AbilityController={cooldown=function()reads+=1 return current end}
local AbilityHud=(function()${ability}end)()
local DisguiseHud=(function()${disguise}end)()
AbilityHud.Init()AbilityHud.Start()DisguiseHud.Init()DisguiseHud.Start()
local function frame()RunService.RenderStepped:fire()end
local function visible()return find("Ability").Visible end
frame()check(not visible(),"Ability hidden before match/data")
events.PhaseChanged("Infiltration")frame()check(not visible(),"No fabricated ability name or ready state")
current={Name="Quick Change",Seconds=30,ReadyAt=130}frame()
check(visible()and find("AbilityName").Text=="[ Q ] Quick Change","Name/key use AbilityController record/config")
check(find("AbilityCooldown").Text=="30s","Server deadline drives countdown")
localNow=99999 frame()check(find("AbilityCooldown").Text=="30s","Local clock cannot advance ability cooldown")
serverNow=115.2 frame()check(find("AbilityCooldown").Text=="15s","Fractional remaining seconds round up")
serverNow=129.999 frame()check(find("AbilityCooldown").Text=="1s","No early READY at sub-second remaining")
serverNow=130 frame()check(find("AbilityCooldown").Text=="READY","Ready exactly on server deadline")
serverNow=200 frame()check(find("AbilityCooldown").Text=="READY","Expired deadline stays ready")
current={Name="Quick Change",Seconds=30,ReadyAt=210}frame()check(find("AbilityCooldown").Text=="10s","Fresh packet replaces expired deadline")
events.PhaseChanged("Results")frame()check(not visible(),"Results hides ability")
events.PhaseChanged("Lobby")frame()check(not visible(),"Lobby hides ability")
events.PhaseChanged("Insertion")frame()check(not visible(),"Prior-round record cannot appear in next match")
current={Name="New confirmed ability",Seconds=60,ReadyAt=260}frame()check(visible()and find("AbilityCooldown").Text=="60s","Fresh record restores new-round HUD")
events.PhaseChanged("VaultBreach")frame()check(visible(),"VaultBreach is in match")
events.PhaseChanged("PackageHeist")frame()check(visible(),"PackageHeist is in match")
events.PhaseChanged("Overtime")frame()check(visible(),"Overtime is in match")
check(reads>10,"HUD polls AbilityController instead of keeping duplicate cooldown state")
local function update(slots,exposed,worn)events.DisguiseUpdate({Slots=slots,Exposed=exposed or false,Worn=worn or "Staff",Insertion="Staff"})end
update({false})check(find("Stored1").Text=="G / 1 · EMPTY","Single empty slot remains visible")
update({"Staff"})check(find("Stored1").Text=="G / 1 · STAFF","Single stored role")
local original=find("Stored1")update({"Staff",false})check(find("Stored1")==original,"Existing slot label reused")
check(find("Stored2").Text=="G / 2 · EMPTY","Guise second empty slot visible")
update({false,"Security"})check(find("Stored1").Text=="G / 1 · EMPTY"and find("Stored2").Text=="G / 2 · SECURITY","False entries preserve slot order")
update({"Executive","Security"},true)check(find("Badge").Text=="TRUE FORM","Exposed worn badge preserved")
check(find("Stored1").Text:find("EXECUTIVE",1,true)and find("Stored2").Text:find("SECURITY",1,true),"Both slots remain visible in True Form")
local second=find("Stored2")update({"Security"})check(second.destroyed,"Changing to one-slot agent removes stale second label")
update({"Staff","Staff"})check(find("Stored1").Text~=find("Stored2").Text,"Duplicate stored roles retain distinct numbered slots")
for _,size in {{1280,720},{1920,1080},{2560,1440}}do
 local scale=math.clamp(math.min(size[1]/1280,size[2]/720),1,2)
 local a=find("Ability")local bottom=size[2]+a.Position[4]*scale
 check(bottom-a.Size[2]*scale>=0 and size[1]-theme.MarginPixels*scale-a.Size[1]*scale>=0,"Ability stays in viewport")
 local ammoTop=size[2]-(theme.MarginPixels+theme.AmmoHeightPixels)*scale
 check(bottom<ammoTop,"Ability does not overlap ammo")
 local nameBottom=theme.PaddingPixels+theme.CaptionSize
 local statusTop=a.Size[2]-theme.PaddingPixels-theme.NumberSize
 check(nameBottom<=statusTop,"Ability name/status do not overlap")
 for count=1,2 do
  update(if count==1 then {false}else {false,false})
  local badge=find("Disguise")local badgeTop=size[2]-(theme.CoverBottomPixels+badge.Size[2])*scale
  local vitalsBottom=size[2]-${vitalsBottom}*scale
  check(badgeTop>=vitalsBottom,"One/two-slot badge does not overlap vitals")
  check(theme.PaddingPixels*2+(count-1)*theme.CaptionSize+theme.CaptionSize<=badge.Size[2],"All slot rows fit badge")
 end
end
local abilityGui,disguiseGui=find("AbilityHud"),find("DisguiseHud")script.Destroying:fire()
check(next(events)==nil and #RunService.RenderStepped.listeners==0,"Controller event/render cleanup")
check(abilityGui.destroyed and disguiseGui.destroyed,"HUD roots destroyed")
print("Ability HUD: "..checks.." actual-source assertions passed")
`;
const out=path.join(os.tmpdir(),'cover-story-ability-hud.luau');fs.writeFileSync(out,harness);const result=cp.spawnSync(process.argv[2]||'luau',[out],{encoding:'utf8'});process.stdout.write(result.stdout||'');process.stderr.write(result.stderr||'');if(result.error)throw result.error;process.exitCode=result.status??1;
