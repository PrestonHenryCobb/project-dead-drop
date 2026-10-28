// Actual Asset definitions, draft, Assets view, lock-in, confirmed HUD and map-safe controller.
const fs=require('node:fs'),path=require('node:path'),os=require('node:os'),cp=require('node:child_process');
const read=p=>fs.readFileSync(path.join(__dirname,'..',p),'utf8');
function between(s,a,b){const i=s.indexOf(a),j=s.indexOf(b,i);if(i<0||j<0)throw Error(a);return s.slice(i,j);}
function after(s,a){const i=s.indexOf(a);if(i<0)throw Error(a);return s.slice(i);}
const fixture=between(read('tools/check-match-client.cjs'),'local objects={}','local Accessibility=');
const def=after(read('src/shared/Defs/AssetDefs.luau'),'local rarities:');
const draft=after(read('src/client/Menu/AssetDraft.luau'),'local AssetDraft =');
const style=after(read('src/client/Combat/AssetStyle.luau'),'local AssetStyle =');
const hud=after(read('src/client/Controllers/AssetHudController.luau'),'local AssetHudController =');
const safe=after(read('src/client/Controllers/AssetSafeController.luau'),'local AssetSafeController =');
const view=after(read('src/client/Menu/Views/AssetsCodexView.luau'),'local cleanup =');
const picker=after(read('src/client/Menu/LobbyViews/PreDeployView.luau'),'local PreDeployView =');
const menuFixture=between(read('tools/check-gadget-hud.cjs'),'local player={UserId=1}','local AssetDraft=');
const config=read('src/shared/GameConfig.luau');
const graphic=between(config,'\t\tGraphicHud = {','\n\t\t-- Ticket 19-traversal-warnings:');
const hudConfig=between(config,'\tAssetHud = {','\n\t-- Ticket 18e,');
const harness=`
local checks=0 local function check(v,msg)assert(v,msg)checks+=1 end
local cm={}local function color(value)return setmetatable({value=value},cm)end
cm.__index={Lerp=function(a,b,t)return color(a.value+(b.value-a.value)*t)end}
local Color3={fromRGB=function(r,g,b)return color((r+g+b)/3)end,new=function(r,g,b)return color(r+g+b)end}
local Vector2={new=function(...)return {...}end,zero={}}
local UDim2={new=function(...)return {...}end,fromOffset=function(...)return {...}end,fromScale=function(...)return {...}end}
local UDim={new=function(...)return {...}end}
local Enum={Font={GothamMedium=1},TextXAlignment={Left=1},AutomaticSize={X=1,Y=2}}
local GameConfig={Assets={DefaultPicks={"LightFeet","QuickHands","SteadyNerves","DeepPockets"},RarityByTier={[0]="FieldAgent",[1]="Infiltrator",[2]="BlackOps",[3]="Ghost"}},Zones={TierColors={[0]=color(10),[1]=color(20),[2]=color(30),[3]=color(40)}},Gadgets={Slots=2,DefaultPicks={"MedInjector","PlatePack"}}}
GameConfig.UI={GraphicHud=({${graphic}}).GraphicHud}
GameConfig.AssetHud=({${hudConfig}}).AssetHud
GameConfig.Menu={GapPixels=12,CornerPixels=3,TrimPixels=1,PaddingPixels=12,ChipHeightPixels=22,TextSizes={Display=28,Small=14},SecondaryHeightPixels=44,RosterCardPixels=90,LeftRailPixels=280,RightRailPixels=320}
local config=GameConfig.Menu
${fixture}
theme=GameConfig.UI.GraphicHud
local oldNew=Instance.new
Instance.new=function(class)
 local o=oldNew(class)o.attrs={}o.attrSignals={}
 function o:IsA(k)return self.ClassName==k or (k=="BasePart"and self.ClassName=="Part")end
 function o:GetAttribute(k)return self.attrs[k]end
 function o:GetAttributeChangedSignal(k)if not self.attrSignals[k]then self.attrSignals[k]=signal()end return self.attrSignals[k]end
 function o:Destroy()if self.destroyed then return end self.destroyed=true self.Destroying:fire()for _,c in self.children do c:Destroy()end self.Parent=nil end
 return o
end
local oldPanel=HudKit.panel
HudKit.panel=function(parent,name,pos,anchor,size)local p=oldPanel(parent,name)p.Parent.Position=pos p.Parent.Size=size return p end
local HudScale={bind=function()end}
local DeepFreeze=function(v)return v end local Types={}
local AssetDefs=(function()${def}end)()
local Draft=(function()${draft}end)()
local Style=(function()${style}end)()
check(#AssetDefs.order==6 and #AssetDefs.rarities==4,"Real six Assets and four rarity order loaded")
for _,id in AssetDefs.order do for _,rarity in AssetDefs.rarities do
 check(Style.value(id,rarity)==string.format("%+.0f%%",AssetDefs.valueOf(id,rarity)*100),"Shared source value "..id..rarity)
end end
check(Style.value("LightFeet","Ghost")=="-50%"and Style.value("SteadyNerves","Ghost")=="+150%","Signed fractional values displayed correctly")
local corrupt=Draft.get({"bad","QuickHands","QuickHands"})local seen={}
for _,id in corrupt do check(AssetDefs.get(id)and not seen[id],"Initial list normalized for draft only")seen[id]=true end
Draft.get(GameConfig.Assets.DefaultPicks)
local copy=Draft.get()copy[1]="DuctRat"check(Draft.get()[1]=="LightFeet","Returned list cannot mutate draft")
check(not Draft.choose(1,"QuickHands")and not Draft.choose(5,"DuctRat")and not Draft.choose(1,"bad"),"Duplicate/invalid picks refused locally")
local events={}local requests={}local RemoteController={connect=function(name,fn)events[name]=fn return {Disconnect=function()events[name]=nil end}end,fire=function(...)table.insert(requests,{...})end}
local script={Destroying=signal()}
local RunService={Heartbeat=signal()}
local Hud=(function()${hud}end)()Hud.Init()Hud.Start()
check(not find("AssetStrip").Visible,"No guessed initial Assets")
local wire={Slots={}}
for index,rarity in AssetDefs.rarities do table.insert(wire.Slots,{Rarity=rarity,AssetId=GameConfig.Assets.DefaultPicks[index],Found=false})end
events.AssetState(wire)check(not find("AssetStrip").Visible,"Lobby hides confirmed state")events.PhaseChanged("Infiltration")check(find("AssetStrip").Visible,"Match shows confirmed four slots")
local function child(parent,name)for _,o in parent.children do if o.Name==name then return o end end error(name)end
local function panel(rarity)return find(rarity).children[1]end
check(child(panel("FieldAgent"),"AssetRarity").Text=="Field Agent · NOT FOUND","Unfound slot identified without activating it")
wire.Slots[4].Found=true events.AssetState(wire)
check(child(panel("Ghost"),"AssetRarity").TextColor3==Style.color("Ghost")and child(panel("Ghost"),"AssetName").TextColor3==theme.TextColor,"Only confirmed Found lights rarity/name")
events.PhaseChanged("VaultBreach")check(child(panel("Ghost"),"AssetRarity").Text:find("FOUND",1,true),"Phase transition does not clear found Assets")
local added,removed=signal(),signal()local workspace={GetServerTimeNow=function()return 100 end}
local map=Instance.new("Folder")map.Parent=workspace
local function safePart(rarity)local p=Instance.new("Part")p.Color=color(1)p.attrs={Rarity=rarity,Opened=false}p.Parent=map return p end
local safes={}for _,r in AssetDefs.rarities do table.insert(safes,safePart(r))end
local actor=Instance.new("Model")actor.Parent=workspace local humanoid=Instance.new("Humanoid")humanoid.Parent=actor
local actorPart=Instance.new("Part")actorPart.Color=color(99)actorPart.attrs={Rarity="Ghost"}actorPart.Parent=actor table.insert(safes,actorPart)
local CollectionService={GetTagged=function()return safes end,GetInstanceAddedSignal=function()return added end,GetInstanceRemovedSignal=function()return removed end}
local Enums={Tag={AssetSafe="AssetSafe"}}
local SafeController=(function()${safe}end)()SafeController.Init()SafeController.Start()
for index,rarity in AssetDefs.rarities do check(safes[index].Color==Style.color(rarity),"Safe rarity tint "..rarity)end
check(actorPart.Color.value==99,"Even an incorrectly tagged actor part stays untouched")
local first=safes[1]first.attrs.Opened=true first.attrSignals.Opened:fire()
check(math.abs(first.Color.value-10*(1-GameConfig.AssetHud.SafeDimFraction))<.0001,"Opened safe dimmed by configured fraction")
first.attrs.Opened=false first.attrSignals.Opened:fire()check(first.Color==Style.color("FieldAgent"),"New round opened reset restores rarity tint")
first.attrs.Rarity="Ghost"first.attrSignals.Rarity:fire()check(first.Color==Style.color("Ghost"),"Live rarity attribute change")
removed:fire(first)check(first.Color.value==1 and #first.attrSignals.Opened.listeners==0,"Stream-out restores original and disconnects")added:fire(first)check(first.Color==Style.color("Ghost"),"Stream-in retints")
-- Shared mock menu primitives and the actual PreDeploy view.
${menuFixture}
local AssetDraft=Draft
local GadgetDefs={order={"MedInjector","PlatePack"},get=function(id)return {Id=id,Name=id,Category="Support",Charges=1}end}
local GadgetCard={emblem=function(parent)return named("Frame",parent,"Category")end}
function MenuTheme.secondaryButton(p)
 local b=button(p)
 b.SetText=function(value)b.Instance.Text=value end
 b.SetEnabled=function(value)b.Instance.enabled=value end
 return b
end
local watch=nil
local Kit={Theme=MenuTheme}
function Kit.session(stage)
 local root=named("Frame",stage,"AssetView")local body=named("Frame",root,"Body")
 return {Body=body,Root=root,destroy=function()root:Destroy()watch=nil end,status=function()end,watch=function(fn)watch=fn fn(snapshot)end}
end
function Kit.scrollRegion(parent,name)return named("ScrollingFrame",parent,name)end
Kit.stack=function()end
function Kit.flowPanel(parent,name)return named("Frame",parent,name)end
function Kit.flowText(parent,name,text)local t=named("TextLabel",parent,name)t.Text=text return t end
local View=(function()${view}end)()
local stage=Instance.new("Frame")View.Mount(stage,navigator)
check(find("AssetSlot1").Text:find("Field Agent",1,true)and find("AssetSlot4").Text:find("Ghost",1,true),"Four slot rarity labels")
find("ChooseAsset_FieldMedic").click()
check(Draft.get()[1]=="FieldMedic"and find("AssetSlot1").Text:find("+15%",1,true),"Assets tab changes shared draft and displays slot value")
check(not find("ChooseAsset_QuickHands").enabled,"Asset used in another slot cannot be duplicated")
find("AssetSlot4").click()find("ChooseAsset_DuctRat").click()
check(Draft.get()[4]=="DuctRat"and find("AssetSlot4").Text:find("+75%",1,true),"Ghost selection uses Ghost value")
watch(snapshot)check(Draft.get()[1]=="FieldMedic","Profile redraw cannot overwrite edited draft")
check(child(panel("FieldAgent"),"AssetName").Text:find("Light Feet",1,true),"Draft choice cannot change confirmed in-match slot")
View.Unmount()check(watch==nil,"View unmount cleans session")
local Picker=(function()${picker}end)()Picker.Mount(stage,navigator)find("LockIn").click()
local request=requests[#requests]check(request[1]=="RequestLockInPreDeploy"and #request[2].AssetIds==4,"Lock-in contains four AssetIds")
check(request[2].AssetIds[1]=="FieldMedic"and request[2].AssetIds[4]=="DuctRat"and request[2].GadgetIds[1]=="MedInjector","Rarity order/draft preserved with gadget picks")
Draft.choose(1,"LightFeet")check(request[2].AssetIds[1]=="FieldMedic","Transport list detached from later edits")Picker.Unmount()
for _,s in wire.Slots do s.Found=false end events.AssetState(wire)check(child(panel("Ghost"),"AssetRarity").Text=="Ghost · NOT FOUND","Server loss/rescue reset unlights Assets")
events.PhaseChanged("Lobby")check(not find("AssetStrip").Visible,"Lobby hides and clears state")events.PhaseChanged("Insertion")check(not find("AssetStrip").Visible,"New match cannot show prior state")
for _,size in {{1280,720},{1920,1080},{2560,1440}}do
 local scale=math.clamp(math.min(size[1]/1280,size[2]/720),1,2)local h=GameConfig.AssetHud.SlotHeightPixels*4+theme.PaddingPixels*3
 check((GameConfig.AssetHud.TopPixels+h)*scale<size[2]-(theme.MarginPixels+theme.AmmoHeightPixels*2+theme.PaddingPixels)*scale,"Asset strip clears ability/ammo stack")
end
local hudGui=find("AssetHud")script.Destroying:fire()
check(hudGui.destroyed and next(events)==nil and #added.listeners==0 and #removed.listeners==0,"HUD/safe subscriptions cleaned up")
for _,p in safes do if p~=actorPart then check(p.Color.value==1,"Teardown restores original safe colour")end end
print("Assets client: "..checks.." actual-source assertions passed")
`;
const out=path.join(os.tmpdir(),'cover-story-assets-client.luau');fs.writeFileSync(out,harness);const result=cp.spawnSync(process.argv[2]||'luau',[out],{encoding:'utf8'});process.stdout.write(result.stdout||'');process.stderr.write(result.stderr||'');if(result.error)throw result.error;process.exitCode=result.status??1;
