// Executes the actual ViewKit session implementation with narrow GUI/transport fixtures.
// Usage: node tools/check-menu-session.cjs <official-luau-cli>
const fs = require('fs');
const os = require('os');
const path = require('path');
const {execFileSync} = require('child_process');
const runtime = process.argv[2];
if (!runtime) throw Error('Pass the official Luau CLI path');
const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'cover-story-menu-session-'));
const source = fs.readFileSync(path.join(__dirname, '../src/client/Menu/Components/ViewKit.luau'), 'utf8');
const prefix = `local e = require("./Fixture")
local Janitor = require("./Janitor")
local GuiService, Theme, Remote = e.GuiService, e.Theme, e.Remote
local Instance, UDim2, Enum = e.Instance, e.UDim2, e.Enum
local task = e.task
local config = {GapPixels=12}
`;
fs.writeFileSync(path.join(directory,'Actual.luau'),prefix+source.slice(source.indexOf('local Kit = {}')));
fs.copyFileSync(path.join(__dirname,'../src/shared/Util/Janitor.luau'),path.join(directory,'Janitor.luau'));
fs.writeFileSync(path.join(directory,'Fixture.luau'),`
local e = {}
e.GuiService = {}
e.UDim2 = {new=function(...) return {...} end, fromOffset=function(...) return {...} end, fromScale=function(...) return {...} end}
e.Enum={TextXAlignment={Left=1},TextYAlignment={Top=1},AutomaticSize={Y=1}}
e.Theme={Fonts={Bold=1,Body=2},TextSizes={Display=28,Body=15},Colors={Text=1}}
e.Instance={new=function(class)
 local object={ClassName=class, Children={}}
 function object:Destroy() self.destroyed=true; for _, child in self.Children do child:Destroy() end end
 return setmetatable(object,{__newindex=function(self,key,value)
  rawset(self,key,value)
  if key=='Parent' and value then table.insert(value.Children,self) end
 end})
end}
local tasks={}
e.task={spawn=function(fn)
 local thread=coroutine.create(fn)
 local ok,err=coroutine.resume(thread); assert(ok,err)
 table.insert(tasks,thread)
 return thread
end}
-- Janitor uses the CLI's global task.cancel via a wrapper added by the runner.
e.cancel=function(thread) assert(coroutine.status(thread)~="dead","must not cancel completed threads"); coroutine.close(thread) end
e.task.cancel=e.cancel
local callbacks={}
e.Remote={calls={}, result=true, reason=nil, pending=false, snapshot={Profile={Level=1}}}
function e.Remote.connect(_,callback)
 local connection={}
 callbacks[connection]=callback
 function connection:Destroy() callbacks[self]=nil end
 return connection
end
function e.Remote.invoke(name,payload)
 if e.Remote.pending then coroutine.yield() end
 if name=='GetPlayerMetaProfile' then return e.Remote.snapshot end
 table.insert(e.Remote.calls,{name,payload})
 return e.Remote.result,e.Remote.reason
end
function e.push(value) for _, callback in callbacks do callback(value) end end
function e.connections() local n=0;for _ in callbacks do n+=1 end;return n end
function e.thread() return tasks[#tasks] end
return e
`);
// The official CLI has no Roblox task library; the cleanup algorithm stays unchanged.
const janitor=fs.readFileSync(path.join(directory,'Janitor.luau'),'utf8');
fs.writeFileSync(path.join(directory,'Janitor.luau'),'local task={cancel=require("./Fixture").cancel}\n'+janitor);
fs.writeFileSync(path.join(directory,'Run.luau'),`
local e=require("./Fixture")
local Kit=require("./Actual")
local count=0
local function check(value,message) assert(value,message);count+=1 end
local stage=e.Instance.new("Frame")
local session=Kit.session(stage,"NATIVE MENU")
local received=0
session.watch(function(value) received+=1;check(value.Profile.Level>=1,"real profile delivered") end)
check(received==1,"initial profile once")
check(e.connections()==1,"one profile subscription")
e.push({Profile={Level=2}})
check(received==2 and session.snapshot().Profile.Level==2,"push replaces snapshot")
session.request("RequestEquipLoadout",{AgentId="Guise"})
check(#e.Remote.calls==1,"request sent once")
check(session.Root.Children[#session.Root.Children].Text=="Confirmed by server.","confirmation readable")
e.Remote.result=false;e.Remote.reason="LockedHardware"
session.request("RequestEquipLoadout",{})
check(session.Root.Children[#session.Root.Children].Text=="LockedHardware","refusal readable")
e.Remote.pending=true
session.request("RequestEquipLoadout",{})
local pending=e.thread()
check(coroutine.status(pending)=="suspended","pending invoke yields")
session.request("RequestEquipLoadout",{})
check(#e.Remote.calls==2,"duplicate request blocked while busy")
session.destroy()
check(coroutine.status(pending)=="dead","unmount cancels pending request")
check(e.connections()==0 and session.Root.destroyed,"unmount releases subscription and GUI")
e.push({Profile={Level=3}})
check(received==2,"unmounted callback never runs")
e.Remote.pending=false
local current={Profile={Level=4}}
local listener
local unsubscribed=false
local navigator={snapshot=function()return current end,onSnapshot=function(fn)listener=fn;return function()unsubscribed=true end end}
local shared=Kit.session(stage,"SHARED PROFILE",navigator)
shared.watch(function(value)check(value.Profile.Level>=4,"shell profile delivered")end)
check(shared.snapshot()==current,"shell snapshot reused")
check(e.connections()==0,"shell transport subscription reused")
listener({Profile={Level=5}})
check(shared.snapshot().Profile.Level==5,"shell pushes update view")
shared.destroy()
check(unsubscribed,"shell listener released")
current=nil
local waiting=Kit.session(stage,"WAIT FOR SHELL",navigator)
local delivered=0
waiting.watch(function()delivered+=1 end)
check(waiting.snapshot()==nil and delivered==0,"nil shell profile remains loading")
listener({Profile={Level=6}})
check(waiting.snapshot().Profile.Level==6 and delivered==1,"first shell push resolves loading")
waiting.destroy()
print("MENU_SESSION_PASS: "..count.." assertions")
`);
execFileSync(runtime,['Run.luau'],{cwd:directory,stdio:'inherit'});
