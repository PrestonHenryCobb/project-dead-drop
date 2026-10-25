--!strict
-- Explicit Edit-only two-client probe. Its temporary server/client fixtures never enter the saved game.
local RunService = game:GetService("RunService")
local Review = {}
local SERVER = [=[
local service=game:GetService("StudioTestService")
local args=service:GetTestArgs()
if type(args)~="table" or args.Tag~="CrowdReadability" then return end
local ok,problem=pcall(function()
 local players=game:GetService("Players")
 local deadline=os.clock()+100
 repeat task.wait(.1) until #players:GetPlayers()==2 or os.clock()>deadline
 assert(#players:GetPlayers()==2,"Players missing")
 for _,p in players:GetPlayers() do
  repeat task.wait(.1) until (p.Character and p.Character:FindFirstChild("Head")) or os.clock()>deadline
 end
 local rigs=require(game.ServerScriptService.Server.Services.RigService)
 local outfits=require(game.ReplicatedStorage.Shared.Defs.OutfitDefs)
 local origin=Vector3.new(10000,10000,10000)
 for i,p in players:GetPlayers() do
  local root=p.Character.HumanoidRootPart
  root.Anchored=true
  root.CFrame=CFrame.new(origin+Vector3.new((i-1)*4,0,0))
 end
 local model=rigs.createNpcRig(outfits.byRole.Guest[1],CFrame.lookAt(origin+Vector3.new(2,0,-4),origin))
 local marker=Instance.new("ObjectValue")
 marker.Name="CrowdReadabilityFixture"
 marker.Value=model
 marker.Parent=game.ReplicatedStorage
 task.wait(14)
 marker:Destroy(); model:Destroy()
 print("CROWD_READABILITY_SERVER_PASS")
end)
if not ok then warn("CROWD_READABILITY_SERVER_FAIL",problem) end
service:EndTest(ok and "ServerPassed" or "ServerFailed")
]=]
local CLIENT = [=[
local args=game:GetService("StudioTestService"):GetTestArgs()
if type(args)~="table" or args.Tag~="CrowdReadability" then return end
local ok,problem=pcall(function()
 local players=game:GetService("Players")
 local player=players.LocalPlayer
 local marker=game.ReplicatedStorage:WaitForChild("CrowdReadabilityFixture",100)
 assert(marker,"Fixture not ready")
 local model=marker.Value
 local peer
 for _,p in players:GetPlayers() do if p~=player then peer=p end end
 assert(peer and peer.Character and model,"Peer/fixture missing")
 local seenNpc,seenPlayer=false,false
 local deadline=os.clock()+12
 repeat
  for _,item in {{model,"npc"},{peer.Character,"player"}} do
   local controller=item[1]:FindFirstChildOfClass("Humanoid") or item[1]:FindFirstChildOfClass("AnimationController")
   local animator=controller and controller:FindFirstChildOfClass("Animator")
   if animator then
    for _,track in animator:GetPlayingAnimationTracks() do
     if track.Animation and (track.Animation.Name=="GlanceLeft" or track.Animation.Name=="GlanceRight") then
      if item[2]=="npc" then seenNpc=true else seenPlayer=true end
     end
    end
   end
  end
  task.wait(.1)
 until (seenNpc and seenPlayer) or os.clock()>deadline
 assert(seenNpc,"No nearby NPC head glance")
 assert(seenPlayer,"No equivalent player-model head glance")
 print("CROWD_READABILITY_CLIENT_PASS",player.Name)
end)
if not ok then warn("CROWD_READABILITY_CLIENT_FAIL",problem) end
]=]

function Review.run(): any
	assert(RunService:IsStudio() and not RunService:IsRunning(), "Run this explicit review in Studio Edit")
	local server = Instance.new("Script")
	server.Name = "CrowdReadabilityServerProbe"
	server.Source = SERVER
	server.Parent = game:GetService("ServerScriptService")
	local client = Instance.new("LocalScript")
	client.Name = "CrowdReadabilityClientProbe"
	client.Source = CLIENT
	client.Parent = game:GetService("StarterPlayer").StarterPlayerScripts
	local ok, result = pcall(function()
		return game:GetService("StudioTestService"):ExecuteMultiplayerTestAsync(2, { Tag = "CrowdReadability" })
	end)
	server:Destroy()
	client:Destroy()
	if not ok then
		error(result)
	end
	return result
end

return Review
