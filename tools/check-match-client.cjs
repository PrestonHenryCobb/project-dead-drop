// Actual client presentation/controller bodies, deterministic clock and UI/service fixtures. No Studio playtest.
const fs=require('node:fs'),path=require('node:path'),os=require('node:os'),cp=require('node:child_process');
const root=path.resolve(__dirname,'..');
const read=p=>fs.readFileSync(path.join(root,p),'utf8');
function from(text,marker){const n=text.indexOf(marker);if(n<0)throw Error(marker);return text.slice(n);}
const model=from(read('src/client/Combat/MatchPresentation.luau'),'local MatchPresentation =');
const controller=from(read('src/client/Controllers/MatchController.luau'),'local MatchController =');
const markers=from(read('src/client/Controllers/TeammateMarkerController.luau'),'local TeammateMarkerController =');
const configSource=read('src/shared/GameConfig.luau');
const a=configSource.indexOf('\tMatchHud = {'),b=configSource.indexOf('\n\t-- Spec 3.1: modes.',a);
if(a<0||b<0)throw Error('MatchHud config boundaries changed');
const harness=`
local checks=0
local function check(value,message)assert(value,message)checks+=1 end
local now=100
local Color3={new=function(...)return {...}end}
local Vector2={new=function(x,y)return {X=x,Y=y}end,zero={X=0,Y=0}}
local UDim2={new=function(...)return {...}end,fromScale=function(...)return {...}end,fromOffset=function(...)return {...}end}
local Enum={HighlightDepthMode={AlwaysOnTop=1},ZIndexBehavior={Sibling=1},AutomaticSize={Y=1},SortOrder={LayoutOrder=1},TextXAlignment={Left=1},TextTruncate={AtEnd=1}}
local GameConfig={Debug={MenuOnJoin=true},Match={InsertionSeconds=8,BannerSeconds=3},UI={WarningColor={}},Lobby={TeamColors={{Color={}},{Color={}}}}}
local settings={${configSource.slice(a,b)}}
GameConfig.MatchHud=settings.MatchHud
local Presentation=(function()${model} end)()
local state=Presentation.new()
check(state.view(now)==nil,"No invented initial phase")
check(Presentation.clock(nil,now)=="—","Unknown clock remains unknown")
check(Presentation.clock(161,now)=="01:01","Server clock formatting")
check(Presentation.clock(99,now)=="00:00","Clock cannot go negative")
state.apply("Insertion",{StartedAt=100,EndsAt=108,Brief={Mode="Duos",TeamId=1,Teams=2,Players=4}})
check(state.view(104).fade==.5 and state.view(104).brief~=nil,"Insertion timing/brief")
state.apply("Infiltration",{StartedAt=108,MainEndsAt=948,Banner="INFILTRATE"})
check(state.view(109).mainTimer=="13:59" and state.view(109).banner=="INFILTRATE","Main clock/banner")
check(state.view(112).banner==nil and state.view(112).brief==nil,"Expired banner and prior briefing removed")
local result={WinnerTeamId=nil,Reason="MissionFailed",Teams={{TeamId=1,Won=false,Members={{DisplayName="Agent <A>",AgentId="Guise",Out=true}}}}}
state.apply("Infiltration",{StartedAt=108,MainEndsAt=948,Results=result})
check(state.view(110).results==nil,"Roster cannot be presented outside Results")
state.apply("Results",{StartedAt=948,EndsAt=963,Results=result})
check(state.view(950).results==result and state.view(950).mainTimer==nil,"Results switch")
state.apply("Lobby",{StartedAt=963})
check(state.view(964).results==nil and state.view(964).ready==nil,"Reset removes result/wait state")
state.apply("Lobby",{StartedAt=963,EndsAt=1023,ReadyPlayers=2})
check(state.view(1024).ready==2 and state.view(1024).phase=="Lobby","Zero fill clock cannot start a phase")
state.apply("Overtime",{StartedAt=963})
check(state.view(964).mainTimer=="—","No invented overtime timer")
local objects={}
local function signal()
 local s={listeners={}}
 function s:Connect(fn)
  table.insert(self.listeners,fn)
  return {Disconnect=function()for i,v in self.listeners do if v==fn then table.remove(self.listeners,i)break end end end}
 end
 function s:fire(...)local list=table.clone(self.listeners)for _,fn in list do fn(...)end end
 return s
end
local Instance={new=function(class)
 local item={ClassName=class,children={},Destroying=signal()}
 function item:Destroy()self.destroyed=true end
 function item:IsA(name)return self.ClassName==name end
 function item:FindFirstChild(name)for _,child in self.children do if child.Name==name then return child end end end
 function item:FindFirstChildOfClass(class)for _,child in self.children do if child.ClassName==class then return child end end end
 function item:SetAttribute()error("Must never decorate a character")end
 table.insert(objects,item)
 return setmetatable(item,{__newindex=function(self,key,value)
  if key=="Parent" and value and value.children then table.insert(value.children,self)end
  rawset(self,key,value)
 end})
end}
local function find(name)
 for i=#objects,1,-1 do if objects[i].Name==name and not objects[i].destroyed then return objects[i]end end
 error("Missing UI "..name)
end
local Janitor={new=function()
 local j={items={}}
 function j:Add(item)table.insert(self.items,item)return item end
 function j:Cleanup()
  for i=#self.items,1,-1 do
   local item=self.items[i]
   if type(item)=="function" then item()elseif item.Disconnect then item:Disconnect()else item:Destroy()end
  end
  table.clear(self.items)
 end
 function j:Destroy()self:Cleanup()end
 return j
end}
local theme={TextColor={},ReloadBarPixels=3}
local HudTheme={get=function()return theme end}
local function named(class,parent,name)local r=Instance.new(class)r.Name=name r.Parent=parent return r end
local HudKit={screen=function(name)return named("ScreenGui",nil,name)end,
 panel=function(parent,name)return named("Frame",named("Frame",parent,name),"Backdrop")end,
 text=function(parent,name)return named("TextLabel",parent,name)end}
local Accessibility={reducedMotion=function()return false end}
local events={}
local RemoteController={connect=function(name,fn)events[name]=fn return {Disconnect=function()events[name]=nil end}end}
local RunService={RenderStepped=signal()}
local workspace={GetServerTimeNow=function()return now end}
local script={Destroying=signal()}
local Controller=(function()${controller}end)()
Controller.Init() Controller.Start()
local brief={Mode="Duos",TeamId=1,Teams=2,Players=4}
events.PhaseChanged("Insertion",{StartedAt=100,EndsAt=108,Brief=brief})
now=104 RunService.RenderStepped:fire()
check(find("InsertionFade").Visible and find("InsertionFade").BackgroundTransparency==.5,"Controller insertion fade")
check(find("Briefing").Visible and find("Details").Text=="DUOS · 2 TEAMS · 4 PLAYERS","Controller private brief")
events.PhaseChanged("Infiltration",{StartedAt=108,MainEndsAt=948,Banner="INFILTRATE"})
now=110 RunService.RenderStepped:fire()
check(not find("Briefing").Visible and not find("InsertionFade").Visible,"Insertion UI cleared")
check(find("Clock").Text=="13:58" and find("PhaseBanner").Text=="INFILTRATE","Controller HUD clocks")
now=112 RunService.RenderStepped:fire()check(not find("PhaseBanner").Visible,"Banner expires")
events.PhaseChanged("Results",{StartedAt=948,EndsAt=963,Results=result})
now=950 RunService.RenderStepped:fire()
check(find("Result").Text=="MISSION FAILED" and find("Results").Visible,"Failure results")
check(find("ResultRow").Text=="Agent <A> · Guise · ELIMINATED" and not find("ResultRow").RichText,"Names are plain text")
local oldRow=find("ResultRow")
events.PhaseChanged("Lobby",{StartedAt=963,EndsAt=1023,ReadyPlayers=2})
now=970 RunService.RenderStepped:fire()
check(oldRow.destroyed and not find("Results").Visible,"Results destroyed on lobby reset")
check(find("Waiting").Text=="WAITING FOR PLAYERS · 2 READY · FILL 00:53","Ready-team lobby wait")
result.WinnerTeamId=1
events.PhaseChanged("Results",{StartedAt=1000,EndsAt=1015,Results=result})
RunService.RenderStepped:fire()check(find("Result").Text=="MISSION SUCCESS","Own-team success from server")
result.WinnerTeamId=2
events.PhaseChanged("Results",{StartedAt=1000,EndsAt=1015,Results=result})
check(find("Result").Text=="MISSION FAILED","Rival winner does not become own success")
script.Destroying:fire()
check(events.PhaseChanged==nil and #RunService.RenderStepped.listeners==0,"Controller listeners cleaned")
local Players={LocalPlayer={},PlayerRemoving=signal()}
local Vector3={new=function(...)return {...}end}
local MarkerController=(function()${markers}end)()
MarkerController.Init()MarkerController.Start()
local function character()
 local model=Instance.new("Model")
 local root=Instance.new("BasePart")root.Name="HumanoidRootPart"root.Parent=model
 local humanoid=Instance.new("Humanoid")humanoid.Health=100 humanoid.Parent=model
 return model,humanoid,root
end
local rig,hp,body=character()
local friend={Character=rig}
local enemy={Character=character()}
events.TeamRoster({TeamId=1,Members={Players.LocalPlayer,friend}})
local diamond=find("Teammate")
local outline=objects[#objects]
check(diamond.ClassName=="BillboardGui" and outline.ClassName=="Highlight","Marker pair")
check(diamond.Parent.Name=="PrivateTeamMarkers" and outline.Parent==diamond.Parent,"No marker children on rigs")
RunService.RenderStepped:fire()check(not diamond.Enabled,"No markers in lobby")
events.PhaseChanged("Insertion",{})RunService.RenderStepped:fire()
check(diamond.Enabled and diamond.Adornee==body and outline.Adornee==rig,"Living teammate marker")
check(diamond.AlwaysOnTop and outline.DepthMode==Enum.HighlightDepthMode.AlwaysOnTop,"Authorized through-wall visibility")
check(outline.Adornee~=enemy.Character,"Enemy cannot be discovered from world population")
local count=0 for _,obj in objects do if obj.ClassName=="BillboardGui"and not obj.destroyed then count+=1 end end
check(count==1,"Roster excludes self and nonmembers")
hp.Health=0 RunService.RenderStepped:fire()
check(not diamond.Enabled and diamond.Adornee==nil and outline.Adornee==nil,"Dead teammates unmarked")
hp.Health=1 RunService.RenderStepped:fire()check(diamond.Enabled,"Downed but living teammate remains marked")
friend.Character=nil RunService.RenderStepped:fire()check(not diamond.Enabled,"Streaming/character removal")
local newRig,newHp,newRoot=character()friend.Character=newRig RunService.RenderStepped:fire()
check(diamond.Adornee==newRoot and outline.Adornee==newRig,"Marker follows replacement rig")
events.TeamRoster({TeamId=2,Members={friend}})
check(outline.FillColor==GameConfig.Lobby.TeamColors[2].Color,"Roster color update")
events.PhaseChanged("Results",{})RunService.RenderStepped:fire()check(not diamond.Enabled,"Results hides markers")
events.TeamRoster({TeamId=2,Members={}})
check(diamond.destroyed and outline.destroyed,"Roster removal destroys visuals")
events.TeamRoster({TeamId=999,Members={friend}})
count=0 for _,obj in objects do if obj.ClassName=="BillboardGui"and not obj.destroyed then count+=1 end end
check(count==0,"Unknown team color does not grant markers")
script.Destroying:fire()
check(events.TeamRoster==nil and events.PhaseChanged==nil and #RunService.RenderStepped.listeners==0,"Marker teardown disconnects")
print("Match client: "..checks.." actual-source assertions passed")
`;
const out=path.join(os.tmpdir(),'cover-story-match-client.luau');fs.writeFileSync(out,harness);
const result=cp.spawnSync(process.argv[2]||'luau',[out],{encoding:'utf8'});
process.stdout.write(result.stdout||'');process.stderr.write(result.stderr||'');
if(result.error)throw result.error;process.exitCode=result.status??1;
