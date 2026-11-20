--!strict
-- The client side of spectating (SPEC_CHANGES 14.4, ticket 9c). The server says who this player may watch
-- (SpectateState); this draws it: an orbit camera behind the watched player, or a free drone camera, a line saying
-- what is being watched, and the spectator chat. The drone sends its wanted position and the server limits and clamps
-- it. Nothing here reaches anyone still alive.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local InputHints = require(Shared.Util.InputHints)
local Types = require(Shared:WaitForChild("Types"))
local HudKit = require(Shared:WaitForChild("Util"):WaitForChild("HudKit"))
local HudTheme = require(Shared:WaitForChild("Util"):WaitForChild("HudTheme"))
local Janitor = require(Shared:WaitForChild("Util"):WaitForChild("Janitor"))
local RemoteController = require(script.Parent.RemoteController)
local HeldItemController = require(script.Parent.HeldItemController)
local CameraGuard = require(script.Parent.Parent.Combat.CameraGuard)
local FlightInput = require(script.Parent.Parent.Combat.FlightInput)

local SpectateController = {}

local config = GameConfig.Spectate
local keys = config.Keys
local graphics = HudTheme.get()
local STEP_NAME = "CoverStorySpectate"
local CHAT_ACTION = "CoverStorySpectateChat"
local CHAT_LINE_PIXELS = 20
local CHAT_WIDTH_PIXELS = 360

local janitor = Janitor.new()
local sessionJanitor = Janitor.new()
local active = false
local phase: Types.Phase? = nil
local mode = "None"
local targetUserId: number? = nil
local canDrone = false
local yaw = 0
local pitch = 0
local dronePosition = Vector3.zero
local sendElapsed = 0
local lastSent = Vector3.zero
local statusRoot: Frame? = nil
local statusText: TextLabel? = nil
local chatRoot: Frame? = nil
local chatBox: TextBox? = nil
local chatLines: { { label: TextLabel, at: number } } = {}

local wallParams = RaycastParams.new()
wallParams.CollisionGroup = GameConfig.Rig.CollisionGroup
wallParams.RespectCanCollide = true

local function matches(input: InputObject, key: EnumItem): boolean
	return input.KeyCode == key or input.UserInputType == key
end

local function targetRoot(): BasePart?
	local userId = targetUserId
	local player = if userId then Players:GetPlayerByUserId(userId) else nil
	local root = player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function describe(): string
	local hints = InputHints.line({
		{
			Label = "switch",
			Key = keys.Previous,
			Second = keys.Next,
			Pad = GameConfig.ClientFlight.PreviousPad,
			PadSecond = GameConfig.ClientFlight.NextPad,
		},
		{
			Label = if mode == "Drone" then "follow" else "drone",
			Key = keys.Drone,
			Pad = GameConfig.ClientFlight.DronePad,
		},
	})
	if mode == "Drone" then
		return `SPECTATING: DRONE    {hints}{InputHints.text(
			"\nWASD FLY · MOUSE LOOK · SPACE/CTRL HEIGHT · SHIFT BOOST",
			"\nLEFT STICK FLY · RIGHT STICK LOOK · A/B HEIGHT · L3 BOOST"
		)}`
	elseif mode == "None" then
		return "SPECTATING: NOBODY LEFT TO WATCH"
	end
	local userId = targetUserId
	local player = if userId then Players:GetPlayerByUserId(userId) else nil
	local name = if player then player.DisplayName else "..."
	return `SPECTATING: {string.upper(name)}    {hints}`
end

local function orbitCamera(camera: Camera)
	local root = targetRoot()
	if not root then
		return
	end
	local camConfig = config.Camera
	local focus = root.Position + Vector3.new(0, camConfig.Height, 0)
	local rotation = CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
	local back = rotation.LookVector * -1
	local reach = camConfig.Distance
	local hit = workspace:Raycast(focus, back * (reach + camConfig.WallPadding), wallParams)
	if hit then
		reach = math.max(0.5, (hit.Position - focus).Magnitude - camConfig.WallPadding)
	end
	camera.CFrame = CFrame.lookAt(focus + back * reach, focus)
end

local function axis(positive: { Enum.KeyCode }, negative: { Enum.KeyCode }): number
	local value = 0
	for _, key in positive do
		if UserInputService:IsKeyDown(key) then
			value += 1
			break
		end
	end
	for _, key in negative do
		if UserInputService:IsKeyDown(key) then
			value -= 1
			break
		end
	end
	return value
end

local function droneCamera(camera: Camera, dt: number, padMove: Vector2, padUp: number, padBoost: boolean)
	local controls = GameConfig.Controls
	local look = CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
	if not HeldItemController.isInputBlocked() then
		local forward = axis(controls.MoveForward, controls.MoveBack)
		local side = axis(controls.MoveRight, controls.MoveLeft)
		local rise = (if UserInputService:IsKeyDown(keys.Up) then 1 else 0)
			- (if UserInputService:IsKeyDown(keys.Down) then 1 else 0)
		local wish = look.LookVector * (forward + padMove.Y)
			+ look.RightVector * (side + padMove.X)
			+ Vector3.new(0, rise + padUp, 0)
		if wish.Magnitude > 0 then
			local speed = config.DroneSpeed
				* (if UserInputService:IsKeyDown(keys.Boost) or padBoost then config.DroneBoost else 1)
			dronePosition += (if wish.Magnitude > 1 then wish.Unit else wish) * speed * dt
		end
	end
	camera.CFrame = CFrame.new(dronePosition) * look
	sendElapsed += dt
	if sendElapsed >= 1 / config.DroneSendHz and (dronePosition - lastSent).Magnitude > 0.05 then
		sendElapsed = 0
		lastSent = dronePosition
		RemoteController.fire("RequestDronePosition", dronePosition)
	end
end

local function step(dt: number)
	if CameraGuard.menuOpen() then
		return
	end
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	camera.CameraType = Enum.CameraType.Scriptable
	local blocked = HeldItemController.isInputBlocked()
	local padMove, padLook, padUp, padBoost = FlightInput.read()
	UserInputService.MouseBehavior = if blocked then Enum.MouseBehavior.Default else Enum.MouseBehavior.LockCenter
	if not blocked then
		local delta = UserInputService:GetMouseDelta()
		local radians = math.rad(config.Camera.DegreesPerPixel)
		local limit = math.rad(config.Camera.PitchLimitDegrees)
		local stickRadians = math.rad(GameConfig.ClientFlight.LookDegreesPerSecond) * dt
		yaw -= delta.X * radians + padLook.X * stickRadians
		pitch = math.clamp(pitch - delta.Y * radians + padLook.Y * stickRadians, -limit, limit)
	end
	if mode == "Drone" then
		droneCamera(camera, dt, padMove, padUp, padBoost)
	elseif mode == "Teammate" or mode == "Player" then
		orbitCamera(camera)
	end
	if statusText then
		statusText.Text = describe()
	end
	local now = os.clock()
	local typing = chatBox ~= nil and chatBox:IsFocused()
	for _, line in chatLines do
		line.label.Visible = typing or now - line.at < config.ChatFadeSeconds
	end
end

local function addChatLine(info: Types.SpectatorChatInfo)
	local root = chatRoot
	if not root then
		return
	end
	local label = HudKit.text(root, "Line", UDim2.new(), Vector2.zero, UDim2.new(1, 0, 0, CHAT_LINE_PIXELS))
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextWrapped = true
	label.Text = `{info.Sender}: {info.Text}`
	label.LayoutOrder = (chatLines[#chatLines] and chatLines[#chatLines].label.LayoutOrder or 0) + 1
	table.insert(chatLines, { label = label, at = os.clock() })
	while #chatLines > config.ChatLines do
		local oldest = table.remove(chatLines, 1)
		if oldest then
			oldest.label:Destroy()
		end
	end
end

local function openChat(_: string, state: Enum.UserInputState): Enum.ContextActionResult
	if not active or HeldItemController.isInputBlocked() then
		return Enum.ContextActionResult.Pass
	end
	if state == Enum.UserInputState.Begin and chatBox and not chatBox:IsFocused() then
		task.defer(function()
			if active and chatBox and not HeldItemController.isInputBlocked() then
				chatBox:CaptureFocus()
			end
		end)
	end
	return Enum.ContextActionResult.Sink
end

local function startSession()
	active = true
	CameraGuard.setRemoteView(script, true)
	RunService:BindToRenderStep(STEP_NAME, Enum.RenderPriority.Camera.Value + 2, step) -- after DisguiseFacing
	sessionJanitor:Add(function()
		RunService:UnbindFromRenderStep(STEP_NAME)
	end)
	sessionJanitor:Add(UserInputService.InputBegan:Connect(function(input, processed)
		if processed or HeldItemController.isInputBlocked() then
			return
		end
		if matches(input, keys.Next) or matches(input, GameConfig.ClientFlight.NextPad) then
			RemoteController.fire("RequestSpectate", "Next")
		elseif matches(input, keys.Previous) or matches(input, GameConfig.ClientFlight.PreviousPad) then
			RemoteController.fire("RequestSpectate", "Previous")
		elseif
			(matches(input, keys.Drone) or matches(input, GameConfig.ClientFlight.DronePad))
			and (canDrone or mode == "Drone")
		then
			RemoteController.fire("RequestSpectate", "Drone")
		end
	end))
	ContextActionService:BindActionAtPriority(
		CHAT_ACTION,
		openChat,
		false,
		Enum.ContextActionPriority.High.Value,
		keys.Chat
	)
	sessionJanitor:Add(function()
		ContextActionService:UnbindAction(CHAT_ACTION)
	end)
	local camera = workspace.CurrentCamera
	if camera then
		local _, cameraYaw, _ = camera.CFrame:ToOrientation()
		yaw, pitch = cameraYaw, 0
		dronePosition = camera.CFrame.Position
		lastSent = dronePosition
	end
end

local function stopSession()
	active = false
	CameraGuard.setRemoteView(script, false)
	sessionJanitor:Cleanup()
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	CameraGuard.restoreGameplay()
	if statusRoot then
		statusRoot.Visible = false
	end
	if chatRoot then
		chatRoot.Visible = false
	end
end

local function onState(info: Types.SpectateStateInfo)
	if phase == "Lobby" or phase == "Insertion" or phase == "Results" then
		if active then
			stopSession()
		end
		return
	end
	mode, targetUserId, canDrone = info.Mode, info.TargetUserId, info.CanDrone
	if info.DronePosition then
		dronePosition = info.DronePosition
		lastSent = dronePosition
	end
	local spectating = info.Mode ~= "None"
	if spectating and not active then
		startSession()
		if statusRoot then
			statusRoot.Visible = true
		end
		if chatRoot then
			chatRoot.Visible = true
		end
	elseif not spectating and active then
		stopSession()
	end
end

function SpectateController.Init() end

function SpectateController.Start()
	local gui = HudKit.screen("SpectateHud")
	janitor:Add(gui)
	local panel = HudKit.panel(
		gui,
		"Status",
		UDim2.new(0.5, 0, 1, -graphics.PaddingPixels * 3),
		Vector2.new(0.5, 1),
		UDim2.fromOffset(graphics.ActionWidthPixels * 2, graphics.ActionHeightPixels)
	)
	statusRoot = panel.Parent :: Frame
	statusRoot.Visible = false
	statusText = HudKit.text(
		panel,
		"Text",
		UDim2.fromOffset(graphics.PaddingPixels, graphics.PaddingPixels),
		Vector2.zero,
		UDim2.new(1, -graphics.PaddingPixels * 2, 1, -graphics.PaddingPixels * 2)
	)
	statusText.TextWrapped = true
	statusText.TextSize = graphics.CaptionSize
	local chat = Instance.new("Frame")
	chat.Name = "Chat"
	chat.BackgroundTransparency = 1
	chat.AnchorPoint = Vector2.new(0, 1)
	chat.Position = UDim2.new(0, graphics.PaddingPixels * 2, 1, -graphics.PaddingPixels * 3)
	chat.Size = UDim2.fromOffset(CHAT_WIDTH_PIXELS, CHAT_LINE_PIXELS * (config.ChatLines + 1))
	chat.Visible = false
	chat.Parent = gui
	chatRoot = chat
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.Parent = chat
	local box = Instance.new("TextBox")
	box.Name = "Input"
	box.LayoutOrder = math.huge
	box.Size = UDim2.new(1, 0, 0, CHAT_LINE_PIXELS)
	box.BackgroundTransparency = 0.5
	box.BackgroundColor3 = Color3.new(0, 0, 0)
	box.BorderSizePixel = 0
	box.ClearTextOnFocus = false
	box.Font = graphics.Font
	box.TextSize = GameConfig.UI.TextSize
	box.TextColor3 = GameConfig.UI.TextColor
	box.TextXAlignment = Enum.TextXAlignment.Left
	local function chatHint()
		box.PlaceholderText = InputHints.bracket(keys.Chat, nil, "spectator chat")
	end
	chatHint()
	janitor:Add(InputHints.onChange(chatHint))
	box.Text = ""
	box.Parent = chat
	chatBox = box
	janitor:Add(box.FocusLost:Connect(function(enterPressed)
		local text = box.Text
		box.Text = ""
		if enterPressed and string.match(text, "%S") then
			RemoteController.fire("RequestSpectatorChat", string.sub(text, 1, config.ChatMaxLength))
		end
	end))
	janitor:Add(RemoteController.connect("SpectateState", onState))
	janitor:Add(RemoteController.connect("PhaseChanged", function(value: Types.Phase)
		phase = value
		if (value == "Lobby" or value == "Insertion" or value == "Results") and active then
			stopSession()
		end
	end))
	janitor:Add(Players.LocalPlayer.CharacterAdded:Connect(function()
		if active then
			stopSession()
		end
	end))
	janitor:Add(RemoteController.connect("SpectatorChat", addChatLine))
	janitor:Add(function()
		stopSession()
	end)
	janitor:Add(script.Destroying:Connect(function()
		janitor:Destroy()
	end))
end

return SpectateController
