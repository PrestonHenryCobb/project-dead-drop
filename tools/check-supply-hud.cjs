// Actual Supply HUD and held-item input routing, using deterministic GUI/transport/clock fixtures.
const fs=require('node:fs'),path=require('node:path'),os=require('node:os'),cp=require('node:child_process');
const read=p=>fs.readFileSync(path.join(__dirname,'..',p),'utf8');
function between(s,a,b){const i=s.indexOf(a),j=s.indexOf(b,i);if(i<0||j<0)throw Error(a);return s.slice(i,j);}
function after(s,a){const i=s.indexOf(a);if(i<0)throw Error(a);return s.slice(i);}
const fixture=between(read('tools/check-match-client.cjs'),'local objects={}','local Accessibility=');
const config=read('src/shared/GameConfig.luau');
const match=between(config,'\tMatchHud = {','\n\t-- Spec 3.1: modes.');
const graphic=between(config,'\t\tGraphicHud = {','\n\t\t-- Ticket 19-traversal-warnings:');
const hud=after(read('src/client/Controllers/SupplyHudController.luau'),'local SupplyHudController =');
const held=after(read('src/client/Controllers/HeldItemController.luau'),'local HeldItemController =');
const harness=`
local checks=0 local function check(v,msg)assert(v,msg)checks+=1 end
local now=100 local os={clock=function()return now end}
local Color3={fromRGB=function(...)return {...}end}
local Vector2={new=function(...)return {...}end,zero={}}
local UDim2={new=function(...)return {...}end,fromScale=function(...)return {...}end,fromOffset=function(...)return {...}end}
local UDim={new=function(...)return {...}end}
local Enum={Font={GothamMedium=1},AutomaticSize={Y=1},SortOrder={LayoutOrder=1},UserInputState={Begin="Begin",End="End",Cancel="Cancel",Change="Change"},ContextActionResult={Pass="Pass",Sink="Sink"},KeyCode={Escape="Escape",ButtonB="B",Backspace="Backspace"}}
local GameConfig={Combat={InputPriority=3000},Controls={Fire="Fire",FirePad="FirePad",Aim="Aim",AimPad="AimPad"}}
GameConfig.MatchHud=({${match}}).MatchHud
GameConfig.UI={GraphicHud=({${graphic}}).GraphicHud}
${fixture}
theme=GameConfig.UI.GraphicHud
local oldNew=Instance.new
Instance.new=function(class)
 local o=oldNew(class)o.Activated=signal()
 function o:IsDescendantOf(parent)local p=self.Parent while p do if p==parent then return true end p=p.Parent end return false end
 function o:Destroy()if self.destroyed then return end self.destroyed=true self.Destroying:fire()for _,c in self.children do c:Destroy()end self.Parent=nil end
 return o
end
local oldPanel=HudKit.panel
HudKit.panel=function(parent,name,pos,anchor,size)local p=oldPanel(parent,name)p.Parent.Position=pos p.Parent.AnchorPoint=anchor p.Parent.Size=size return p end
local oldText=HudKit.text
HudKit.text=function(parent,name,pos,anchor,size)local t=oldText(parent,name)t.Position=pos t.AnchorPoint=anchor t.Size=size return t end
local bindings={}local ContextActionService={BindActionAtPriority=function(_,name,fn)bindings[name]=fn end,UnbindAction=function(_,name)bindings[name]=nil end}
local UserInputService={InputBegan=signal(),WindowFocusReleased=signal(),TextBoxFocused=signal(),GetFocusedTextBox=function()return nil end}
local player={CharacterRemoving=signal(),CharacterAdded=signal()}
local Players={LocalPlayer=player}
local script={Destroying=signal()}
local RunService={RenderStepped=signal()}
local events={}local requests={}
local RemoteController={connect=function(name,fn)events[name]=fn return {Disconnect=function()events[name]=nil end}end,fire=function(...)table.insert(requests,{...})end}
local GuiService={SelectedObject=nil}
local HeldItemController=(function()${held}end)()HeldItemController.Init()HeldItemController.Start()
local fireCalls={}local aimCalls={}local heldChanges=0
local item={fire=function(s)table.insert(fireCalls,s)end,aim=function(s)table.insert(aimCalls,s)end,setHeld=function()heldChanges+=1 end}
HeldItemController.registerWeapon(item)
local Supply=(function()${hud}end)()Supply.Init()Supply.Start()
local function frame()RunService.RenderStepped:fire()end
local function click(id)find(id).Activated:fire()end
local offers={
 {Id="ArmorPlate",Name="Armor Plate",Price=17,Available=true,Reason=""},
 {Id="AmmoRefill",Name="Full ammo refill",Price=2,Available=false,Reason="Ammo is full"},
 {Id="HealToFull",Name="Heal to full",Price=3,Available=true,Reason=""},
 {Id="GadgetCharge",Name="Gadget charge",Price=3,Available=true,Reason=""},
 {Id="AbilityCooldownReset",Name="Ability cooldown reset",Price=4,Available=false,Reason="Ability is ready"},
 {Id="SecurityKeycard",Name="Security Keycard",Price=3,Available=true,Reason=""},
}
local function state(buying,intel)return {Open=true,CacheId="S2",Intel=intel or 40,Items=offers,Buying=buying,BuySeconds=2}end
check(not find("SupplyShopOverlay").Visible,"No shop before server opens it")
bindings.HeldItemFire(nil,"Begin")check(fireCalls[#fireCalls]=="Begin","Normal held input works")
events.ShopState(state())frame()
check(find("SupplyShopOverlay").Visible and find("SupplyIntel").Text=="TEAM INTEL · 40","Private server open/balance")
check(find("ArmorPlate").Text=="Armor Plate · 17 INTEL","Uses exact server price, no local base price/discount")
check(find("AmmoRefill").Text:find("Ammo is full",1,true)and not find("AmmoRefill").Active,"Unavailable reason and disabled action")
check(fireCalls[#fireCalls]=="Cancel"and aimCalls[#aimCalls]=="Cancel","Opening cancels existing fire and aim")
local n=#fireCalls check(bindings.HeldItemFire(nil,"Begin")=="Pass"and #fireCalls==n,"GUI clicks cannot shoot or deploy")
check(bindings.HeldItemAim(nil,"Begin")=="Pass","GUI right-click cannot aim/deploy alternate")
check(not find("SupplyPurchaseProgress").Visible,"No invented purchase before acknowledgement")
click("AmmoRefill")check(#requests==0,"Unavailable item sends no request")
click("ArmorPlate")check(#requests==1 and requests[1][1]=="RequestShopBuy"and requests[1][2]=="ArmorPlate","Buy sends only exact item id")
click("HealToFull")check(#requests==1,"Only one unacknowledged buy request")frame()
check(find("SupplyIntel").Text=="TEAM INTEL · 40"and not find("SupplyPurchaseProgress").Visible,"Request cannot spend Intel or start purchase locally")
events.ShopState(state("ArmorPlate"))frame()check(find("SupplyPurchaseProgress").Visible and find("SupplyPurchaseProgress").Size[1]==0,"Buying acknowledgement starts progress")
check(not find("HealToFull").Active,"No second purchase during confirmed Buying")
now=101 frame()check(find("SupplyPurchaseProgress").Size[1]==.5,"BuySeconds drives receipt-relative progress")
events.ShopState(state("ArmorPlate"))frame()check(find("SupplyPurchaseProgress").Size[1]==.5,"Same active purchase snapshot does not restart bar")
now=110 frame()check(find("SupplyPurchaseProgress").Size[1]==1 and find("SupplyPurchaseProgress").Visible,"Full bar cannot invent completion")
events.ShopState(state(nil,23))frame()check(not find("SupplyPurchaseProgress").Visible and find("SupplyIntel").Text=="TEAM INTEL · 23","Only server snapshot confirms purchase/balance")
events.ShopState(state(nil,0))frame()check(not find("ArmorPlate").Active and find("ArmorPlate").Text:find("Not enough Intel",1,true),"Affordability uses server balance")
click("CloseSupplyShop")check(requests[#requests][1]=="RequestShopClose"and not find("SupplyShopOverlay").Visible,"Close button asks server and dismisses UI")
n=#fireCalls bindings.HeldItemFire(nil,"Begin")check(#fireCalls==n+1 and heldChanges==1,"Closing restores input without changing held item")
events.ShopState(state())UserInputService.InputBegan:fire({KeyCode="Escape"})check(requests[#requests][1]=="RequestShopClose"and not find("SupplyShopOverlay").Visible,"Escape closes with existing request")
events.ShopState(state())check(bindings.CloseSupplyShop(nil,"Begin")=="Sink","B/Backspace closes contextually")check(bindings.CloseSupplyShop(nil,"Begin")=="Pass","Hidden shop cannot swallow Back")
events.ShopState(state())events.ShopState({Open=false,Items={},Intel=0,BuySeconds=2,CacheId=""})check(not find("SupplyShopOverlay").Visible,"Server close clears UI")
for _,phase in {"Lobby","Insertion","Results"}do events.ShopState(state())events.PhaseChanged(phase)check(not find("SupplyShopOverlay").Visible,"Phase closes shop: "..phase)end
events.ShopState(state())events.Downed({})check(not find("SupplyShopOverlay").Visible,"Downed closes shop")
events.ShopState(state())events.Eliminated({})check(not find("SupplyShopOverlay").Visible,"Elimination closes shop")
events.ShopState(state())player.CharacterRemoving:fire()check(not find("SupplyShopOverlay").Visible,"Character removal closes shop")
events.ShopState(state())
local panel=find("SupplyShop")local height=panel.Size[2]
local rows=find("SupplyOffers")local status=find("SupplyStatus")local bar=find("SupplyPurchaseProgress")local close=find("CloseSupplyShop")
check(rows.Size[4]+height>GameConfig.MatchHud.BodySize*2,"Scrollable offers have meaningful height")
check(rows.Position[2]+height+rows.Size[4]<=height+status.Position[4]-status.Size[4],"Offer list clears status text")
check(height+status.Position[4]<=height+bar.Position[4],"Status clears progress bar")
check(height+bar.Position[4]+theme.ReloadBarPixels<=height+close.Position[4],"Progress clears close button")
for _,size in {{1280,720},{1920,1080},{2560,1440}}do local scale=math.clamp(math.min(size[1]/1280,size[2]/720),1,2)check(panel.Size[1]*scale<size[1]and panel.Size[2]*scale<size[2],"Shop fits supported viewport")end
local gui=find("SupplyHud")script.Destroying:fire()
check(gui.destroyed and next(events)==nil and next(bindings)==nil and #RunService.RenderStepped.listeners==0 and requests[#requests][1]=="RequestShopClose","Controllers/bindings/server session cleaned up")
check(#UserInputService.InputBegan.listeners==0 and #player.CharacterRemoving.listeners==0,"Input/life subscriptions cleaned up")
print("Supply HUD: "..checks.." actual-source assertions passed")
`;
const out=path.join(os.tmpdir(),'cover-story-supply-hud.luau');fs.writeFileSync(out,harness);const result=cp.spawnSync(process.argv[2]||'luau',[out],{encoding:'utf8'});process.stdout.write(result.stdout||'');process.stderr.write(result.stderr||'');if(result.error)throw result.error;process.exitCode=result.status??1;
