--!strict
-- Ticket gala-sculptures. Explicit, temporary Studio-only integration probes; never enabled in a saved game.
-- Run require(a fresh clone of this module).run() in the EDIT command bar. No new remotes or identity metadata.
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local ReviewHarness = {}

local SERVER = [=[
--!strict
local service = game:GetService("StudioTestService")
local args = service:GetTestArgs()
if type(args) ~= "table" or args.Tag ~= "GalaArtReview" then return end
local ok, problem = pcall(function()
    local players = game:GetService("Players")
    local deadline = os.clock() + 90
    local function waitFor(test: () -> boolean)
        repeat if test() then return end; task.wait(0.1) until os.clock() >= deadline
        error("Gala server probe timed out")
    end
    waitFor(function() return #players:GetPlayers() == 2 end)
    waitFor(function()
        local count = 0
        for _, model in workspace:GetChildren() do
            if model:IsA("Model") and model:FindFirstChild("HumanoidRootPart") then count += 1 end
        end
        return count == 202
    end)
    local shared = game.ReplicatedStorage.Shared
    local outfits = require(shared.Defs.OutfitDefs)
    local apply = require(shared.Util.OutfitApplier)
    local rigService = require(game.ServerScriptService.Server.Services.RigService)
    local common = outfits.byRole.Guest[1]
    local fixture = rigService.createNpcRig(common, CFrame.new(0,-100,0))
    for _, player in players:GetPlayers() do
        waitFor(function() return player.Character ~= nil and player.Character:FindFirstChild("SculptedSuit") ~= nil end)
        local body = player.Character :: Model
        apply.apply(body, common)
        game:GetService("RunService").Heartbeat:Wait()
        for _, name in {"SculptedSuit"} do
            local theirs = fixture:FindFirstChild(name) :: Model
            local ours = body:FindFirstChild(name) :: Model
            assert(theirs and ours, "Missing shared sculpture")
            for _, part in theirs:GetChildren() do
                if part:IsA("BasePart") then
                    local match = ours:FindFirstChild(part.Name) :: BasePart
                    assert(match and match.ClassName == part.ClassName, "Different mesh class")
                    assert((match.Size - part.Size).Magnitude < 0.01, `Different mesh fit {name}.{part.Name}: {match.Size} / {part.Size}`)
                    assert(match.Color == part.Color and match.Material == part.Material, "Different shading")
                    assert(match.MaterialVariant == part.MaterialVariant, "Different PBR variant")
                    assert(not match.CanQuery and not match.CanCollide and match.Massless, "Cosmetic changes physics")
                end
            end
        end
    end
    fixture:Destroy()
    print("GALA_REVIEW_SERVER_PASS", "two players matched the same NPC outfit")
    task.wait(45) -- cold-start clients can take 40s to load; logs independently determine pass/fail
end)
if not ok then warn("GALA_REVIEW_SERVER_FAIL", problem) end
service:EndTest(if ok then "ServerPassed" else tostring(problem))
]=]

local CLIENT = [=[
--!strict
local args = game:GetService("StudioTestService"):GetTestArgs()
if type(args) ~= "table" or args.Tag ~= "GalaArtReview" then return end
local fixtures = require(game.ReplicatedStorage.Shared.Util.Janitor).new()
local ok, problem = pcall(function()
    local player = game:GetService("Players").LocalPlayer
    local deadline = os.clock() + 90
    local hud = player.PlayerGui:WaitForChild("CombatHud", 60)
    assert(hud, "HUD did not start")
    local card = hud:WaitForChild("Vitals"):WaitForChild("Backdrop") :: Frame
    assert(card.BackgroundColor3:ToHex() == "f4efe6", "Parchment missing")
    local client = player.PlayerScripts:WaitForChild("Client")
    local accessibility = require(game.ReplicatedStorage.Shared.Util.UiAccessibility)
    local nativeMotion = game:GetService("GuiService").ReducedMotionEnabled
    assert(accessibility.reducedMotion() == nativeMotion, "Native Reduce Motion preference mismatch")
    local graphics = require(client.Controllers.GraphicsController)
    local config = require(game.ReplicatedStorage.Shared.GameConfig)
    -- Ticket gala-material-install: variant data must replicate with the same shared material contract.
    local materials = game:GetService("MaterialService")
    if args.RequireMaterials then
        for role, definition in config.Art.Materials do
            local variant = materials:FindFirstChild("Gala" .. role)
            assert(variant and variant:IsA("MaterialVariant") and variant.BaseMaterial == definition.Base, "Missing PBR variant")
            -- Map IDs are Plugin-protected: verify those in Edit, not from an ordinary client script.
        end
    end
    local lighting = game:GetService("Lighting")
    task.wait(4) -- GraphicsController gathers the city before its first refresh
    for _, mode in {"Low", "Medium", "High"} do
        graphics.setMode(mode)
        task.wait(0.2)
        assert(lighting.GlobalShadows == config.Graphics.Levels[mode].Shadows, "Shadow quality mismatch")
        assert(lighting.GalaBloom.Enabled == config.Graphics.Levels[mode].Bloom, "Bloom quality mismatch")
        assert(lighting.Ambient == (if mode == "Low" then config.Art.Lighting.LowAmbient else config.Art.Lighting.Ambient), "Ambient fallback mismatch")
    end
    graphics.setMode("Auto")
    local fx = require(client.Combat.ShotFx)
    local camera = workspace.CurrentCamera
    assert(camera)
    -- Ticket 19-traversal-warnings: exercise the real client controller and engine raycasts.
    local traversal = player.PlayerGui:WaitForChild("TraversalHud", 10)
    assert(traversal, "Traversal HUD did not start")
    local warning = traversal:WaitForChild("Warning") :: Frame
    local body = player.Character :: Model
    local root = body:FindFirstChild("HumanoidRootPart") :: BasePart
    local savedRoot, savedAnchor = root.CFrame, root.Anchored
    local savedCamera, savedType = camera.CFrame, camera.CameraType
    fixtures:Add(function()
        root.CFrame, root.Anchored = savedRoot, savedAnchor
        camera.CFrame, camera.CameraType = savedCamera, savedType
    end)
    root.Anchored = true
    root.CFrame = CFrame.new(0,500,0)
    camera.CameraType = Enum.CameraType.Scriptable
    camera.CFrame = CFrame.new(0,502,0)
    local vent = fixtures:Add(Instance.new("Part"))
    vent.Name, vent.Anchored, vent.CanCollide = "ReviewVent", true, false
    vent.Size = Vector3.new(2,2,0.2)
    vent.CFrame = camera.CFrame * CFrame.new(0,0,-4)
    vent.Parent = workspace
    game:GetService("CollectionService"):AddTag(vent, require(game.ReplicatedStorage.Shared.Enums).Tag.Vent)
    task.wait(config.UI.TraversalWarnings.CheckSeconds * 3)
    assert(warning.Visible, "Visible nearby vent had no warning")
    local wall = fixtures:Add(Instance.new("Part"))
    wall.Anchored, wall.CanCollide = true, false
    wall.Size = Vector3.new(6,6,0.2)
    wall.CFrame = camera.CFrame * CFrame.new(0,0,-2)
    wall.Parent = workspace
    task.wait(config.UI.TraversalWarnings.CheckSeconds * 3)
    assert(not warning.Visible, "Vent warning leaked through wall")
    wall:Destroy()
    vent.CFrame = camera.CFrame * CFrame.new(0,0,4)
    task.wait(config.UI.TraversalWarnings.CheckSeconds * 3)
    assert(not warning.Visible, "Vent warning ignored facing")
    fixtures:Cleanup()
    for _ = 1,24 do fx.impact(camera.CFrame.Position + camera.CFrame.LookVector * 8, Vector3.yAxis) end
    local pool = camera:FindFirstChild("CombatImpacts")
    assert(pool and #pool:GetChildren() == config.Art.ImpactPoolSize * config.Art.ImpactSpokes, "Spark pool grew")
    task.wait(config.Combat.Feedback.ImpactSeconds + 0.2)
    for _, part in pool:GetChildren() do assert((part :: BasePart).Transparency == 1, "Spark lingered") end
    repeat
        local count = 0
        for _, body in workspace:GetChildren() do
            if body:IsA("Model") and body:FindFirstChild("HumanoidRootPart") then
                assert(body:FindFirstChild("SculptedSuit"), "Client saw native-only disguise")
                count += 1
            end
        end
        if count >= 202 then break end
        task.wait(0.2)
    until os.clock() >= deadline
    assert(os.clock() < deadline, "Crowd did not replicate")
end)
fixtures:Destroy()
if ok then print("GALA_REVIEW_CLIENT_PASS", "HUD, Low/Medium/High, pooled sparks and crowd")
else warn("GALA_REVIEW_CLIENT_FAIL", problem) end
]=]

function ReviewHarness.run(): any
	assert(RunService:IsStudio() and not RunService:IsRunning(), "Run art review in Studio Edit mode")
	local server = Instance.new("Script")
	server.Name, server.Source = "GalaReviewProbe", SERVER
	local client = Instance.new("LocalScript")
	client.Name, client.Source = "GalaReviewProbe", CLIENT
	server.Parent = ServerScriptService
	client.Parent = StarterPlayer.StarterPlayerScripts
	local ok, result = pcall(function()
		return game:GetService("StudioTestService"):ExecuteMultiplayerTestAsync(2, {
			Tag = "GalaArtReview",
			RequireMaterials = game:GetService("MaterialService"):FindFirstChild("GalaIvory") ~= nil,
		})
	end)
	server:Destroy()
	client:Destroy()
	if not ok then
		error(result)
	end
	return result -- Also require TWO client PASS log entries and no FAIL entries; server result alone is insufficient.
end

return ReviewHarness
