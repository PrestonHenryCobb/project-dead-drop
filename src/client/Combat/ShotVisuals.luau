--!strict
-- Ticket 8.11: reusable client-only tracer and muzzle-flash parts. No instances, tables or tasks per shot/frame.
-- start() allocates pools before input is bound; fire() only fills existing slots. Quiet always suppresses both.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Types = require(Shared:WaitForChild("Types"))
local WeaponDefs = require(Shared:WaitForChild("Defs"):WaitForChild("WeaponDefs"))
local Janitor = require(Shared:WaitForChild("Util"):WaitForChild("Janitor"))

type Tracer = {
	part: Part,
	origin: Vector3,
	direction: Vector3,
	distance: number,
	travel: number,
	length: number,
	speed: number,
	width: number,
	active: boolean,
	fresh: boolean,
}
type Flash = { part: Part, remaining: number, fresh: boolean }

local ShotVisuals = {}
local feedback = GameConfig.Combat.Feedback
local defaults = WeaponDefs.ShotDefaults
local tracers: { Tracer } = {}
local flashes: { Flash } = {}
local tracerIndex, flashIndex = 0, 0
local janitor = Janitor.new()
local started = false

-- Pick an up axis that cannot be parallel to the shot, including straight up/down shots.
local function shotFrame(origin: Vector3, direction: Vector3): CFrame
	local up = if math.abs(direction.Y) < 1 then Vector3.yAxis else Vector3.zAxis
	return CFrame.lookAt(origin, origin + direction, up)
end

local function makePart(folder: Folder, name: string): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Transparency = 1
	part.Parent = folder
	return part
end

local function clear()
	for _, slot in tracers do
		slot.active = false
		slot.part.Transparency = 1
	end
	for _, slot in flashes do
		slot.remaining = 0
		slot.part.Transparency = 1
	end
end

local function drawTracer(slot: Tracer)
	local head = math.min(slot.travel, slot.distance)
	local tail = math.max(0, slot.travel - slot.length)
	local length = head - tail
	if length <= feedback.ShotVisualMinStuds then
		slot.active = false
		slot.part.Transparency = 1
		return
	end
	slot.part.Size = Vector3.new(slot.width, slot.width, length)
	slot.part.CFrame = shotFrame(slot.origin + slot.direction * ((head + tail) / 2), slot.direction)
	slot.part.Transparency = 0
end

local function update(dt: number)
	for _, slot in tracers do
		if slot.active then
			-- Keep the muzzle segment for at least one render, even when a near hit's flight is shorter than dt.
			if slot.fresh then
				slot.fresh = false
			else
				slot.travel += slot.speed * dt
				drawTracer(slot)
			end
		end
	end
	for _, slot in flashes do
		if slot.remaining > 0 then
			if slot.fresh then
				slot.fresh = false
			else
				slot.remaining = math.max(0, slot.remaining - dt)
				slot.part.Transparency = 1 - slot.remaining / feedback.FlashSeconds
			end
		end
	end
end

function ShotVisuals.start()
	if started then
		return
	end
	started = true
	local folder = Instance.new("Folder")
	folder.Name = "CombatShotVisuals"
	folder.Parent = workspace -- created by this client, never on a character or replicated to another client
	janitor:Add(folder)
	for _ = 1, feedback.TracerPoolSize do
		table.insert(tracers, {
			part = makePart(folder, "Tracer"),
			origin = Vector3.zero,
			direction = Vector3.zAxis,
			distance = 0,
			travel = 0,
			length = 0,
			speed = 0,
			width = 0,
			active = false,
			fresh = false,
		})
	end
	for _ = 1, feedback.FlashPoolSize do
		table.insert(flashes, { part = makePart(folder, "MuzzleFlash"), remaining = 0, fresh = false })
	end
	janitor:Add(RunService.RenderStepped:Connect(update))
	janitor:Add(Players.LocalPlayer.CharacterRemoving:Connect(clear))
	janitor:Add(script.Destroying:Connect(function()
		janitor:Destroy()
		table.clear(tracers)
		table.clear(flashes)
	end))
end

function ShotVisuals.remoteMuzzle(origin: Vector3, hit: Vector3): Vector3
	local delta = hit - origin
	if delta.Magnitude <= feedback.ShotVisualMinStuds then
		return origin
	end
	return shotFrame(origin, delta.Unit):PointToWorldSpace(feedback.RemoteMuzzleOffset)
end

function ShotVisuals.fire(def: Types.WeaponDef, muzzle: Vector3, hit: Vector3)
	if def.Quiet or not started then
		return
	end
	local delta = hit - muzzle
	local distance = delta.Magnitude
	if distance <= feedback.ShotVisualMinStuds then
		return
	end
	local direction = delta / distance
	tracerIndex = tracerIndex % #tracers + 1
	local tracer = tracers[tracerIndex]
	tracer.origin = muzzle
	tracer.direction = direction
	tracer.distance = distance
	tracer.length = math.max(feedback.ShotVisualMinStuds, def.TracerLength or defaults.TracerLength)
	tracer.travel = math.min(tracer.length, distance)
	tracer.speed = math.max(feedback.ShotVisualMinStuds, def.TracerSpeed or defaults.TracerSpeed)
	tracer.width = math.max(feedback.ShotVisualMinStuds, def.TracerWidth or defaults.TracerWidth)
	tracer.part.Color = def.TracerColor or defaults.TracerColor
	tracer.active = true
	tracer.fresh = true
	drawTracer(tracer)

	flashIndex = flashIndex % #flashes + 1
	local flash = flashes[flashIndex]
	flash.remaining = feedback.FlashSeconds
	flash.fresh = true
	flash.part.Size = def.FlashSize or defaults.FlashSize
	flash.part.Color = def.FlashColor or defaults.FlashColor
	flash.part.CFrame = shotFrame(muzzle, direction) * CFrame.new(0, 0, -flash.part.Size.Z / 2)
	flash.part.Transparency = 0
end

return ShotVisuals
