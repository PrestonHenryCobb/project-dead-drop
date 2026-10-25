--!strict
-- The two bodies of a takedown hold (R5-takedown). The server owns the hold; this only poses this player's own
-- character, which every other client then sees through normal animation replication:
--
--   * Taking someone down (MeleeState Kind "Takedown", Active): arms locked round the target (TakedownGrab).
--   * Being taken down (TakedownVictim, sent only to the target): clawing at the hold (TakedownStruggle).
--
-- A held NPC is posed by the server through NPCAnimation, so both bodies look the same whoever they are. The poses stop
-- the moment the hold ends, whether it broke or completed; the result of a completed hold (MeleeState Result) is the
-- server's word on whether the target went down, and nothing here confirms a kill.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local PoseAnimation = require(Shared:WaitForChild("Util"):WaitForChild("PoseAnimation"))
local Types = require(Shared:WaitForChild("Types"))
local RemoteController = require(script.Parent.RemoteController)

local TakedownBodyController = {}

local localPlayer = Players.LocalPlayer
local fade = GameConfig.NPC.AnimationFadeSeconds

local tracks: { [string]: AnimationTrack } = {}

local function setPose(name: string, on: boolean)
	local track = tracks[name]
	if not on then
		if track then
			track:Stop(fade)
		end
		return
	end
	if not track then
		local character = localPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
		local animation = PoseAnimation.registerAll()[name]
		if not (animator and animation) then
			return
		end
		track = animator:LoadAnimation(animation)
		tracks[name] = track
	end
	local loaded = track :: AnimationTrack
	if not loaded.IsPlaying then
		loaded:Play(fade)
	end
end

local function stopAll()
	for _, track in tracks do
		track:Stop(fade)
	end
	table.clear(tracks)
end

function TakedownBodyController.Init() end

function TakedownBodyController.Start()
	RemoteController.connect("MeleeState", function(info: Types.MeleeState)
		if info.Kind == "Takedown" then
			setPose(Enums.NpcAnimation.TakedownGrab, info.Active)
		elseif info.Kind == "Strike" then
			setPose(Enums.NpcAnimation.TakedownGrab, false)
		end
	end)
	RemoteController.connect("TakedownVictim", function(info: Types.TakedownVictimInfo)
		setPose(Enums.NpcAnimation.TakedownStruggle, info.Active)
	end)
	RemoteController.connect("Downed", stopAll)
	RemoteController.connect("Eliminated", stopAll)
	localPlayer.CharacterAdded:Connect(stopAll)
end

return TakedownBodyController
