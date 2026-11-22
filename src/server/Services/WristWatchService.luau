--!strict
-- Wrist watch (owner test 2026-11-21): while a player hacks (any InteractService hold named in GameConfig.WristWatch.HackLabels) and,
-- briefly, while they re-cover, a small watch sits on their left wrist. It is a real part welded to the character, so every client sees
-- it, and it is removed as soon as the action ends (plus LingerSeconds), so nobody carries one the rest of the time. Hacking is already
-- something NPCs never do. The wrist watch is built only while the agent is Exposed (a covered agent shows none, so it never marks a disguised
-- player), on any look. The owner always gets WristWatchState to draw their own raised first-person watch.
--
-- The model is named "Watch" and carries no player, team or agent information. A character that is destroyed takes its watch with it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Types = require(Shared:WaitForChild("Types"))
local CoverService = require(script.Parent.CoverService)
local DisguiseService = require(script.Parent.DisguiseService)
local DroneService = require(script.Parent.DroneService)
local InteractService = require(script.Parent.InteractService)
local RemoteService = require(script.Parent.RemoteService)

local WristWatchService = {}

local config = GameConfig.WristWatch

type Shown = { watch: Model?, holdUntil: number, kind: string }

local shown: { [Player]: Shown } = {}

local function weld(parent: Instance, part0: BasePart, part1: BasePart, offset: CFrame)
	part1.CFrame = part0.CFrame * offset
	local joint = Instance.new("WeldConstraint")
	joint.Part0, joint.Part1 = part0, part1
	joint.Parent = parent
end

local function plain(part: Part)
	part.Anchored = false
	part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = false, false, false, false
	part.Massless = true
end

local function build(hand: BasePart): Model
	local watch = Instance.new("Model")
	watch.Name = "Watch"
	local band = Instance.new("Part")
	band.Name = "Band"
	band.Shape = Enum.PartType.Cylinder
	band.Size = config.BandSize
	band.Color = config.BandColor
	band.Material = Enum.Material.SmoothPlastic
	plain(band)
	band.Parent = watch
	local face = Instance.new("Part")
	face.Name = "Face"
	face.Size = config.FaceSize
	face.Color = config.FaceColor
	face.Material = Enum.Material.Neon
	plain(face)
	face.Parent = watch
	-- A cylinder's axis is its X; turn the ring so its axis runs along the forearm (the hand's Y).
	weld(watch, hand, band, config.BandOffset * CFrame.Angles(0, 0, math.pi / 2))
	weld(watch, hand, face, config.FaceOffset)
	watch.PrimaryPart = band
	return watch
end

local function remove(player: Player)
	local entry = shown[player]
	if entry then
		shown[player] = nil
		if entry.watch then
			entry.watch:Destroy()
		end
	end
end

local function tellOwner(player: Player, kind: string, seconds: number, active: boolean)
	local info: Types.WristWatchInfo = { Kind = kind, Seconds = seconds, Active = active }
	RemoteService.fireClient("WristWatchState", player, info)
end

-- The watch goes up for `seconds` (and an action that ends sooner lowers it sooner, see lower). The owner always gets their own raised
-- watch. The one on the wrist that everyone sees goes on only while the agent is Exposed (out of cover), on whatever look they wear:
-- a covered agent's wrist shows nothing, so a watch never marks a disguised player.
local function raise(player: Player, kind: string, seconds: number)
	local character = player.Character
	local hand = character and character:FindFirstChild("LeftHand")
	if not (character and hand and hand:IsA("BasePart")) then
		return
	end
	local entry = shown[player]
	if entry and entry.watch and entry.watch.Parent ~= character then
		remove(player)
		entry = nil
	end
	if not entry then
		entry = { watch = nil, holdUntil = 0, kind = kind }
		shown[player] = entry
	end
	local mine = entry :: Shown
	if not mine.watch and CoverService.isExposed(player) then
		local created = build(hand)
		created.Parent = character
		mine.watch = created
	end
	mine.kind = kind
	mine.holdUntil = os.clock() + seconds + config.LingerSeconds
	tellOwner(player, kind, seconds, true)
	local stamp = mine.holdUntil
	task.delay(seconds + config.LingerSeconds, function()
		local now = shown[player]
		if now == mine and now.holdUntil == stamp then
			remove(player)
			tellOwner(player, mine.kind, 0, false)
		end
	end)
end

-- Lowers the watch when the action of this kind ends (a hack ending does not take down a re-cover's watch, nor the reverse).
local function lower(player: Player, kind: string)
	local entry = shown[player]
	if not entry or entry.kind ~= kind then
		return
	end
	local stamp = os.clock() + config.LingerSeconds
	entry.holdUntil = stamp
	tellOwner(player, kind, 0, false)
	task.delay(config.LingerSeconds, function()
		local now = shown[player]
		if now == entry and now.holdUntil == stamp then
			remove(player)
		end
	end)
end

function WristWatchService.Init() end

function WristWatchService.Start()
	InteractService.onHold(function(player, label, active, seconds)
		if not config.HackLabels[label] then
			return
		end
		if active then
			-- A drone's hack is not seen on her body (IntelService), so her wrist shows nothing either.
			if DroneService.position(player) == nil then
				raise(player, "Hack", math.max(seconds, 0))
			end
		else
			lower(player, "Hack")
		end
	end)
	DisguiseService.onRecoverBegan(function(player, seconds)
		raise(player, "Recover", seconds)
	end)
	DisguiseService.onRecoverEnded(function(player)
		lower(player, "Recover")
	end)
	Players.PlayerRemoving:Connect(function(player)
		remove(player)
	end)
end

return WristWatchService
