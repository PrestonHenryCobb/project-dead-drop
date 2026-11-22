--!strict
-- Wrist watch (owner answers 2026-11-21 and 2026-11-22). An Exposed agent (out of cover) wears a watch on the left wrist, on whatever look
-- they have, for as long as they are Exposed; a covered agent shows none, so a watch never marks a disguised player. The watch is a real part
-- welded to the hand, so every client sees it. Its face is dim, and glows (no progress, just lit) while the agent hacks (an InteractService
-- hold named in GameConfig.WristWatch.HackLabels) and while they re-cover. Its colours are the equipped Watch cosmetic (Defs/WatchDefs).
-- The owner also gets WristWatchState for every hack or re-cover, covered or not, to draw their own raised first-person watch; there is no
-- raise pose on the character (first person only). A drone's hack is not seen on her body, so it neither glows the watch nor shows one.
--
-- The model is named "Watch" and carries no player, team or agent information. A character that is destroyed takes its watch with it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Types = require(Shared:WaitForChild("Types"))
local WatchDefs = require(Shared:WaitForChild("Defs"):WaitForChild("WatchDefs"))
local CoverService = require(script.Parent.CoverService)
local DisguiseService = require(script.Parent.DisguiseService)
local DownedService = require(script.Parent.DownedService)
local DroneService = require(script.Parent.DroneService)
local InteractService = require(script.Parent.InteractService)
local MetaProgressionService = require(script.Parent.MetaProgressionService)
local RemoteService = require(script.Parent.RemoteService)

local WristWatchService = {}

local config = GameConfig.WristWatch

type Action = { kind: string, endsAt: number } -- endsAt: os.clock() when the glow ends; math.huge while a hold runs
type Worn = { model: Model, face: Part, look: WatchDefs.WatchLook }

local worn: { [Player]: Worn } = {}
local actions: { [Player]: Action } = {}
local sinceCheck = 0

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

local function build(hand: BasePart, look: WatchDefs.WatchLook): Worn
	local model = Instance.new("Model")
	model.Name = "Watch"
	local band = Instance.new("Part")
	band.Name = "Band"
	band.Shape = Enum.PartType.Cylinder
	band.Size = config.BandSize
	band.Color = look.BandColor
	band.Material = Enum.Material.SmoothPlastic
	plain(band)
	band.Parent = model
	local face = Instance.new("Part")
	face.Name = "Face"
	face.Size = config.FaceSize
	face.Color = config.DimFaceColor
	face.Material = Enum.Material.SmoothPlastic
	plain(face)
	face.Parent = model
	-- A cylinder's axis is its X; turn the ring so its axis runs along the forearm (the hand's Y).
	weld(model, hand, band, config.BandOffset * CFrame.Angles(0, 0, math.pi / 2))
	weld(model, hand, face, config.FaceOffset)
	model.PrimaryPart = band
	return { model = model, face = face, look = look }
end

local function setLit(entry: Worn, lit: boolean)
	entry.face.Material = if lit then Enum.Material.Neon else Enum.Material.SmoothPlastic
	entry.face.Color = if lit then entry.look.FaceColor else config.DimFaceColor
end

local function takeOff(player: Player)
	local entry = worn[player]
	if entry then
		worn[player] = nil
		entry.model:Destroy()
	end
end

-- Brings this player's worn watch in step: on while Exposed and alive, off otherwise; the face glows while an action runs.
local function sync(player: Player)
	local character = player.Character
	local hand = character and character:FindFirstChild("LeftHand")
	local wants = character ~= nil
		and hand ~= nil
		and hand:IsA("BasePart")
		and CoverService.isExposed(player)
		and not DownedService.isOut(player)
	local entry = worn[player]
	if entry and (not wants or entry.model.Parent ~= character) then
		takeOff(player)
		entry = nil
	end
	if wants and not entry and character and hand and hand:IsA("BasePart") then
		entry = build(hand, WatchDefs.look(MetaProgressionService.equippedWatch(player)))
		entry.model.Parent = character
		worn[player] = entry
	end
	if entry then
		local action = actions[player]
		setLit(entry, action ~= nil and action.endsAt > os.clock())
	end
end

local function tellOwner(player: Player, kind: string, seconds: number, active: boolean)
	local info: Types.WristWatchInfo = { Kind = kind, Seconds = seconds, Active = active }
	RemoteService.fireClient("WristWatchState", player, info)
end

-- The glow (and the owner's raised watch) starts for `seconds`.
local function raise(player: Player, kind: string, seconds: number)
	local action: Action = { kind = kind, endsAt = os.clock() + seconds + config.LingerSeconds }
	actions[player] = action
	tellOwner(player, kind, seconds, true)
	sync(player)
	task.delay(seconds + config.LingerSeconds, function()
		if actions[player] == action then
			actions[player] = nil
			tellOwner(player, kind, 0, false)
			sync(player)
		end
	end)
end

-- The action of this kind ended (a hack ending does not end a re-cover's glow, nor the reverse).
local function lower(player: Player, kind: string)
	local action = actions[player]
	if not action or action.kind ~= kind then
		return
	end
	local ending: Action = { kind = kind, endsAt = os.clock() + config.LingerSeconds }
	actions[player] = ending
	tellOwner(player, kind, 0, false)
	task.delay(config.LingerSeconds, function()
		if actions[player] == ending then
			actions[player] = nil
			sync(player)
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
			-- A drone's hack is not seen on her body (IntelService), so the owner sees their watch but nobody else sees a glow.
			if DroneService.position(player) == nil then
				raise(player, "Hack", math.max(seconds, 0))
			else
				tellOwner(player, "Hack", seconds, true)
			end
		else
			lower(player, "Hack")
			tellOwner(player, "Hack", 0, false)
		end
	end)
	DisguiseService.onRecoverBegan(function(player, seconds)
		raise(player, "Recover", seconds)
	end)
	DisguiseService.onRecoverEnded(function(player)
		lower(player, "Recover")
	end)
	Players.PlayerRemoving:Connect(function(player)
		takeOff(player)
		actions[player] = nil
	end)
	RunService.Heartbeat:Connect(function(dt)
		sinceCheck += dt
		if sinceCheck >= 1 / config.CheckHz then
			sinceCheck = 0
			for _, player in Players:GetPlayers() do
				sync(player)
			end
		end
	end)
end

return WristWatchService
