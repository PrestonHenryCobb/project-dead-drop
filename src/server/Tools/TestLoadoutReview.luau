--!strict
-- Ticket studio-test-loadout: explicit Edit-only two-client regression. Temporary probes remove themselves.
local Review = {}
local SERVER = [=[
--!strict
local studio=game:GetService("StudioTestService")
local args=studio:GetTestArgs()
if args.Tag~="TestLoadoutReview" then return end
local connections={}
local scopeFixture
local ok,problem=pcall(function()
    local players=game:GetService("Players")
    local combat=require(game.ServerScriptService.Server.Services.CombatService)
    local default=require(game.ReplicatedStorage.Shared.GameConfig).Combat.DefaultWeapon
    local deadline=os.clock()+120
    local function waitFor(test)
        repeat if test() then return end; task.wait(0.1) until os.clock()>deadline
        error("Loadout server probe timed out")
    end
    waitFor(function() return #players:GetPlayers()==2 end)
    local driver=players:FindFirstChild("Player1")
    local observer=players:FindFirstChild("Player2")
    assert(driver and observer,"Expected two Studio test players")
    waitFor(function() return combat.getTestWeaponId(driver)~=nil and combat.getTestWeaponId(observer)~=nil end)
    if args.ScopeCheck then
        -- Explicit test snapshot only: deterministic clear LOS, with no fall damage or crowd interference.
        for index,player in {driver,observer} do
            local root=player.Character.HumanoidRootPart
            root.Anchored=true
            root.CFrame=CFrame.new(10000+(index-1)*12,10000,10000)
        end
        scopeFixture=Instance.new("BoolValue")
        scopeFixture.Name="TestScopeFixtureReady"
        scopeFixture.Value=true
        scopeFixture.Parent=game.ReplicatedStorage
    end
    assert(not combat.testCycle(driver,{}),"Accepted malformed selection")
    assert(not combat.testCycle(driver,"ArbitraryWeaponId"),"Accepted arbitrary weapon")
    local requests=0
    local done=false
    table.insert(connections,game.ReplicatedStorage.Remotes.RequestTestLoadout.OnServerEvent:Connect(function(player,action)
        if player==driver then
            if action=="Weapon" or action=="Agent" then requests+=1
            elseif action=="Sync" and requests>0 then done=true end
        end
    end))
    waitFor(function() return done end)
    local selected=combat.getTestWeaponId(driver)
    assert(selected and selected~=default,"Driver did not select a different weapon")
    assert(combat.getTestWeaponId(observer)==default,"Selection changed the other player")
    driver:LoadCharacterAsync()
    waitFor(function() return combat.getTestWeaponId(driver)==selected end)
    task.wait(8) -- both clients independently assert their own post-respawn state
    print("TEST_LOADOUT_SERVER_PASS",selected,requests)
end)
for _,connection in connections do connection:Disconnect() end
if scopeFixture then scopeFixture:Destroy() end
if not ok then warn("TEST_LOADOUT_SERVER_FAIL",problem) end
studio:EndTest(if ok then "ServerPassed" else tostring(problem))
]=]
local CLIENT = [=[
--!strict
local args=game:GetService("StudioTestService"):GetTestArgs()
print("TEST_LOADOUT_BOOT",game:GetService("HttpService"):JSONEncode(args))
if args.Tag~="TestLoadoutReview" then return end
local connection
local scopeConnection
local ok,problem=pcall(function()
    local players=game:GetService("Players")
    local player=players.LocalPlayer
    local shared=game.ReplicatedStorage.Shared
    local config=require(shared.GameConfig)
    local defs=require(shared.Defs.WeaponDefs)
    local choices=require(shared.Util.TestLoadout)
    local controllers=player.PlayerScripts:WaitForChild("Client"):WaitForChild("Controllers")
    local weapon=require(controllers.WeaponController)
    local selector=require(controllers.TestLoadoutController)
    local remote=require(controllers.RemoteController)
    local deadline=os.clock()+115
    local stage="character readiness"
    local function waitFor(test)
        repeat if test() then return end; task.wait(0.05) until os.clock()>deadline
        error("Loadout client probe timed out: "..stage)
    end
    print("TEST_LOADOUT_STAGE","controllers loaded")
    waitFor(function() return player.Character and weapon.getStatus().active end)
    print("TEST_LOADOUT_STAGE","character active")
    task.wait(1)
    local cas=game:GetService("ContextActionService")
    assert(cas:GetBoundActionInfo("StudioCycleAgent").inputTypes[1]==config.Debug.TestLoadout.AgentKey,"Agent binding missing")
    assert(cas:GetBoundActionInfo("StudioCycleWeapon").inputTypes[1]==config.Debug.TestLoadout.WeaponKey,"Weapon binding missing")
    assert(not selector.cycle("Unknown"),"Client accepted an unsupported action")
    local serial=0
    local glints=0
    local last
    connection=game.ReplicatedStorage.Remotes.TestLoadoutChanged.OnClientEvent:Connect(function(info)
        serial+=1; last=info
    end)
    scopeConnection=game.ReplicatedStorage.Remotes.ScopeGlint.OnClientEvent:Connect(function(info)
        assert(typeof(info.Position)=="Vector3" and info.Seconds>0,"Invalid scope glint")
        glints+=1
    end)
    remote.fire("RequestTestLoadout","Sync")
    stage="server acknowledgement"
    waitFor(function() return serial>0 end) -- an avatar can exist before CombatService has initialized its state
    print("TEST_LOADOUT_STAGE","server acknowledged")
    if args.ScopeCheck then
        stage="scope fixture readiness"
        waitFor(function() return game.ReplicatedStorage:FindFirstChild("TestScopeFixtureReady")~=nil end)
    end
    task.wait(0.3) -- allow initial history samples and character replication to settle
    local driver=players:WaitForChild("Player1")
    local oldBody=driver.Character
    if player~=driver then
        waitFor(function() return driver.Character and driver.Character~=oldBody end)
        task.wait(1)
        assert(weapon.getStatus().weaponId==config.Combat.DefaultWeapon,"Other player's choice leaked to observer")
        if args.ScopeCheck then assert(glints>0,"Other client received no scope glint") end
        print("TEST_LOADOUT_SCOPE_COUNT",glints)
    else
        local visited={}
        local groups={}
        local groupCount=0
        for _,def in defs.byId do if not groups[def.Agent] then groups[def.Agent]=true; groupCount+=1 end end
        local function cycle(action)
            stage="cycle "..action
            local current=weapon.getStatus().weaponId
            visited[current]=true
            local expected=choices.nextWeapon(current,action)
            assert(expected)
            local before=serial
            assert(selector.cycle(action)) -- real client request, server validation and owner acknowledgement
            waitFor(function() return serial>before and last.WeaponId==expected.Id and weapon.getStatus().weaponId==expected.Id end)
            local status=weapon.getStatus()
            assert(status.mag==expected.MagSize and status.reserve==expected.ReserveAmmo,"Ammo mismatch after selection")
            assert(not status.reloading,"Selection retained a reload")
            visited[expected.Id]=true
            print("TEST_LOADOUT_STAGE","selected",expected.Id)
            if args.ScopeCheck and expected.ScopeGlint then
                remote.fire("RequestDraw",true)
                task.wait(config.Combat.ScopeGlint.Seconds+1/config.Combat.ScopeGlint.CheckHz+0.2)
                remote.fire("RequestDraw",false)
            end
            task.wait(0.65) -- respect the actual production rate limiter
        end
        local initial=defs.get(weapon.getStatus().weaponId)
        local camera=workspace.CurrentCamera
        stage="first shot acknowledgement"
        remote.fire("FireRequest",player.Character.Head.Position,camera.CFrame.LookVector,workspace:GetServerTimeNow(),initial.Id)
        task.wait(0.2)
        remote.fire("RequestTestLoadout","Sync") -- accepted shots use prediction, not a per-shot AmmoUpdate
        waitFor(function() return weapon.getStatus().mag==initial.MagSize-1 end)
        print("TEST_LOADOUT_STAGE","shot acknowledged")
        remote.fire("ReloadRequest")
        task.wait(0.1)
        cycle("Weapon") -- invalidate the server's pending reload
        for _=1,groupCount do
            local agent=defs.get(weapon.getStatus().weaponId).Agent
            local count=0
            for _,def in defs.byId do if def.Agent==agent then count+=1 end end
            for _=1,count do cycle("Weapon") end
            cycle("Agent")
        end
        for id in defs.byId do assert(visited[id],"Did not reach registered weapon "..id) end
        if weapon.getStatus().weaponId==config.Combat.DefaultWeapon then cycle("Weapon") end
        local selected=weapon.getStatus().weaponId
        oldBody=player.Character
        remote.fire("RequestTestLoadout","Sync")
        waitFor(function() return player.Character and player.Character~=oldBody end)
        waitFor(function() return weapon.getStatus().active and weapon.getStatus().weaponId==selected end)
        assert(weapon.getStatus().mag==defs.get(selected).MagSize,"Respawn did not restore selected ammo")
    end
end)
if connection then connection:Disconnect() end
if scopeConnection then scopeConnection:Disconnect() end
if ok then print("TEST_LOADOUT_CLIENT_PASS",game.Players.LocalPlayer.Name)
else warn("TEST_LOADOUT_CLIENT_FAIL",problem) end
]=]

function Review.run(checkScope: boolean?): any
	local run = game:GetService("RunService")
	assert(run:IsStudio() and not run:IsRunning(), "Run loadout review in Studio Edit mode")
	local server = Instance.new("Script")
	server.Name, server.Source = "TestLoadoutProbe", SERVER
	local client = Instance.new("LocalScript")
	client.Name, client.Source = "TestLoadoutProbe", CLIENT
	server.Parent = game:GetService("ServerScriptService")
	client.Parent = game:GetService("StarterPlayer").StarterPlayerScripts
	local ok, result = pcall(function()
		return game:GetService("StudioTestService")
			:ExecuteMultiplayerTestAsync(2, { Tag = "TestLoadoutReview", ScopeCheck = checkScope == true })
	end)
	server:Destroy()
	client:Destroy()
	assert(ok, tostring(result))
	return result -- require the server AND BOTH independent client PASS logs
end

return Review
