--!strict
-- Ticket R8-pistol-pose: paste into Studio's Edit command bar. No camera/world mutation or firing.
assert(game:GetService("RunService"):IsStudio(), "Studio only")
local shared = game.ReplicatedStorage.Shared:Clone()
shared.Name = "SharedOverride"
local combat = game.StarterPlayer.StarterPlayerScripts.Client.Combat:Clone()
shared.Parent = combat
combat.Name = "DualPistolReviewModules"
combat.Parent = game.ServerStorage
local model: any = nil
local ok, problem = pcall(function()
	local defs = require(shared.Defs.WeaponDefs)
	local config = require(shared.GameConfig)
	local view = require(combat.ViewModel)
	local placement = require(combat.WeaponPlacement)
	local visual = defs.Visuals.SutureDualPistols
	model = view.new(defs.get("SutureDualPistols"))
	model.model.Parent = game.ServerStorage
	local camera = workspace.CurrentCamera
	assert(camera)
	model:update(camera, 0, { pose = "Ready", speedFraction = 0 })
	local right = camera.CFrame:PointToObjectSpace(model.muzzle.WorldPosition)
	local left = camera.CFrame:PointToObjectSpace(model.leftMuzzle.WorldPosition)
	assert(right.X > 0 and left.X < 0, "Both ready pistols are on one side")
	assert(math.abs(right.X + left.X) < 0.001, "Ready muzzles are not symmetric")
	local readyRight, readyLeft = model:getHandTargets()
	assert(readyRight and readyLeft, "Ready pair lost a hand target")
	assert(camera.CFrame:PointToObjectSpace(readyRight.Position).X > 0)
	assert(camera.CFrame:PointToObjectSpace(readyLeft.Position).X < 0)
	model.current = CFrame.identity
	model:update(camera, 0, { pose = "Tucked", speedFraction = 0 })
	local tuckedDirection = camera.CFrame:VectorToObjectSpace(model.drawFrame.LookVector)
	assert(tuckedDirection.Y < -0.7, "Dual carry did not lower both barrels")
	right = camera.CFrame:PointToObjectSpace(model.muzzle.WorldPosition)
	left = camera.CFrame:PointToObjectSpace(model.leftMuzzle.WorldPosition)
	assert(right.X > 0 and left.X < 0, "Dual carry stacked the pair")
	model.current = CFrame.identity
	model:update(camera, 0, { pose = "Aim", speedFraction = 0 })
	assert(model.singleAkimbo, "Single aimed-pistol behavior changed")
	local _, aimedLeft = model:getHandTargets()
	assert(aimedLeft == nil, "Aimed mode retained the hidden left-hand target")
	for _, part in model.parts do
		if part.left then
			assert(part.part.Transparency == 1, "Aimed left gun was visible")
		end
	end
	local checks = 0
	for _, fov in { 60, 75, 100 } do
		for _, aspect in { 4 / 3, 16 / 9, 21 / 9, 9 / 16 } do
			for name, base in config.Combat.ViewModel.Poses do
				local pose = visual.Poses[name] or base
				local r = pose.Rotation
				local desired = CFrame.new(pose.Position) * CFrame.Angles(math.rad(r.X), math.rad(r.Y), math.rad(r.Z))
				local fitted = placement.fit(desired, model.frameCorners, fov, Vector2.new(1080 * aspect, 1080))
				local slope = math.tan(math.rad(fov / 2)) * (1 - config.Combat.Presentation.ScreenMarginFraction)
				for _, corner in model.frameCorners do
					local point = fitted:PointToWorldSpace(corner)
					assert(-point.Z >= config.Combat.Presentation.NearDepthStuds - 0.001)
					assert(math.abs(point.Y) <= -point.Z * slope + 0.001, "Dual vertical clipping")
					assert(math.abs(point.X) <= -point.Z * slope * aspect + 0.001, "Dual horizontal clipping")
					checks += 3
				end
			end
		end
	end
	print(
		"DUAL_PISTOL_NATIVE_PASS",
		checks,
		"frustum checks; symmetric ready, separate tuck, single aimed gun and hand targets"
	)
end)
if model then
	model:destroy()
end
combat:Destroy()
assert(ok, tostring(problem))
