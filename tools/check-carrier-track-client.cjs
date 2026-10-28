// Actual CarrierTrackController with deterministic remote/input/audio/UI fixtures; not a Studio playtest.
const fs=require('node:fs'),cp=require('node:child_process'),path=require('node:path'),os=require('node:os');
const read=p=>fs.readFileSync(path.join(__dirname,'..',p),'utf8');
const fixture=read('tools/check-match-client.cjs');
const ui=fixture.slice(fixture.indexOf('local objects={}'),fixture.indexOf('local Accessibility='));
const source=read('src/client/Controllers/CarrierTrackController.luau');
const body=source.slice(source.indexOf('local CarrierTrackController ='));
const cfg=read('src/shared/GameConfig.luau');
const a=cfg.indexOf('\tCarrierTrackHud = {'),b=cfg.indexOf('\n\t-- GPS routes',a);
const harness=String.raw`
local checks=0
local function check(value,message)assert(value,message)checks+=1 end
local now=100
local os={clock=function()return now end}
local Vector2={new=function(...)return {...}end,zero={}}
local UDim2={new=function(...)return {...}end,fromOffset=function(...)return {...}end}
local Color3={fromRGB=function(...)return {...}end}
local Enum={KeyCode={T={Name="T"},ButtonL3={Name="ButtonL3"}},UserInputState={Begin=1,End=2,Cancel=3},ContextActionResult={Pass=0,Sink=1}}
local GameConfig={Combat={InputPriority=3000}}
local settings={
`+cfg.slice(a,b)+String.raw`
}
GameConfig.CarrierTrackHud=settings.CarrierTrackHud GameConfig.CarrierTrack=settings.CarrierTrack
`+ui+String.raw`
theme.PaddingPixels=12 theme.CaptionSize=12 theme.MarginPixels=24 theme.VitalsHeightPixels=72 theme.ActionWidthPixels=252 theme.ActionHeightPixels=58
local baseNew=Instance.new
Instance.new=function(class)
 local v=baseNew(class)v.Enabled=true v.Activated=signal()
 function v:Play()self.plays=(self.plays or 0)+1 self.playing=true end
 function v:Stop()self.playing=false end
 return v
end
local edge=1
HudKit.edgeGlow=function()return {setAll=function(v)edge=v end}end
local reduced=false
local Accessibility={reducedMotion=function()return reduced end}
local SoundService={}
local character=Instance.new("Model")
local humanoid=Instance.new("Humanoid")humanoid.Health=100 humanoid.Parent=character
local player={Character=character,CharacterAdded=signal()}
local Players={LocalPlayer=player}
local Package={state=function()return nil end}
local UserInputService={WindowFocusReleased=signal(),WindowFocused=signal(),TextBoxFocused=signal(),GetFocusedTextBox=function()return nil end}
local events={}local actions={}local sent={}
local Remote={connect=function(name,fn)events[name]=fn return {Disconnect=function()events[name]=nil end}end,fire=function(name,value)table.insert(sent,{name,value})end}
local ContextActionService={BindActionAtPriority=function(_,name,fn)actions[name]=fn end,UnbindAction=function(_,name)actions[name]=nil end}
local heartbeat=signal()
local RunService={Heartbeat=heartbeat}
local script={Destroying=signal()}
local Controller=(function()
`+body+String.raw`
end)()
Controller.Init()Controller.Start()
local key=GameConfig.CarrierTrackHud.Key
local pad=GameConfig.CarrierTrackHud.Pad
local function input(state,k)return actions.CarrierTrack("",state,{KeyCode=k or key})end
local function tick(seconds)now+=seconds or .05 heartbeat:fire(seconds or .05)end
input(Enum.UserInputState.Begin)check(#sent==0,"lobby cannot track")
events.PhaseChanged("PackageHeist")tick()
check(not find("CarrierTrackHint").Visible,"noncarrier has no hint")
input(Enum.UserInputState.Begin)check(#sent==0,"noncarrier cannot send")
events.PackageState({YouCarry=true})tick()
check(find("CarrierTrackHint").Visible,"only carrier sees hint")
input(Enum.UserInputState.Begin)
check(#sent==1 and sent[1][1]=="RequestCarrierTrack" and sent[1][2]==true,"key down sends true")
input(Enum.UserInputState.Begin)check(#sent==1,"repeat key down ignored")
input(Enum.UserInputState.Begin,pad)input(Enum.UserInputState.End)
check(#sent==1,"second device retains held state")
input(Enum.UserInputState.End,pad)
check(#sent==2 and sent[2][2]==false,"last key up sends false; no client tap inference")
events.CarrierTrackState({Mode="Ping",Marks={{X=1,Y=0,Z=1}},Seconds=1,Intel=4})
local points,v=Controller.marks()check(#points==1,"Ping displays server mark")
tick(.9)check(#Controller.marks()==1,"Ping lasts sent Seconds")
tick(.11)local expired,version=Controller.marks()check(#expired==0 and version>v,"Ping expires from receipt")
events.CarrierTrackState({Mode="Live",Marks={{X=1},{X=2}},Intel=3})
check(#Controller.marks()==2,"Live displays all server marks")
events.CarrierTrackState({Mode="Live",Marks={{X=3}},Intel=3})
check(#Controller.marks()==1 and Controller.marks()[1].X==3,"Live replaces marks")
events.CarrierTrackState({Mode="End",Marks={},Intel=3})check(#Controller.marks()==0,"End clears")
input(Enum.UserInputState.Begin)UserInputService.WindowFocusReleased:fire()
check(sent[#sent][2]==false,"focus loss releases server hold")
local count=#sent
input(Enum.UserInputState.Begin)check(#sent==count,"unfocused key ignored")
UserInputService.WindowFocused:fire()
input(Enum.UserInputState.Begin)UserInputService.TextBoxFocused:fire()
check(sent[#sent][2]==false,"text focus releases hold")
input(Enum.UserInputState.Begin)events.PackageState({YouCarry=false})tick()
check(not find("CarrierTrackHint").Visible and sent[#sent][2]==false,"carrier loss releases and hides")
events.CarrierTrackState({Mode="Live",Marks={{X=4}},Intel=2})check(#Controller.marks()==0,"late marks ignored after loss")
local sound=find("LocalTrackedWhisper")
events.TrackedCue()tick()
check(sound.plays==1 and sound.Parent==SoundService,"cue is local nondirectional audio")
check(edge>=.9 and edge<1,"vignette is faint")
tick(.5)local fading=edge tick(.2)check(edge>fading,"normal cue fades without pulses")
reduced=true events.TrackedCue()tick()
local steady=edge tick(.5)check(edge==steady,"Reduce Motion keeps steady faint vignette")
tick(1)check(edge==1 and not sound.playing,"cue expires/stops audio")
events.PackageState({YouCarry=true})input(Enum.UserInputState.Begin)
events.Downed()tick()
check(sent[#sent][2]==false and not find("CarrierTrackHint").Visible,"downed releases/hides")
events.TrackedCue()check(not sound.playing,"no cue after downed")
events.Revived()events.PackageState({YouCarry=true})input(Enum.UserInputState.Begin)
events.PhaseChanged("Results")tick()check(sent[#sent][2]==false and #Controller.marks()==0,"match exit releases and clears")
script.Destroying:fire()
check(actions.CarrierTrack==nil and #heartbeat.listeners==0 and next(events)==nil,"teardown cleans bindings and remotes")
print("Carrier tracking: "..checks.." actual-source assertions passed")
`;
const file=path.join(os.tmpdir(),'cover-story-carrier-track-client.luau');fs.writeFileSync(file,harness);process.stdout.write(cp.execFileSync(process.argv[2]||'luau',[file],{encoding:'utf8'}));
