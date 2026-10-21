--!strict
-- The one character rig (spec 8.2, 25.3). Players and NPCs both come from the same R15 template, are dressed by
-- the same OutfitApplier, and are made anonymous by the same code, so nothing but behaviour tells them apart.
--
--   * Roblox avatar items are never loaded: LoadCharacterAppearance is off and every character is stripped.
--   * Players spawn through RigService, wearing a random Guest outfit.
--   * No nametags or health bars, and no chat bubbles. Character names are random so they don't reveal the user.
--
--   RigService.createRig(outfit, cframe) -> Model   (a dressed, anonymous rig in Workspace, for NPCs)

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local OutfitApplier = require(Shared:WaitForChild("Util"):WaitForChild("OutfitApplier"))
local OutfitDefs = require(Shared:WaitForChild("Defs"):WaitForChild("OutfitDefs"))
local Types = require(Shared:WaitForChild("Types"))

type OutfitDef = Types.OutfitDef

local RigService = {}

local STARTER_CHARACTER = "StarterCharacter"
local TEST_NPC_OFFSET = CFrame.new(0, 0, -6) -- beside the player, so the two can be compared by eye

local template: Model? = nil
local rng = Random.new()
local testNpcs: { [Player]: Model } = {}

local function randomName(): string
	return (HttpService:GenerateGUID(false):gsub("-", ""):sub(1, 12))
end

-- Rule 3: nothing on a character reveals who or what it is.
local function makeAnonymous(model: Model)
	model.Name = randomName()
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	end
end

local function buildTemplate(): Model
	-- A blank R15 body: no avatar items, no clothing, no player's look.
	local rig =
		Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	OutfitApplier.strip(rig)
	rig.Name = STARTER_CHARACTER
	return rig
end

function RigService.createRig(outfit: OutfitDef, cframe: CFrame): Model
	assert(template, "RigService has not started yet")
	local rig = template:Clone()
	rig.Parent = workspace
	rig:PivotTo(cframe)
	OutfitApplier.apply(rig, outfit)
	makeAnonymous(rig)
	return rig
end

local function spawnTestNpc(player: Player, outfit: OutfitDef, character: Model)
	local old = testNpcs[player]
	if old then
		old:Destroy()
	end
	testNpcs[player] = RigService.createRig(outfit, character:GetPivot() * TEST_NPC_OFFSET)
end

local function onCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	-- Roblox adds a Health script to player characters only. It regenerates health (spec 13.1 says no passive regen)
	-- and NPCs don't have it, so it would be a tell.
	local healthScript = character:WaitForChild("Health", 2)
	if healthScript then
		healthScript:Destroy()
	end
	local outfit = OutfitDefs.random(Enums.Role.Guest, rng)
	OutfitApplier.apply(character, outfit)
	makeAnonymous(character)

	if GameConfig.Debug.SpawnTestNpc then
		spawnTestNpc(player, outfit, character)
	end
	if GameConfig.Debug.AutoRespawn then
		humanoid.Died:Once(function()
			task.delay(GameConfig.Debug.AutoRespawnSeconds, function()
				if player.Parent then
					player:LoadCharacter()
				end
			end)
		end)
	end
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	task.spawn(player.LoadCharacter, player)
end

function RigService.Init()
	-- Spawning goes through us, and Roblox must not put the player's avatar on the rig.
	Players.CharacterAutoLoads = false
	StarterPlayer.LoadCharacterAppearance = false
	local bubbles = TextChatService:FindFirstChild("BubbleChatConfiguration")
	if bubbles and bubbles:IsA("BubbleChatConfiguration") then
		bubbles.Enabled = false
	end
end

function RigService.Start()
	local rig = buildTemplate()
	template = rig

	-- Every player's character is a copy of this model.
	local existing = StarterPlayer:FindFirstChild(STARTER_CHARACTER)
	if existing then
		existing:Destroy()
	end
	rig:Clone().Parent = StarterPlayer

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local npc = testNpcs[player]
		if npc then
			npc:Destroy()
		end
		testNpcs[player] = nil
	end)
end

return RigService
