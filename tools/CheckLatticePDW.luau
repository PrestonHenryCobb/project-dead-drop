--!strict
-- Ticket 8.5c-pdw: explicit non-world native geometry/registry/cadence check.
assert(game:GetService("RunService"):IsStudio(), "Studio only")
local shared = game.ReplicatedStorage.Shared:Clone()
shared.Name = "SharedOverride"
local combat = game.StarterPlayer.StarterPlayerScripts.Client.Combat:Clone()
shared.Parent = combat
combat.Parent = game.ServerStorage
local model: any = nil
local ok, problem = pcall(function()
	local defs = require(shared.Defs.WeaponDefs)
	local config = require(shared.GameConfig)
	local def = defs.get("LatticePDW")
	assert(def and def.Agent == "Lattice" and def.Automatic and not def.Quiet)
	assert(
		def.Damage == 7 and def.RPM == 950 and def.MagSize == 45 and def.ReserveAmmo == 90 and def.ReloadSeconds == 2
	)
	assert(def.Falloff.StartStuds == 25 and def.Falloff.EndStuds == 55 and def.Falloff.MinMult == 0.55)
	local visual = defs.Visuals[def.Id]
	assert(visual.AimBlendRate > config.Combat.Handling.AimBlendRate)
	assert(visual.PoseSpeed > config.Combat.ViewModel.PoseSpeed)
	assert(defs.Visuals.ReticleCarbine.PoseSpeed > visual.PoseSpeed, "Carbine's exceptional draw was lost")
	local choices = require(shared.Util.TestLoadout)
	local current = defs.get(config.Combat.DefaultWeapon)
	local visited = {}
	local count = 0
	for _ in defs.byId do
		assert(not visited[current.Id], "F8 wrapped before all registered weapons")
		visited[current.Id] = true
		count += 1
		current = choices.nextWeapon(current.Id, "All")
	end
	assert(current.Id == config.Combat.DefaultWeapon and visited.LatticePDW)
	local view = require(combat.ViewModel)
	local placement = require(combat.WeaponPlacement)
	model = view.new(def)
	model.model.Parent = game.ServerStorage
	local initial = #model.model:GetDescendants()
	local camera = workspace.CurrentCamera
	assert(camera)
	for index = 1, 100 do
		model:update(camera, 1 / 60, { pose = if index % 2 == 0 then "Ready" else "Aim", speedFraction = 0.5 })
		local right, left = model:getHandTargets()
		assert(right and left and model.muzzle.Parent)
	end
	assert(#model.model:GetDescendants() == initial, "Model update created instances")
	local margin = 1 - config.Combat.Presentation.ScreenMarginFraction
	local checks = 0
	for _, fov in { 60, 75, 100 } do
		for _, aspect in { 4 / 3, 16 / 9, 21 / 9, 9 / 16 } do
			for _, pose in config.Combat.ViewModel.Poses do
				local r = pose.Rotation
				local desired = CFrame.new(pose.Position) * CFrame.Angles(math.rad(r.X), math.rad(r.Y), math.rad(r.Z))
				local fitted = placement.fit(desired, model.frameCorners, fov, Vector2.new(1080 * aspect, 1080))
				local slope = math.tan(math.rad(fov / 2)) * margin
				for _, corner in model.frameCorners do
					local point = fitted:PointToWorldSpace(corner)
					assert(-point.Z >= config.Combat.Presentation.NearDepthStuds - 0.001)
					assert(math.abs(point.Y) <= -point.Z * slope + 0.001)
					assert(math.abs(point.X) <= -point.Z * slope * aspect + 0.001)
					checks += 3
				end
			end
		end
	end
	local cadence = require(combat.WeaponCadence)
	local server = require(game.ServerScriptService.Server.Combat.FireRate)
	assert(math.abs(cadence.gapAfterShot(def, cadence.newStreak(), 0, false) - 60 / 950) < 0.00001)
	assert(math.abs(server.gapAfterShot(def, server.newStreak(), 0, false) - 60 / 950) < 0.00001)
	print(
		"LATTICE_PDW_NATIVE_PASS",
		count,
		"F8 choices;",
		checks,
		"frustum checks; handling, grips, stable instances and cadence"
	)
end)
if model then
	model:destroy()
end
combat:Destroy()
assert(ok, tostring(problem))
