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
local checks = 0
local function check(value: boolean, message: string)
	assert(value, message)
	checks += 1
end

local ok, failure = pcall(function()
	local margin = 1 - GameConfig.Combat.Presentation.ScreenMarginFraction
	local epsilon = GameConfig.Combat.Feedback.ShotVisualMinStuds
	for _, id in { "GuiseSMG", "ReticleCarbine" } do
		local def = WeaponDefs.get(id)
		check(def ~= nil, `Missing definition {id}`)
		local model = ViewModel.new(def)
		table.insert(models, model)
		check(model.muzzle.Parent ~= nil, `Missing muzzle for {id}`)
		check(#model.corners == 8, `Expected eight bound corners for {id}`)
		for _, fov in { 60, 75, 100 } do
			for _, aspect in { 4 / 3, 16 / 9, 21 / 9, 9 / 16 } do
				for _, pose in GameConfig.Combat.ViewModel.Poses do
					local r = pose.Rotation
					local desired = CFrame.new(pose.Position)
						* CFrame.Angles(math.rad(r.X), math.rad(r.Y), math.rad(r.Z))
					local fitted = Placement.fit(desired, model.corners, fov, Vector2.new(1080 * aspect, 1080))
					local slopeY = math.tan(math.rad(fov / 2)) * margin
					for _, corner in model.corners do
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
	check(Placement.tuckFraction(GameConfig.Combat.Presentation.WallReachStuds) == 0, "Resting gun should not tuck")
	check(Placement.tuckFraction(GameConfig.Combat.Presentation.FullTuckStuds) == 1, "Full tuck threshold incorrect")

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
end)

for _, model in models do
	model:destroy()
end
assert(ok, tostring(failure))
print(`Client combat checks passed: {checks}. Body IK, wall rays, input and multiplayer still need a playtest.`)
