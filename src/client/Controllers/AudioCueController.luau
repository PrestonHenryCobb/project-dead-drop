--!strict
-- Ticket audio-defs (Step 20, spec 23): plays every non-weapon cue from Defs/AudioDefs. It reads only what the server already sends
-- (phase, alarm, vault, Package, extraction, cover and the Exposed ping) and what the camera can see, so it tells nobody anything new.
-- A cue with an empty id is skipped. Weapon, hitmarker and impact sounds are elsewhere (ShotFx, WeaponController).
--
-- Footsteps and the crowd murmur treat every body near the camera the same way (a model with a HumanoidRootPart, yours included):
-- the same stride, speed rule and sounds for an NPC and an agent, so a footstep can never tell which is which (CLAUDE.md rule 3).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)
local Enums = require(Shared.Enums)
local Types = require(Shared.Types)
local AudioDefs = require(Shared.Defs.AudioDefs)
local Janitor = require(Shared.Util.Janitor)
local SoundPlayer = require(script.Parent.Parent.Combat.SoundPlayer)
local RemoteController = require(script.Parent.RemoteController)
local SettingsController = require(script.Parent.SettingsController)

local AudioCueController = {}

local config = GameConfig.AudioCues
local janitor = Janitor.new()
local player = Players.LocalPlayer

type Walker = { last: Vector3, travelled: number }

local loops: { [string]: Sound } = {}
local walkers: { [Model]: Walker } = {}
local phase: Types.Phase? = nil
local mainEndsAt: number? = nil
local lockdown = false
local lastPackage: string? = nil
local lastExtraction: string? = nil
local hackedTerminals: { [string]: boolean } = {}
local wasExposed = false
local lastWorn: string? = nil
local currentTier = 0
local crowdTarget = 0

-- The player's world volume (Settings > Audio): every non-weapon cue, the footsteps and the ambience are scaled by it.
local function worldVolume(): number
	return SettingsController.get().WorldVolume
end

local function flat(name: string)
	local def = AudioDefs.Cues[name]
	if def and def.Id ~= "" then
		SoundPlayer.play(def.Id, def.Volume * worldVolume())
	end
end

local function at(name: string, position: Vector3, range: number)
	local def = AudioDefs.Cues[name]
	if def and def.Id ~= "" then
		SoundPlayer.playAt(def.Id, position, def.Volume * worldVolume(), range)
	end
end

-- A looping sound kept for the whole session and faded in or out by volume.
local function loop(key: string, def: AudioDefs.Cue): Sound?
	if def.Id == "" then
		return nil
	end
	local sound = loops[key]
	if not sound then
		local created = Instance.new("Sound")
		created.Name = "Cue" .. key
		created.Looped = true
		created.Volume = 0
		created.SoundId = def.Id
		created.Parent = SoundService
		janitor:Add(created)
		loops[key] = created
		created:Play()
		sound = created
	end
	return sound
end

local function fade(sound: Sound?, volume: number)
	if sound then
		TweenService:Create(sound, TweenInfo.new(config.AmbientFadeSeconds), { Volume = volume * worldVolume() }):Play()
	end
end

local function inMatch(): boolean
	return phase ~= nil and phase ~= "Lobby" and phase ~= "Results"
end

local function bodyRoot(child: Instance): (Model?, BasePart?)
	if child:IsA("Model") then
		local root = child:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			return child, root
		end
	end
	return nil, nil
end

-- Footsteps and crowd size from the bodies near the camera, one rule for all of them.
local function scanBodies(dt: number)
	local camera = workspace.CurrentCamera
	if not camera or not inMatch() then
		return
	end
	local origin = camera.CFrame.Position
	local seen: { [Model]: boolean } = {}
	local nearby = 0
	local reach = math.max(config.FootstepRadiusStuds, config.CrowdRadiusStuds)
	for _, child in workspace:GetChildren() do
		local body, root = bodyRoot(child)
		if body and root then
			local position = root.Position
			local distance = (position - origin).Magnitude
			if distance <= reach then
				seen[body] = true
				if distance <= config.CrowdRadiusStuds then
					nearby += 1
				end
				local walker = walkers[body]
				if not walker then
					walkers[body] = { last = position, travelled = 0 }
				else
					local moved = Vector3.new(position.X - walker.last.X, 0, position.Z - walker.last.Z).Magnitude
					walker.last = position
					local speed = moved / dt
					if speed > 0.5 and speed <= config.FootstepMaxSpeed and distance <= config.FootstepRadiusStuds then
						walker.travelled += moved
						if walker.travelled >= config.FootstepStrideStuds then
							walker.travelled -= config.FootstepStrideStuds
							at(
								if speed >= config.FootstepSprintSpeed then "FootstepSprint" else "FootstepWalk",
								position - Vector3.new(0, root.Size.Y / 2, 0),
								config.FootstepEmitterRange
							)
						end
					else
						walker.travelled = 0
					end
				end
			end
		end
	end
	for body in walkers do
		if not seen[body] then
			walkers[body] = nil
		end
	end
	crowdTarget = math.clamp(nearby / config.CrowdFullCount, 0, 1)
end

local function tierHere(): number
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return currentTier
	end
	local best = -1
	for _, volume in CollectionService:GetTagged(Enums.Tag.ZoneVolume) do
		local tier = volume:GetAttribute("Tier")
		if volume:IsA("BasePart") and type(tier) == "number" and tier > best then
			local offset = volume.CFrame:PointToObjectSpace(root.Position)
			local half = volume.Size / 2
			if math.abs(offset.X) <= half.X and math.abs(offset.Y) <= half.Y and math.abs(offset.Z) <= half.Z then
				best = tier
			end
		end
	end
	return if best >= 0 then best else currentTier
end

local function setAmbience()
	for tier, def in AudioDefs.Ambient do
		local sound = loop(`Ambient{tier}`, def)
		fade(sound, if inMatch() and tier == currentTier then def.Volume else 0)
	end
	fade(loop("Siren", AudioDefs.Siren), if lockdown and inMatch() then AudioDefs.Siren.Volume else 0)
	fade(loop("Crowd", AudioDefs.Crowd), if inMatch() then AudioDefs.Crowd.Volume * crowdTarget else 0)
end

function AudioCueController.Init() end

function AudioCueController.Start()
	local preload: { string } = {}
	for _, def in AudioDefs.Cues do
		table.insert(preload, def.Id)
	end
	SoundPlayer.preload(preload)

	janitor:Add(RemoteController.connect("PhaseChanged", function(value: Types.Phase, data: Types.PhaseData?)
		phase = value
		mainEndsAt = if data then data.MainEndsAt else nil
		if value == "VaultBreach" then
			flat("VaultUnlock")
		end
		if value == "Lobby" or value == "Insertion" then
			lastPackage, lastExtraction, wasExposed, lockdown = nil, nil, false, false
			table.clear(hackedTerminals)
		end
		setAmbience()
	end))
	janitor:Add(RemoteController.connect("ExposedPing", function(info: { Position: Vector3, Seconds: number })
		at("ExposedSting", info.Position, GameConfig.Cover.ExposedPingRadius)
	end))
	janitor:Add(RemoteController.connect("CoverStateChanged", function(info: Types.CoverInfo)
		local exposed = info.State == "Exposed"
		if exposed and not wasExposed then
			flat("ExposedSting")
		end
		wasExposed = exposed
	end))
	janitor:Add(RemoteController.connect("DisguiseUpdate", function(update: Types.DisguiseUpdate)
		if lastWorn and lastWorn ~= update.Worn then
			flat("DisguiseSwap")
		end
		lastWorn = update.Worn
	end))
	janitor:Add(RemoteController.connect("AlarmLevel", function(level: number)
		lockdown = level >= Enums.AlarmLevel.Lockdown
		setAmbience()
	end))
	janitor:Add(RemoteController.connect("VaultProgress", function(info: Types.VaultProgressInfo)
		for _, terminal in info.Terminals do
			if terminal.Hacked and not hackedTerminals[terminal.VaultId] then
				flat("VaultOpened")
			end
			hackedTerminals[terminal.VaultId] = terminal.Hacked
		end
	end))
	janitor:Add(RemoteController.connect("PackageState", function(info: Types.PackageStateInfo)
		if info.State == "Dropped" and lastPackage == "Carried" then
			flat("PackageDropped")
		elseif info.State == "Pedestal" and lastPackage == "Dropped" then
			flat("PackageReturned")
		end
		lastPackage = info.State
	end))
	janitor:Add(RemoteController.connect("ExtractionState", function(info: Types.ExtractionStateInfo)
		if info.State == "Countdown" and lastExtraction ~= "Countdown" then
			flat("ExtractionCalled")
		elseif info.State == "Hover" and lastExtraction ~= "Hover" then
			flat("HelicopterArrival")
		end
		lastExtraction = info.State
	end))

	local sinceBodies, sinceTier, sinceCrowd, sinceTick = 0, 0, 0, 0
	janitor:Add(RunService.Heartbeat:Connect(function(dt)
		sinceBodies += dt
		if sinceBodies >= config.FootstepCheckSeconds then
			scanBodies(sinceBodies)
			sinceBodies = 0
		end
		sinceTier += dt
		if sinceTier >= config.AmbientCheckSeconds then
			sinceTier = 0
			local tier = tierHere()
			if tier ~= currentTier then
				currentTier = tier
				setAmbience()
			end
		end
		sinceCrowd += dt
		if sinceCrowd >= config.CrowdCheckSeconds then
			sinceCrowd = 0
			setAmbience()
		end
		sinceTick += dt
		if sinceTick >= config.TickSeconds then
			sinceTick = 0
			local ends = mainEndsAt
			if inMatch() and ends then
				local left = ends - workspace:GetServerTimeNow()
				if left > 0 and left <= GameConfig.Audio.LastSecondsTicking then
					flat("LastMinuteTick")
				end
			end
		end
	end))
	janitor:Add(script.Destroying:Connect(function()
		janitor:Destroy()
	end))
end

return AudioCueController
