--!strict
-- Plays short sounds from a fixed set of reusable Sound objects, so a fast weapon never creates and destroys a Sound per
-- shot. Client only.
--
--   SoundPlayer.preload(ids)                          load sounds before they are needed
--   SoundPlayer.play(id, volume, pitch?)              a sound heard the same everywhere (your own gun, a hitmarker)
--   SoundPlayer.playAt(id, position, volume, range)   a sound in the world, fading to nothing at `range` studs
--   SoundPlayer.setVolume(multiplier)              local combat-effects mix, including currently playing voices

local ContentProvider = game:GetService("ContentProvider")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Janitor = require(ReplicatedStorage:WaitForChild("Shared").Util.Janitor)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local SoundPlayer = {}

local FLAT_SOUNDS = 24
local EMITTERS = 16
local MIN_ROLLOFF_FRACTION = 0.15 -- the sound is full volume out to this share of its range

local flat: { Sound } = {}
local flatIndex = 0
local emitters: { { part: Part, sound: Sound } } = {}
local emitterIndex = 0
local janitor = Janitor.new()
local group: SoundGroup? = nil

local function combatGroup(): SoundGroup
	if group then
		return group
	end
	local created = Instance.new("SoundGroup")
	created.Name = "LocalCombatEffects"
	created.Volume = GameConfig.ClientAudio.DefaultCombatVolume
	created.Parent = SoundService
	janitor:Add(created)
	group = created
	return created
end

function SoundPlayer.setVolume(value: number)
	if value ~= value or math.abs(value) == math.huge then
		return
	end
	combatGroup().Volume = math.clamp(value, 0, 1)
end

local function flatSound(): Sound
	if #flat == 0 then
		for _ = 1, FLAT_SOUNDS do
			local sound = Instance.new("Sound")
			sound.Name = "CombatSound"
			sound.SoundGroup = combatGroup()
			sound.Parent = SoundService
			janitor:Add(sound)
			table.insert(flat, sound)
		end
	end
	flatIndex = flatIndex % FLAT_SOUNDS + 1
	return flat[flatIndex]
end

local function emitter(): { part: Part, sound: Sound }
	if #emitters == 0 then
		local folder = Instance.new("Folder")
		folder.Name = "CombatEmitters"
		-- A respawn or spectator transition may destroy CurrentCamera. World sounds must survive that camera.
		folder.Parent = workspace
		janitor:Add(folder)
		for _ = 1, EMITTERS do
			local part = Instance.new("Part")
			part.Name = "Emitter"
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Transparency = 1
			part.Size = Vector3.one * 0.2
			part.Parent = folder
			local sound = Instance.new("Sound")
			sound.SoundGroup = combatGroup()
			sound.RollOffMode = Enum.RollOffMode.Linear
			sound.Parent = part
			table.insert(emitters, { part = part, sound = sound })
		end
	end
	emitterIndex = emitterIndex % EMITTERS + 1
	return emitters[emitterIndex]
end

function SoundPlayer.preload(ids: { string })
	local sounds: { Sound } = {}
	local seen: { [string]: boolean } = {}
	for _, id in ids do
		if id == "" or seen[id] then
			continue
		end
		seen[id] = true
		local sound = Instance.new("Sound")
		sound.SoundId = id
		table.insert(sounds, sound)
	end
	task.spawn(function()
		local ok, reason = pcall(function()
			ContentProvider:PreloadAsync(sounds)
		end)
		for _, sound in sounds do
			sound:Destroy()
		end
		if not ok then
			warn(`[Audio] Could not preload combat sounds: {reason}`)
		end
	end)
end

function SoundPlayer.play(id: string, volume: number, pitch: number?)
	local sound = flatSound()
	sound:Stop()
	sound.SoundId = id
	sound.Volume = volume
	sound.PlaybackSpeed = pitch or 1
	sound.TimePosition = 0
	sound:Play()
end

function SoundPlayer.playAt(id: string, position: Vector3, volume: number, range: number)
	local slot = emitter()
	slot.sound:Stop()
	slot.part.Position = position
	slot.sound.SoundId = id
	slot.sound.Volume = volume
	slot.sound.RollOffMinDistance = range * MIN_ROLLOFF_FRACTION
	slot.sound.RollOffMaxDistance = range
	slot.sound.TimePosition = 0
	slot.sound:Play()
end

janitor:Add(script.Destroying:Connect(function()
	janitor:Destroy()
	table.clear(flat)
	table.clear(emitters)
	group = nil
end))

return SoundPlayer
