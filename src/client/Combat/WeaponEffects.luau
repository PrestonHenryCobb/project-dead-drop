--!strict
-- Cosmetic event renderer. All instances stay in a client-only folder, never on a character.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)
local Types = require(Shared.Types)
local WeaponDefs = require(Shared.Defs.WeaponDefs)
local Janitor = require(Shared.Util.Janitor)
local SoundPlayer = require(script.Parent.SoundPlayer)
local config = GameConfig.Combat.WeaponEffects

type Flight = {
	id: number?,
	kind: string,
	origin: Vector3,
	velocity: Vector3,
	gravity: number,
	started: number,
	expires: number,
	part: BasePart,
	last: Vector3,
	stopped: boolean,
}
type Timed = { part: BasePart, expires: number }
type Glow = { id: string, expires: number, highlight: Highlight }
local WeaponEffects = {}
local folder: Folder? = nil
local smokeVeil: Frame? = nil
local flights: { Flight } = {}
local lights: { Timed } = {}
local clouds: { Timed } = {}
local glows: { Glow } = {}
local params = RaycastParams.new()
params.CollisionGroup = GameConfig.Rig.CollisionGroup
params.RespectCanCollide = true

local function part(size: Vector3, color: Color3): Part
	local result = Instance.new("Part")
	result.Anchored = true
	result.CanCollide, result.CanTouch, result.CanQuery = false, false, false
	result.Size, result.Color = size, color
	result.Material = Enum.Material.Neon
	result.Parent = folder
	return result
end

local function removeFlight(index: number)
	flights[index].part:Destroy()
	table.remove(flights, index)
end

local function makeFlight(
	kind: string,
	origin: Vector3,
	velocity: Vector3,
	gravity: number,
	started: number,
	expires: number
): Flight
	if #flights >= config.MaxFlights then
		removeFlight(1)
	end
	local visual = if kind == "Knife"
		then part(GameConfig.Combat.Projectile.KnifeSize, config.KnifeColor)
		else part(config.FlareSize, config.FlareColor)
	if kind == "Knife" then
		visual.Material = Enum.Material.Metal
	end
	visual.CFrame = CFrame.lookAt(origin, origin + velocity)
	local flight: Flight = {
		id = nil,
		kind = kind,
		origin = origin,
		velocity = velocity,
		gravity = gravity,
		started = started,
		expires = expires,
		part = visual,
		last = origin,
		stopped = false,
	}
	table.insert(flights, flight)
	return flight
end

function WeaponEffects.predict(def: Types.WeaponDef, origin: Vector3, direction: Vector3)
	local projectile = def.Projectile
	if not projectile or not folder then
		return
	end
	local now = workspace:GetServerTimeNow()
	makeFlight(
		projectile.Kind,
		origin,
		direction * projectile.Speed,
		projectile.Gravity,
		now,
		now + config.PredictionSeconds
	)
end

function WeaponEffects.launched(info: Types.ProjectileLaunchInfo)
	local flight: Flight? = nil
	if info.Own then
		-- Own acknowledgements adopt the oldest outstanding prediction of this kind; remote events are ordered.
		for _, candidate in flights do
			if candidate.id == nil and candidate.kind == info.Kind then
				flight = candidate
				break
			end
		end
	end
	local lifetime = config.PredictionSeconds
	for _, def in WeaponDefs.byId do
		if def.Projectile and def.Projectile.Kind == info.Kind then
			lifetime = def.Projectile.MaxSeconds
			if not info.Own and def.HearStuds ~= 0 then
				SoundPlayer.playAt(
					def.Sounds.Fire,
					info.Origin,
					GameConfig.Combat.Feedback.ShotVolume,
					def.HearStuds or GameConfig.Audio.DefaultWeaponRadius
				)
			end
			break
		end
	end
	if not flight then
		flight =
			makeFlight(info.Kind, info.Origin, info.Velocity, info.Gravity, info.StartedAt, info.StartedAt + lifetime)
	end
	flight.id = info.Id
	flight.origin, flight.velocity, flight.gravity = info.Origin, info.Velocity, info.Gravity
	flight.started, flight.expires = info.StartedAt, info.StartedAt + lifetime
	flight.last, flight.stopped = info.Origin, false
end

function WeaponEffects.impact(info: Types.ProjectileImpactInfo)
	for index = #flights, 1, -1 do
		if flights[index].id == info.Id then
			removeFlight(index)
		end
	end
	if not info.LightUntil or info.LightUntil <= workspace:GetServerTimeNow() then
		return
	end
	if #lights >= config.MaxLights then
		lights[1].part:Destroy()
		table.remove(lights, 1)
	end
	local marker = part(Vector3.one * config.ImpactSize, config.FlareColor)
	marker.Position = info.Position
	local light = Instance.new("PointLight")
	light.Color, light.Brightness, light.Range = config.FlareColor, config.FlareBrightness, config.FlareRange
	light.Shadows = true
	light.Parent = marker
	table.insert(lights, { part = marker, expires = info.LightUntil })
end

function WeaponEffects.smoke(info: Types.SmokeCloudInfo)
	if info.ExpiresAt <= workspace:GetServerTimeNow() then
		return
	end
	if #clouds >= config.MaxClouds then
		clouds[1].part:Destroy()
		table.remove(clouds, 1)
	end
	local cloud = part(Vector3.one * (info.Radius * 2), config.SmokeColor)
	cloud.Shape = Enum.PartType.Ball
	cloud.Material = Enum.Material.SmoothPlastic
	cloud.Transparency = config.SmokeTransparency
	cloud.Position = info.Position
	table.insert(clouds, { part = cloud, expires = info.ExpiresAt })
end

local function resolve(id: string): Model?
	if string.sub(id, 1, 1) == "P" then
		local userId = tonumber(string.sub(id, 2))
		if userId then
			local player = Players:GetPlayerByUserId(userId)
			if player then
				return player.Character
			end
		end
	end
	local target = workspace:FindFirstChild(id)
	return if target and target:IsA("Model") then target else nil
end

function WeaponEffects.glow(info: Types.TargetGlowInfo)
	for _, entry in glows do
		if entry.id == info.TargetId then
			entry.expires = math.max(entry.expires, info.ExpiresAt)
			return
		end
	end
	if #glows >= config.MaxGlows then
		glows[1].highlight:Destroy()
		table.remove(glows, 1)
	end
	local highlight = Instance.new("Highlight")
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.FillColor, highlight.OutlineColor = config.FlareColor, config.FlareColor
	highlight.FillTransparency, highlight.OutlineTransparency =
		config.GlowFillTransparency, config.GlowOutlineTransparency
	highlight.Enabled = false
	highlight.Parent = folder
	table.insert(glows, { id = info.TargetId, expires = info.ExpiresAt, highlight = highlight })
end

function WeaponEffects.step()
	local now = workspace:GetServerTimeNow()
	local ignore: { Instance } = {}
	if folder then
		table.insert(ignore, folder)
	end
	if Players.LocalPlayer.Character then
		table.insert(ignore, Players.LocalPlayer.Character :: Model)
	end
	params.FilterDescendantsInstances = ignore
	for index = #flights, 1, -1 do
		local flight = flights[index]
		if now >= flight.expires then
			removeFlight(index)
		elseif not flight.stopped then
			local age = math.max(0, now - flight.started)
			local acceleration = Vector3.new(0, -flight.gravity, 0)
			local position = flight.origin + flight.velocity * age + acceleration * (age * age / 2)
			local hit = workspace:Raycast(flight.last, position - flight.last, params)
			if hit then
				position = hit.Position
				flight.stopped = true
			end
			local velocity = flight.velocity + acceleration * age
			flight.part.CFrame = CFrame.lookAt(position, position + velocity)
			flight.last = position
		end
	end
	for index = #lights, 1, -1 do
		if now >= lights[index].expires then
			lights[index].part:Destroy()
			table.remove(lights, index)
		end
	end
	for index = #clouds, 1, -1 do
		if now >= clouds[index].expires then
			clouds[index].part:Destroy()
			table.remove(clouds, index)
		end
	end
	local camera = workspace.CurrentCamera
	if smokeVeil then
		local inside = false
		if camera then
			for _, cloud in clouds do
				if (camera.CFrame.Position - cloud.part.Position).Magnitude < cloud.part.Size.X / 2 then
					inside = true
					break
				end
			end
		end
		smokeVeil.Visible = inside
	end
	for index = #glows, 1, -1 do
		local entry = glows[index]
		if now >= entry.expires then
			entry.highlight:Destroy()
			table.remove(glows, index)
		else
			local target = resolve(entry.id)
			local root = target and target:FindFirstChild("HumanoidRootPart")
			entry.highlight.Adornee = target
			entry.highlight.Enabled = false
			if camera and root and root:IsA("BasePart") then
				local hit = workspace:Raycast(camera.CFrame.Position, root.Position - camera.CFrame.Position, params)
				entry.highlight.Enabled = hit == nil or (target ~= nil and hit.Instance:IsDescendantOf(target))
			end
		end
	end
end

function WeaponEffects.start(janitor: Janitor.Janitor)
	if folder then
		return
	end
	local effects = Instance.new("Folder")
	effects.Name = "WeaponEffects"
	effects.Parent = workspace
	folder = effects
	janitor:Add(effects)
	-- Sphere backs are culled from inside: a local veil preserves obscuration while standing in a cloud.
	local gui = Instance.new("ScreenGui")
	gui.Name = "WeaponSmoke"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = config.SmokeDisplayOrder
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local veil = Instance.new("Frame")
	veil.Size = UDim2.fromScale(1, 1)
	veil.BackgroundColor3 = config.SmokeColor
	veil.BackgroundTransparency = config.SmokeVeilTransparency
	veil.BorderSizePixel = 0
	veil.Visible = false
	veil.Parent = gui
	smokeVeil = veil
	janitor:Add(gui)
	janitor:Add(function()
		table.clear(flights)
		table.clear(clouds)
		table.clear(lights)
		table.clear(glows)
		folder = nil
		smokeVeil = nil
	end)
end

return WeaponEffects
