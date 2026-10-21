--!strict
-- The one character rig (spec 8.2, 25.3). Players and NPCs both come from the same R15 template, are dressed by
-- the same OutfitApplier, and are made anonymous by the same code, so nothing but behaviour tells them apart.
--
--   * Roblox avatar items are never loaded: LoadCharacterAppearance is off and every character is stripped.
--   * Players spawn through RigService, wearing a random Guest outfit.
--   * No nametags or health bars, and no chat bubbles. Character names are random so they don't reveal the user.
--   * Every part of every character is in one collision group (GameConfig.Rig), including parts added later.
--
--   RigService.createNpcRig(outfit, cframe) -> (Model, number)
--     A dressed, anonymous rig in Workspace for an NPC (spec 25.4): no Humanoid, an AnimationController so clients
--     can animate it, and an anchored HumanoidRootPart the server moves. The number is how high the root's centre
--     sits above the ground. Yields until the template is built.

local HttpService = game:GetService("HttpService")
local PhysicsService = game:GetService("PhysicsService")
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

local template: Model? = nil
local templateReady = Instance.new("BindableEvent")
local rng = Random.new()

local function randomName(): string
	return (HttpService:GenerateGUID(false):gsub("-", ""):sub(1, 12))
end

-- Spec 8.2: players and NPCs collide the same way, so every character part goes in one group, now and later.
local function joinCollisionGroup(model: Model)
	local group = GameConfig.Rig.CollisionGroup
	local function assign(instance: Instance)
		if instance:IsA("BasePart") then
			instance.CollisionGroup = group
		end
	end
	for _, descendant in model:GetDescendants() do
		assign(descendant)
	end
	model.DescendantAdded:Connect(assign)
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

local function getTemplate(): Model
	if not template then
		templateReady.Event:Wait()
	end
	return template :: Model
end

-- The server's own camera is inside Workspace (so the Humanoid can scale the body and fit accessories) but its
-- children never replicate. NPC rigs are built there and only appear to clients once they are finished, so no
-- client ever sees an NPC with a Humanoid.
local function stagingArea(): Instance
	local camera = workspace.CurrentCamera
	assert(camera, "The server has no CurrentCamera to build NPC rigs in")
	return camera
end

-- The Humanoid fits accessories with RigidConstraints, which stop holding once the Humanoid is gone (the
-- accessories fall off). Swap each for a Weld to its body part so it becomes part of the anchored body.
local function weldAccessories(rig: Model)
	for _, accessory in rig:GetChildren() do
		local handle = accessory:IsA("Accessory") and accessory:FindFirstChild("Handle")
		if handle and handle:IsA("BasePart") then
			for _, constraint in handle:GetChildren() do
				if constraint:IsA("RigidConstraint") and constraint.Attachment0 and constraint.Attachment1 then
					local handleAttachment, bodyAttachment = constraint.Attachment0, constraint.Attachment1
					if handleAttachment.Parent ~= handle then
						handleAttachment, bodyAttachment = bodyAttachment, handleAttachment
					end
					local weld = Instance.new("Weld")
					weld.Name = "AccessoryWeld"
					weld.Part0 = bodyAttachment.Parent :: BasePart
					weld.Part1 = handle
					weld.C0 = bodyAttachment.CFrame
					weld.C1 = handleAttachment.CFrame
					weld.Parent = handle
					constraint:Destroy()
				end
			end
		end
	end
end

function RigService.createNpcRig(outfit: OutfitDef, cframe: CFrame): (Model, number)
	local rig = getTemplate():Clone()
	rig.Parent = stagingArea()
	rig:PivotTo(cframe)
	-- The Humanoid applies the outfit's scale and accessories, then is swapped for a cheap AnimationController.
	OutfitApplier.apply(rig, outfit)
	makeAnonymous(rig)
	joinCollisionGroup(rig)

	local humanoid = rig:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = rig:FindFirstChild("HumanoidRootPart") :: BasePart
	local rootHeight = humanoid.HipHeight + root.Size.Y / 2
	weldAccessories(rig)
	humanoid:Destroy()

	local controller = Instance.new("AnimationController")
	Instance.new("Animator").Parent = controller
	controller.Parent = rig
	root.Anchored = true
	-- With streaming on, a client receives the whole rig or nothing, never a body without its root or animator.
	rig.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	rig.Parent = workspace
	return rig, rootHeight
end

local function onCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	-- Roblox adds a Health script to player characters only. It regenerates health (spec 13.1 says no passive regen)
	-- and NPCs don't have it, so it would be a tell.
	local healthScript = character:WaitForChild("Health", 2)
	if healthScript then
		healthScript:Destroy()
	end
	OutfitApplier.apply(character, OutfitDefs.random(Enums.Role.Guest, rng))
	makeAnonymous(character)
	joinCollisionGroup(character)

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

	local group = GameConfig.Rig.CollisionGroup
	if not PhysicsService:IsCollisionGroupRegistered(group) then
		PhysicsService:RegisterCollisionGroup(group)
	end
	PhysicsService:CollisionGroupSetCollidable(group, group, GameConfig.Rig.CharactersCollideWithEachOther)
	local bubbles = TextChatService:FindFirstChild("BubbleChatConfiguration")
	if bubbles and bubbles:IsA("BubbleChatConfiguration") then
		bubbles.Enabled = false
	end
end

function RigService.Start()
	local rig = buildTemplate()

	-- Every player's character is a copy of this model.
	local existing = StarterPlayer:FindFirstChild(STARTER_CHARACTER)
	if existing then
		existing:Destroy()
	end
	rig:Clone().Parent = StarterPlayer

	template = rig
	templateReady:Fire()

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return RigService
