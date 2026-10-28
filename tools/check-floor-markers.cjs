// Uses authored levels and generated volume geometry, then executes the real band resolver/streaming controller.
const fs=require('node:fs'),path=require('node:path'),os=require('node:os'),cp=require('node:child_process');
const root=path.resolve(__dirname,'..'),read=p=>fs.readFileSync(path.join(root,p),'utf8');
const build=read('src/server/Tools/Gala/Build.luau');
if(!build.includes('`Zone_{levelName}_T{piece.room.tier}_{piece.room.id}`')||!build.includes('y + height / 2 - 1'))throw Error('Generated floor-volume protocol changed');
const topHeight=Number(build.match(/local ZONE_H = (\d+)/)?.[1]);if(!topHeight)throw Error('Missing authored top height');
const sources=['Layout','Relayout'].map(name=>{
 const raw=read(`src/server/Tools/Gala/${name}.luau`).match(/levels = \{([^}]+)\}/)?.[1];if(!raw)throw Error('Authored levels changed');
 const levels=[...raw.matchAll(/(\w+) = (-?\d+)/g)].map(m=>({name:m[1],y:Number(m[2])})).sort((a,b)=>a.y-b.y);
 return {name,levels};
});
const volumeSets=sources.map(source=>`{Name="${source.name}",Volumes={${source.levels.map((l,i)=>{
 const h=(source.levels[i+1]?.y??(l.y+topHeight))-l.y;
 return `volume("Zone_${l.name}_T1_room",${l.y+h/2-1},${h})`;
}).join(',')}}}`).join(',');
const bands=read('src/client/Combat/FloorBands.luau');
const rawController=read('src/client/Controllers/FloorMarkerController.luau');
const start=rawController.indexOf('local FloorMarkerController =');if(start<0)throw Error('Controller boundary changed');
const harness=`
local checks=0
local function check(value,message)assert(value,message)checks+=1 end
local function volume(name,center,height)
 local item={Name=name,Position={Y=center},Size={Y=height}}
 function item:IsA(kind)return kind=="BasePart"end
 function item:SetAttribute()error("No map/character decoration")end
 function item:GetAttribute()error("Floor lookup needs no identity attributes")end
 return item
end
local FloorBands=(function()${bands}end)()
for _,source in {${volumeSets}}do
 local model=FloorBands.new()
 for _,part in source.Volumes do model.add(part)end
 for index,part in source.Volumes do
  local low=part.Position.Y-part.Size.Y/2
  local high=part.Position.Y+part.Size.Y/2
  local name=string.match(part.Name,"^Zone_(.-)_T")
  check(model.nameAt(low)==name,"Inclusive authored lower boundary")
  check(model.nameAt(high-.01)==name,"Inside authored upper boundary")
  check(model.hint(low+2,high-2)=="","Same named floor despite vertical separation")
  if index<#source.Volumes then
   local nextPart=source.Volumes[index+1]
   local target=nextPart.Position.Y
   local nextName=string.match(nextPart.Name,"^Zone_(.-)_T")
   check(model.hint(low+2,target)=="↑ "..nextName,"Next authored floor above")
   check(model.hint(target,low+2)=="↓ "..name,"Previous authored floor below")
  end
 end
 local first=source.Volumes[1]
 local duplicate=volume(first.Name,first.Position.Y,first.Size.Y)
 model.add(duplicate)model.remove(first)
 check(model.nameAt(duplicate.Position.Y)~=nil,"Duplicate rooms preserve a floor on stream-out")
 model.remove(duplicate)
 check(model.nameAt(duplicate.Position.Y)==nil,"Last streamed room removes its floor")
 check(model.hint(-1000,0)=="" and model.hint(0,1000)=="","Unknown height does not invent a floor")
 model.clear()check(model.nameAt(0)==nil,"Clear removes cached floor data")
end
local model=FloorBands.new()
local ground=volume("Zone_G_T0_public",11,24)
local mezzanine=volume("Zone_M_T1_staff",35,24)
model.add(ground)model.add(mezzanine)
check(model.hint(3,13)=="","A ten-stud change in one room is not a new floor")
model.add(ground)model.remove(ground)
check(model.nameAt(3)==nil,"Repeated tag discovery does not leak reference counts")
model.add(ground)
local ambiguous=volume("Zone_other_T1_room",11,24)model.add(ambiguous)
check(model.nameAt(3)==nil and model.hint(3,35)=="","Ambiguous bands yield no arrow")
model.remove(ambiguous)check(model.nameAt(3)=="G","Ambiguity resolves after stream-out")
model.add(volume("UnknownMarker",11,24))check(model.nameAt(3)=="G","Unrelated names ignored")
model.add(volume("Zone_fake_T1_room",100,0))check(model.nameAt(100)==nil,"Invalid height ignored")
local function signal()
 local s={listeners={}}
 function s:Connect(fn)table.insert(self.listeners,fn)return {Disconnect=function()for i,f in self.listeners do if f==fn then table.remove(self.listeners,i)break end end end}end
 function s:fire(...)for _,fn in table.clone(self.listeners)do fn(...)end end
 return s
end
local added,removed=signal(),signal()
local CollectionService={GetTagged=function()return {ground,mezzanine}end,GetInstanceAddedSignal=function()return added end,GetInstanceRemovedSignal=function()return removed end}
local Enums={Tag={ZoneVolume="ZoneVolume"}}
local Janitor={new=function()
 local j={items={}}
 function j:Add(item)table.insert(self.items,item)end
 function j:Destroy()for i=#self.items,1,-1 do local item=self.items[i]if type(item)=="function"then item()else item:Disconnect()end end table.clear(self.items)end
 return j
end}
local workspace={CurrentCamera={CFrame={Position={Y=3}}}}
local script={Destroying=signal()}
local Controller=(function()${rawController.slice(start)}end)()
Controller.Init()Controller.Start()
check(Controller.hint({Y=35})=="↑ M","Controller reads current camera floor")
removed:fire(mezzanine)check(Controller.hint({Y=35})=="","Missing streamed floor stays unknown")
added:fire(mezzanine)check(Controller.hint({Y=35})=="↑ M","Restreamed floor returns")
workspace.CurrentCamera={CFrame={Position={Y=35}}}
check(Controller.hint({Y=3})=="↓ G","Camera replacement/spectator floor")
workspace.CurrentCamera=nil check(Controller.hint({Y=3})=="","No camera is safe")
workspace.CurrentCamera={CFrame={Position={Y=3}}}
script.Destroying:fire()
check(#added.listeners==0 and #removed.listeners==0 and Controller.hint({Y=35})=="","Controller clears stream hooks/cache")
print("Floor markers: "..checks.." actual-source assertions passed across both authored layouts")
`;
const out=path.join(os.tmpdir(),'cover-story-floor-markers.luau');fs.writeFileSync(out,harness);
const result=cp.spawnSync(process.argv[2]||'luau',[out],{encoding:'utf8'});process.stdout.write(result.stdout||'');process.stderr.write(result.stderr||'');if(result.error)throw result.error;process.exitCode=result.status??1;
