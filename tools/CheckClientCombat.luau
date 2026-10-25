--!strict
-- Paste into Studio's CLIENT Command Bar during a fresh playtest. Cosmetic/math checks only; no server requests.
-- Tests real modules and CFrame math, not a second implementation of the placement algorithm.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local client = Players.LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Client")
local combat = client:WaitForChild("Combat")
local shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(shared:WaitForChild("GameConfig"))
local WeaponDefs = require(shared:WaitForChild("Defs"):WaitForChild("WeaponDefs"))
local ViewModel = require(combat:WaitForChild("ViewModel"))
local Placement = require(combat:WaitForChild("WeaponPlacement"))
local Visuals = require(combat:WaitForChild("ShotVisuals"))

local models: { any } = {}
local fixtures: { Instance } = {}
local checks = 0
local function check(value: boolean, message: string)
	assert(value, message)
	checks += 1
end

local ok, failure = pcall(function()
	local margin = 1 - GameConfig.Combat.Presentation.ScreenMarginFraction
	local epsilon = GameConfig.Combat.Feedback.ShotVisualMinStuds
	for id in WeaponDefs.byId do
		local def = WeaponDefs.get(id)
		check(def ~= nil, `Missing definition {id}`)
		local model = ViewModel.new(def)
		table.insert(models, model)
		check(model.muzzle.Parent ~= nil, `Missing muzzle for {id}`)
		check(#model.corners == 8, `Expected eight bound corners for {id}`)
		check(#model.frameCorners > 2, `Missing visible gun/grip framing points for {id}`)
		for _, fov in { 60, 75, 100 } do
			for _, aspect in { 4 / 3, 16 / 9, 21 / 9, 9 / 16 } do
				for _, pose in GameConfig.Combat.ViewModel.Poses do
					local r = pose.Rotation
					local desired = CFrame.new(pose.Position)
						* CFrame.Angles(math.rad(r.X), math.rad(r.Y), math.rad(r.Z))
					local fitted = Placement.fit(desired, model.frameCorners, fov, Vector2.new(1080 * aspect, 1080))
					local slopeY = math.tan(math.rad(fov / 2)) * margin
					for _, corner in model.frameCorners do
						local point = fitted:PointToWorldSpace(corner)
						local depth = -point.Z
						check(depth >= GameConfig.Combat.Presentation.NearDepthStuds - epsilon, "Near-plane clipping")
						check(math.abs(point.Y) <= depth * slopeY + epsilon, `Vertical clipping: {id}, FOV {fov}`)
						check(
							math.abs(point.X) <= depth * slopeY * aspect + epsilon,
							`Horizontal clipping: {id}, aspect {aspect}`
						)
					end
				end
			end
		end
	end
	-- Ticket 8.16: translating the camera must not drag a settled gun through world space. Use a separate
	-- camera far from the map so the real collision sampler is clear, without changing the player's camera.
	local fixtureCamera = Instance.new("Camera")
	table.insert(fixtures, fixtureCamera)
	fixtureCamera.CFrame = CFrame.new(10000, 10000, 10000)
	for _, model in models do
		model:update(fixtureCamera, 1, { pose = "Ready", speedFraction = 0 })
		local beforeFrame = fixtureCamera.CFrame:ToObjectSpace(model.drawFrame)
		fixtureCamera.CFrame += Vector3.new(20, 10, 5)
		model:update(fixtureCamera, 1 / 60, { pose = "Ready", speedFraction = 0 })
		local afterFrame = fixtureCamera.CFrame:ToObjectSpace(model.drawFrame)
		check((afterFrame.Position - beforeFrame.Position).Magnitude < epsilon, "Camera translation dragged the gun")
		check(model.drawScale <= GameConfig.Combat.Presentation.ViewDepthScale, "FPS model exceeded close-depth scale")
	end
	check(Placement.tuckFraction(GameConfig.Combat.Presentation.WallReachStuds) == 0, "Resting gun should not tuck")
	check(Placement.tuckFraction(GameConfig.Combat.Presentation.FullTuckStuds) == 1, "Full tuck threshold incorrect")
	check(
		Placement.attackBlocked(1.5, 0),
		"A reachable wall distance must block attacks, not only the old 0.65 stud threshold"
	)
	check(
		Placement.attackBlocked(GameConfig.Combat.Presentation.WallReachStuds, 0.5),
		"Visible tuck recovery must still block"
	)
	check(
		not Placement.attackBlocked(GameConfig.Combat.Presentation.WallReachStuds, 0),
		"A clear, recovered gun must allow attacks"
	)

	local camera = workspace.CurrentCamera
	assert(camera, "No camera")
	Visuals.start()
	local folder = workspace:FindFirstChild("CombatShotVisuals")
	assert(folder, "No visual pool")
	local parts = folder:GetChildren()
	local before: { number } = {}
	for index, part in parts do
		before[index] = (part :: BasePart).Transparency
	end
	local origin = camera.CFrame.Position + camera.CFrame.LookVector
	local hit = origin + camera.CFrame.LookVector * 50
	Visuals.fire(WeaponDefs.get("GuiseSMG"), origin, hit)
	for index, part in parts do
		check((part :: BasePart).Transparency == before[index], "Quiet SMG changed a visual pool slot")
	end
	Visuals.fire(WeaponDefs.get("ReticleCarbine"), origin, hit)
	local visible = 0
	for _, part in parts do
		if (part :: BasePart).Transparency < 1 then
			visible += 1
		end
	end
	check(visible >= 2, "Non-Quiet weapon did not create a tracer and flash")
	check(
		#folder:GetChildren() == GameConfig.Combat.Feedback.TracerPoolSize + GameConfig.Combat.Feedback.FlashPoolSize,
		"Pool grew"
	)

	-- Exercise the real collision sampler and the live HUD with a temporary client-only wall.
	local wall = Instance.new("Part")
	wall.Name = "ClientCombatTestWall"
	wall.Anchored = true
	wall.CanQuery, wall.CanCollide, wall.CanTouch = true, true, false
	wall.Size = Vector3.new(10, 10, 0.3)
	wall.CFrame = camera.CFrame * CFrame.new(0, 0, -1.5)
	wall.Parent = workspace
	table.insert(fixtures, wall)
	local RunService = game:GetService("RunService")
	RunService.RenderStepped:Wait()
	RunService.RenderStepped:Wait()
	check(Placement.attackBlocked(Placement.wallDistance(camera), 0), "Wall sampler did not block a nearby wall")
	local poses = GameConfig.Combat.ViewModel.Poses
	local function poseRotation(pose: any): CFrame
		local rotation = pose.Rotation
		return CFrame.Angles(math.rad(rotation.X), math.rad(rotation.Y), math.rad(rotation.Z))
	end
	for _, model in models do
		model:update(camera, 1, { pose = "Ready", speedFraction = 0 })
		check(model:isFireBlocked(camera), "Model bypassed the reachable-distance attack gate")
		local expected = poseRotation(poses.Ready):Lerp(poseRotation(poses.Tucked), model.tuck)
		local actual = camera.CFrame:ToObjectSpace(model.drawFrame).Rotation
		local _, difference = expected:ToObjectSpace(actual):ToAxisAngle()
		check(math.abs(difference) < 1e-4, "Visible wall tuck was filtered separately from the blocking fraction")
	end
	local WeaponController = require(client.Controllers.WeaponController)
	check(WeaponController.getStatus().attackBlocked, "Live attack gate disagrees with wall sampler")
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local hud = playerGui:FindFirstChild("CombatHud")
	assert(hud, "Combat HUD must be running")
	check((hud:FindFirstChild("ObstructionReticle") :: Frame).Visible, "Blocked graphic not visible")
	for _, side in { "Left", "Right", "Up", "Down" } do
		check(
			not (hud:FindFirstChild("Crosshair" .. side) :: Frame).Visible,
			"Crosshair still visible while obstructed"
		)
	end
	local disguiseHud = playerGui:FindFirstChild("DisguiseHud")
	assert(disguiseHud, "Disguise HUD must be running")
	check(not (disguiseHud:FindFirstChild("Dot") :: Frame).Visible, "Disguise dot still visible while obstructed")
	local cosmetic = camera:FindFirstChild("FirstPersonArms")
	assert(cosmetic, "Cosmetic first-person arms must be running")
	for _, item in cosmetic:GetDescendants() do
		check(not item:IsA("Motor6D") and not item:IsA("Humanoid"), "Cosmetic arms contain live avatar joints")
		if item:IsA("BasePart") then
			check(item.Anchored and not item.CanCollide and not item.CanQuery, "Cosmetic arm can affect gameplay")
		end
	end
	local avatar = Players.LocalPlayer.Character
	assert(avatar, "Local avatar must exist")
	for _, item in avatar:GetDescendants() do
		if item:IsA("BasePart") then
			check(item.LocalTransparencyModifier == 1, "Real avatar still visible in the owner's FPS view")
		end
	end
end)

for _, model in models do
	model:destroy()
end
for _, fixture in fixtures do
	fixture:Destroy()
end
assert(ok, tostring(failure))
print(`Client combat checks passed: {checks}. Body IK, wall rays, input and multiplayer still need a playtest.`)
