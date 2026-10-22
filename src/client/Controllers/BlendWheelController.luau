--!strict
-- The Blend wheel (spec 6.7): hold Blend to open a radial of social emotes, point at one and let go to play it.
-- An emote stops as soon as the player moves. Emotes are not cover-breaking.
--
-- The animations are the same ones NPCs play at their nodes (Defs/PoseDefs). The client plays them on its own
-- character, and Roblox shows them to everyone, so no server request is needed. Sit only works near a Seat-tagged
-- part. While the wheel is open the camera is held still so the mouse can choose a slice; the match keeps running.

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local PoseAnimation = require(Shared:WaitForChild("Util"):WaitForChild("PoseAnimation"))

local BlendWheelController = {}

local ui = GameConfig.UI
local cover = GameConfig.Cover
local emotes = cover.BlendEmotes
local localPlayer = Players.LocalPlayer

local gui: ScreenGui? = nil
local slices: { TextLabel } = {}
local animations: { [string]: Animation } = {}
local playing: AnimationTrack? = nil
local open = false
local selected: number? = nil
local stick = Vector2.zero

local function humanoidOf(): Humanoid?
	local character = localPlayer.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function nearSeat(): boolean
	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return false
	end
	for _, seat in CollectionService:GetTagged(Enums.Tag.Seat) do
		if seat:IsA("BasePart") and (seat.Position - root.Position).Magnitude <= cover.SeatRange then
			return true
		end
	end
	return false
end

local function stopEmote()
	if playing then
		playing:Stop(GameConfig.NPC.AnimationFadeSeconds)
		playing = nil
	end
end

local function playEmote(name: string)
	stopEmote()
	local poseName = (cover.BlendEmoteAnimations :: { [string]: string })[name]
	local animation = poseName and animations[poseName]
	local humanoid = humanoidOf()
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not (animation and animator) then
		return -- Idle: nothing to play, the base idle shows
	end
	local track = animator:LoadAnimation(animation)
	playing = track
	track:Play(GameConfig.NPC.AnimationFadeSeconds)
end

local function enabled(name: string): boolean
	return name ~= "Sit" or nearSeat()
end

local function buildGui()
	local wheel = Instance.new("ScreenGui")
	wheel.Name = "BlendWheel"
	wheel.ResetOnSpawn = false
	wheel.IgnoreGuiInset = true
	wheel.Enabled = false
	for index, name in emotes do
		local angle = (index - 1) / #emotes * 2 * math.pi
		local text = Instance.new("TextLabel")
		text.Name = name
		text.AnchorPoint = Vector2.new(0.5, 0.5)
		text.Position =
			UDim2.new(0.5, math.sin(angle) * ui.BlendWheelRadius, 0.5, -math.cos(angle) * ui.BlendWheelRadius)
		text.Size = UDim2.fromOffset(110, 30)
		text.BackgroundTransparency = 0.5
		text.BackgroundColor3 = Color3.new(0, 0, 0)
		text.Font = ui.Font
		text.TextSize = ui.TextSize
		text.TextColor3 = ui.TextColor
		text.Text = string.upper(name)
		text.Parent = wheel
		table.insert(slices, text)
	end
	wheel.Parent = localPlayer:WaitForChild("PlayerGui")
	gui = wheel
end

-- The slice the pointer is on, or nil if it is still near the centre.
local function sliceAt(vector: Vector2): number?
	if vector.Magnitude < ui.BlendWheelDeadZone then
		return nil
	end
	local angle = math.atan2(vector.X, -vector.Y) % (2 * math.pi)
	local width = 2 * math.pi / #emotes
	return math.floor((angle + width / 2) / width) % #emotes + 1
end

local function refresh()
	local pointer = stick
	if UserInputService.MouseEnabled and stick.Magnitude < 0.1 then
		local camera = workspace.CurrentCamera
		if camera then
			local mouse = UserInputService:GetMouseLocation()
			pointer = (mouse - camera.ViewportSize / 2) / ui.BlendWheelRadius
		end
	end
	selected = sliceAt(pointer)
	for index, text in slices do
		local on = enabled(emotes[index])
		text.TextColor3 = if on then ui.TextColor else ui.BlendWheelDisabledColor
		text.BackgroundTransparency = if index == selected and on then 0.1 else 0.6
	end
end

local function openWheel()
	if open or not gui then
		return
	end
	open = true
	selected = nil
	local camera = workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Scriptable -- hold the view still while choosing
	end
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	gui.Enabled = true
	refresh()
end

local function closeWheel(commit: boolean)
	if not open or not gui then
		return
	end
	open = false
	gui.Enabled = false
	local camera = workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Custom
	end
	if commit and selected and enabled(emotes[selected]) then
		playEmote(emotes[selected])
	end
end

local function onBlend(_: string, state: Enum.UserInputState)
	if state == Enum.UserInputState.Begin then
		openWheel()
	elseif state == Enum.UserInputState.End then
		closeWheel(true)
	elseif state == Enum.UserInputState.Cancel then
		closeWheel(false)
	end
	return Enum.ContextActionResult.Pass
end

function BlendWheelController.Init() end

function BlendWheelController.Start()
	animations = PoseAnimation.registerAll()
	buildGui()
	ContextActionService:BindAction("Blend", onBlend, false, GameConfig.Controls.Blend, GameConfig.Controls.BlendPad)

	UserInputService.InputChanged:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Thumbstick1 then
			stick = Vector2.new(input.Position.X, -input.Position.Y)
		end
	end)

	RunService.Heartbeat:Connect(function()
		if open then
			refresh()
		end
		-- Moving ends an emote (spec 6.7).
		local humanoid = humanoidOf()
		if playing and humanoid and humanoid.MoveDirection.Magnitude > 0.1 then
			stopEmote()
		end
	end)
end

return BlendWheelController
