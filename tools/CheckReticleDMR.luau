--!strict
-- Ticket 8.5d-dmr: isolated Edit-mode native geometry/cadence assertions; no Play restart, camera mutation or shots.
assert(game:GetService("RunService"):IsStudio(), "Studio only")
local shared = game.ReplicatedStorage.Shared:Clone()
shared.Name = "SharedOverride"
local combat = game.StarterPlayer.StarterPlayerScripts.Client.Combat:Clone()
shared.Parent = combat
combat.Name = "DmrReviewModules"
combat.Parent = game.ServerStorage
local model: any = nil
local ok, problem = pcall(function()
	local defs = require(shared.Defs.WeaponDefs)
	local config = require(shared.GameConfig)
	local aim = require(combat.WeaponAim)
	local placement = require(combat.WeaponPlacement)
	local view = require(combat.ViewModel)
	local def = defs.get("ReticleDMR")
	assert(def and def.Damage == 68 and def.RPM == 45 and def.MagSize == 5 and def.ReserveAmmo == 10)
	assert(def.ScopeGlint and not def.Quiet and def.Falloff == nil and def.HeadshotMult == 2)
	local visual = defs.Visuals[def.Id]
	assert(visual.Magnification == 3)
	model = view.new(def)
	model.model.Parent = game.ServerStorage -- never enters the world/camera for a rendered frame
	assert(model.muzzle and model.model:FindFirstChild("ScopeDial") and model.model:FindFirstChild("BoltHandle"))
	local checks = 0
	local margin = 1 - config.Combat.Presentation.ScreenMarginFraction
	for _, baseFov in { 70, 85, 100 } do
		for _, fov in { baseFov, aim.fov(baseFov, def.AimZoom, visual.Magnification) } do
			for _, aspect in { 4 / 3, 16 / 9, 21 / 9, 9 / 16 } do
				for _, pose in config.Combat.ViewModel.Poses do
					local r = pose.Rotation
					local desired = CFrame.new(pose.Position)
						* CFrame.Angles(math.rad(r.X), math.rad(r.Y), math.rad(r.Z))
					local fitted = placement.fit(desired, model.frameCorners, fov, Vector2.new(1080 * aspect, 1080))
					local slope = math.tan(math.rad(fov / 2)) * margin
					for _, corner in model.frameCorners do
						local point = fitted:PointToWorldSpace(corner)
						assert(-point.Z >= config.Combat.Presentation.NearDepthStuds - 0.001, "DMR near clipping")
						assert(math.abs(point.Y) <= -point.Z * slope + 0.001, "DMR vertical clipping")
						assert(math.abs(point.X) <= -point.Z * slope * aspect + 0.001, "DMR horizontal clipping")
						checks += 3
					end
				end
			end
		end
	end
	local camera = workspace.CurrentCamera
	assert(camera)
	local handle = model.model:FindFirstChild("BoltHandle") :: BasePart
	local rest = handle:GetAttribute("Offset") :: CFrame
	model.boltAt = os.clock() - visual.BoltCycleSeconds / 2
	model:update(camera, 0, { pose = "Aim", speedFraction = 0 })
	local drawn = model.drawFrame:PointToObjectSpace(handle.Position) / model.drawScale
	assert(drawn.Z > rest.Position.Z + visual.BoltTravelStuds * 0.9, "Bolt did not cycle")
	model.boltAt = -math.huge
	model:update(camera, 0, { pose = "Aim", speedFraction = 0 })
	drawn = model.drawFrame:PointToObjectSpace(handle.Position) / model.drawScale
	assert(math.abs(drawn.Z - rest.Position.Z) < 0.001, "Bolt did not return")
	local cadence = require(combat.WeaponCadence)
	local serverCadence = require(game.ServerScriptService.Server.Combat.FireRate)
	assert(math.abs(cadence.gapAfterShot(def, cadence.newStreak(), 0, false) - 60 / 45) < 0.001)
	assert(math.abs(serverCadence.gapAfterShot(def, serverCadence.newStreak(), 0, false) - 60 / 45) < 0.001)
	print("RETICLE_DMR_NATIVE_PASS", checks, "frustum checks; bolt cycle, exact scope and matching cadence")
end)
if model then
	model:destroy()
end
combat:Destroy()
assert(ok, tostring(problem))
