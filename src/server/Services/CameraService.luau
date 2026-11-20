--!strict
-- Ticket 14: security cameras and the Camera Room (spec 18.1).
--
--   * Each camera (tag SecurityCamera) sweeps SweepDegrees back and forth over SweepSeconds, looking down its cone
--     (ConeDegrees, Range). It is a witness for Cover while it works (CoverService.addWitnessSource, worth 0.6).
--   * It locks on to an agent in its cone who is Exposed in a Tier 1+ zone, or trespassing (zone above their clearance):
--     it stops sweeping and turns red, and LockOnSeconds of continuous view raises the alarm once. It sweeps on again
--     once it has lost the target for LockLoseSeconds. The nearest AlertGuards guards go to where the agent was (GuardService).
--   * Hold Interact within HackRange for HackSeconds (kind "Camera"): disabled for HackDisabledSeconds, and it cannot be
--     hacked again for HackImmuneSeconds after it comes back. Suspicious if another camera sees it (noteHacking).
--   * A shot that ends on a camera destroys it for DestroyedSeconds (CombatService world-hit listener).
--   * The Camera Room terminal (made at match start on a clear spot of the room): hold Interact CameraRoom.HoldSeconds to
--     disable every working camera for DisableAllSeconds, once per CooldownSeconds. It breaks Cover.
--   * In Lockdown cameras sweep faster (AlarmService.sweepMult).
--
-- Clients animate the sweep themselves from attributes on the camera part (CameraController): CameraState, SweepPhase
-- (0 to 1, sine of it is the angle), SweepSince (server time of that phase), SweepRate (cycles a second, 0 when still) and
-- HackableAt (server time). The server never moves the part.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Smoke = require(script.Parent.Parent.Combat.Smoke)
local Placement = require(script.Parent.Parent.Security.Placement)
local AlarmService = require(script.Parent.AlarmService)
local CombatService = require(script.Parent.CombatService)
local CoverService = require(script.Parent.CoverService)
local DisguiseService = require(script.Parent.DisguiseService)
local DownedService = require(script.Parent.DownedService)
local DroneService = require(script.Parent.DroneService)
local GuardService = require(script.Parent.GuardService)
local InteractService = require(script.Parent.InteractService)
local MatchService = require(script.Parent.MatchService)
local ReachService = require(script.Parent.ReachService)
local ZoneService = require(script.Parent.ZoneService)

type CameraState = "Sweep" | "Locked" | "Disabled" | "Destroyed"

type Camera = {
	id: string,
	part: BasePart,
	baseLook: Vector3, -- unit vector the part faces when the sweep is centred
	phase: number, -- sweep phase at phaseAt
	phaseAt: number, -- os.clock()
	rate: number, -- cycles a second
	state: CameraState,
	untilAt: number, -- os.clock(): when Disabled or Destroyed ends
	hackableAt: number, -- os.clock(): not before
	target: Player?,
	lockStart: number,
	lostSince: number,
	raised: boolean,
}

local CameraService = {}

local config = GameConfig.Security.Camera
local roomConfig = GameConfig.Security.CameraRoom
local cameras: { Camera } = {}
local byId: { [string]: Camera } = {}
local witnesses: { CoverService.Witness } = {}
local terminal: BasePart? = nil
local terminalReadyAt = 0

local sightParams = RaycastParams.new()
sightParams.CollisionGroup = GameConfig.Rig.CollisionGroup
sightParams.RespectCanCollide = true

local function phaseNow(camera: Camera, now: number): number
	return (camera.phase + camera.rate * (now - camera.phaseAt)) % 1
end

local function lookOf(camera: Camera, now: number): Vector3
	local yaw = math.rad(config.SweepDegrees / 2) * math.sin(2 * math.pi * phaseNow(camera, now))
	return CFrame.Angles(0, yaw, 0):VectorToWorldSpace(camera.baseLook)
end

local function working(camera: Camera): boolean
	return camera.state == "Sweep" or camera.state == "Locked"
end

-- Tells clients (attributes on the camera part only) and fixes the phase from here on.
local function setMotion(camera: Camera, state: CameraState, now: number)
	camera.phase = phaseNow(camera, now)
	camera.phaseAt = now
	camera.state = state
	camera.rate = if state == "Sweep" then AlarmService.sweepMult() / config.SweepSeconds else 0
	local part = camera.part
	part:SetAttribute("CameraState", state)
	part:SetAttribute("SweepPhase", camera.phase)
	part:SetAttribute("SweepSince", workspace:GetServerTimeNow())
	part:SetAttribute("SweepRate", camera.rate)
	part:SetAttribute("HackableAt", workspace:GetServerTimeNow() + math.max(camera.hackableAt - now, 0))
end

local function unlock(camera: Camera)
	camera.target = nil
	camera.raised = false
	camera.lostSince = 0
end

local function disable(camera: Camera, seconds: number, hackImmuneSeconds: number, now: number)
	unlock(camera)
	camera.untilAt = now + seconds
	camera.hackableAt = camera.untilAt + hackImmuneSeconds
	setMotion(camera, "Disabled", now)
end

local function playerBody(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") and not DownedService.isOut(player) then
		return root
	end
	return nil
end

local function inCone(camera: Camera, look: Vector3, point: Vector3): boolean
	local offset = point - camera.part.Position
	local distance = offset.Magnitude
	if distance > config.Range or distance < 1e-3 then
		return false
	end
	if math.acos(math.clamp(look:Dot(offset / distance), -1, 1)) > math.rad(config.ConeDegrees / 2) then
		return false
	end
	return workspace:Raycast(camera.part.Position, offset, sightParams) == nil
		and not Smoke.blocks(camera.part.Position, point)
end

-- A camera locks on to an Exposed agent in Tier 1 or higher, or to anyone in a zone above their clearance.
local function wanted(player: Player, position: Vector3): boolean
	local tier = ZoneService.tierAt(position)
	return (CoverService.isExposed(player) and tier >= 1) or tier > DisguiseService.getClearance(player)
end

local function think(camera: Camera, bodies: { [Player]: BasePart }, now: number)
	if camera.state == "Disabled" or camera.state == "Destroyed" then
		if now >= camera.untilAt then
			setMotion(camera, "Sweep", now)
		end
		return
	end
	local look = lookOf(camera, now)
	local seen: Player? = nil
	local previous = camera.target
	for player, root in bodies do
		if wanted(player, root.Position) and inCone(camera, look, root.Position) then
			if player == previous or not seen then
				seen = player
			end
		end
	end
	if camera.state == "Sweep" then
		if seen then
			camera.target, camera.lockStart, camera.lostSince, camera.raised = seen, now, 0, false
			setMotion(camera, "Locked", now)
		end
		return
	end
	if seen then
		if seen ~= previous then
			camera.target, camera.lockStart, camera.raised = seen, now, false
		end
		camera.lostSince = 0
		if not camera.raised and now - camera.lockStart >= config.LockOnSeconds then
			camera.raised = true
			AlarmService.raise(1, `Camera {camera.id} saw {seen.Name}`)
			local root = bodies[seen]
			if root then
				GuardService.alertNearest(root.Position, config.AlertGuards) -- spec 18.1
			end
		end
	else
		if camera.lostSince == 0 then
			camera.lostSince = now
		elseif now - camera.lostSince >= config.LockLoseSeconds then
			unlock(camera)
			setMotion(camera, "Sweep", now)
		end
	end
end

local function tick()
	local now = os.clock()
	if not MatchService.isInMatch() then
		return
	end
	local bodies: { [Player]: BasePart } = {}
	for _, player in Players:GetPlayers() do
		local root = playerBody(player)
		if root then
			bodies[player] = root
		end
	end
	table.clear(witnesses)
	for _, camera in cameras do
		think(camera, bodies, now)
		if working(camera) then
			table.insert(witnesses, {
				position = camera.part.Position,
				look = lookOf(camera, now),
				kind = "Camera",
				range = config.Range,
				fov = config.ConeDegrees,
			})
		end
	end
end

local function reset()
	local now = os.clock()
	for _, camera in cameras do
		unlock(camera)
		camera.hackableAt = 0
		setMotion(camera, "Sweep", now)
	end
	terminalReadyAt = 0
	table.clear(witnesses)
end

local function beginHack(player: Player, targetName: string): InteractService.Interaction?
	local camera = byId[targetName]
	local root = playerBody(player)
	if
		not (camera and root)
		or not MatchService.isInMatch()
		or not working(camera)
		or os.clock() < camera.hackableAt
	then
		return nil
	end
	-- Ticket 16c: Lattice's drone hacks from where it hovers.
	local flying = DroneService.position(player) ~= nil
	local function distance(): number
		local origin = ReachService.origin(player) or root.Position
		local offset = camera.part.Position - origin
		return Vector3.new(offset.X, 0, offset.Z).Magnitude -- the camera is high on a wall: reach is on the floor plan
	end
	if distance() > config.HackRange then
		return nil
	end
	if not flying then
		CoverService.noteHacking(player)
	end
	return {
		label = "Hack camera",
		seconds = config.HackSeconds,
		stillValid = function()
			if not flying then
				CoverService.noteHacking(player)
			end
			return playerBody(player) ~= nil and working(camera) and distance() <= config.InteractStuds
		end,
		complete = function()
			if working(camera) then
				disable(camera, config.HackDisabledSeconds, config.HackImmuneSeconds, os.clock())
			end
		end,
	}
end

local function beginTerminal(player: Player, targetName: string): InteractService.Interaction?
	local screen = terminal
	local root = playerBody(player)
	if not (screen and root) or targetName ~= screen:GetAttribute("SecurityId") or not MatchService.isInMatch() then
		return nil
	end
	if os.clock() < terminalReadyAt or (screen.Position - root.Position).Magnitude > roomConfig.InteractStuds then
		return nil
	end
	CoverService.noteHacking(player)
	return {
		label = "Camera Room",
		seconds = roomConfig.HoldSeconds,
		stillValid = function()
			CoverService.noteHacking(player)
			local body = playerBody(player)
			return body ~= nil and (screen.Position - body.Position).Magnitude <= roomConfig.InteractStuds
		end,
		complete = function()
			local now = os.clock()
			if now < terminalReadyAt then
				return
			end
			terminalReadyAt = now + roomConfig.CooldownSeconds
			screen:SetAttribute("ReadyAt", workspace:GetServerTimeNow() + roomConfig.CooldownSeconds)
			for _, camera in cameras do
				if working(camera) then
					disable(camera, roomConfig.DisableAllSeconds, 0, now)
				end
			end
			CoverService.expose(player, "CameraRoom") -- spec 18.1: it breaks Cover
		end,
	}
end

-- The terminal sits on a clear spot of the Camera Room's floor.
local function makeTerminal()
	local volume: BasePart? = nil
	for _, instance in CollectionService:GetTagged(Enums.Tag.ZoneVolume) do
		if instance:IsA("BasePart") and string.find(instance.Name, roomConfig.RoomId, 1, true) then
			volume = instance
			break
		end
	end
	if not volume then
		warn(`[CameraService] No zone volume for room {roomConfig.RoomId}: no Camera Room terminal`)
		return
	end
	local size = roomConfig.TerminalSize
	local origin = volume.Position - Vector3.new(0, volume.Size.Y / 2 - 3, 0)
	local reach = math.min(volume.Size.X, volume.Size.Z) / 2 - size.X
	local spot = Placement.clearSpot(origin, size, 0, reach)
	if not spot then
		warn("[CameraService] No clear floor in the Camera Room for the terminal")
		return
	end
	local part = Instance.new("Part")
	part.Name = "CameraTerminal"
	part.Anchored = true
	part.Size = size
	part.Position = spot
	part.Color = Color3.fromRGB(40, 60, 80)
	part.Material = Enum.Material.Metal
	part:SetAttribute("SecurityId", "T1")
	part:SetAttribute("ReadyAt", 0)
	CollectionService:AddTag(part, Enums.Tag.CameraTerminal)
	local folder = workspace:FindFirstChild("SecurityObjects") or Instance.new("Folder")
	folder.Name = "SecurityObjects"
	folder.Parent = workspace
	part.Parent = folder
	terminal = part
end

-- Ticket 17c (Jammer): every working camera within `radius` (on the floor plan) of `position` goes dark for `seconds` from now; asked again before
-- that, it stays dark. No hack immunity follows, so a jammer that is taken out lets its cameras back within `seconds`.
function CameraService.jamAt(position: Vector3, radius: number, seconds: number)
	local now = os.clock()
	for _, camera in cameras do
		-- A camera is high on a wall, so the radius is measured on the floor plan, as a hack's reach is.
		local offset = camera.part.Position - position
		if Vector3.new(offset.X, 0, offset.Z).Magnitude <= radius then
			if working(camera) then
				disable(camera, seconds, 0, now)
			elseif camera.state == "Disabled" then
				camera.untilAt = math.max(camera.untilAt, now + seconds)
			end
		end
	end
end

function CameraService.Init() end

function CameraService.Start()
	local now = os.clock()
	for _, instance in CollectionService:GetTagged(Enums.Tag.SecurityCamera) do
		if instance:IsA("BasePart") then
			local flat = instance.CFrame.LookVector
			local camera: Camera = {
				id = `C{#cameras + 1}`,
				part = instance,
				baseLook = flat,
				phase = math.random(),
				phaseAt = now,
				rate = 0,
				state = "Sweep",
				untilAt = 0,
				hackableAt = 0,
				target = nil,
				lockStart = 0,
				lostSince = 0,
				raised = false,
			}
			table.insert(cameras, camera)
			byId[camera.id] = camera
			instance:SetAttribute("SecurityId", camera.id)
			setMotion(camera, "Sweep", now)
		end
	end
	makeTerminal()

	CoverService.addWitnessSource(function()
		return witnesses
	end)
	CombatService.setWorldHitListener(function(point: Vector3, _: Player)
		local hitAt = os.clock()
		for _, camera in cameras do
			if camera.state ~= "Destroyed" and (point - camera.part.Position).Magnitude <= config.HitRadiusStuds then
				unlock(camera)
				camera.untilAt = hitAt + config.DestroyedSeconds
				setMotion(camera, "Destroyed", hitAt)
			end
		end
	end)
	InteractService.register("Camera", beginHack)
	InteractService.register("CameraTerminal", beginTerminal)
	MatchService.onPhaseChanged(function(phase)
		if phase == "Lobby" or phase == "Insertion" then
			reset()
		end
	end)
	AlarmService.onChange(function()
		local at = os.clock()
		for _, camera in cameras do
			if camera.state == "Sweep" then
				setMotion(camera, "Sweep", at) -- picks up the new sweep speed
			end
		end
	end)

	local interval = 1 / config.CheckHz
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= interval then
			elapsed = 0
			tick()
		end
	end)
end

return CameraService
