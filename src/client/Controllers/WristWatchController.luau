--!strict
-- Wrist watch (owner test 2026-11-21), your own view: while you hack, or briefly while you re-cover, your left arm lifts a watch in front of
-- you as if checking the time, the gun drops out of view, and a bar on the watch fills over the action's time. The server sends
-- WristWatchState to you only; everyone else sees the real watch the server puts on an Exposed agent's wrist (WristWatchService).
-- The watch is a local part in the camera, never in the world. FirstPersonBodyController draws the left arm to leftHand(); WeaponController
-- lowers the gun by raised().
--
--   WristWatchController.raised() -> number            0 (down) to 1 (up), eased
--   WristWatchController.leftHand(camera) -> CFrame?   where the left hand is while the watch is up or rising, else nil

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Janitor = require(Shared:WaitForChild("Util"):WaitForChild("Janitor"))
local Types = require(Shared:WaitForChild("Types"))
local RemoteController = require(script.Parent.RemoteController)

local WristWatchController = {}

local config = GameConfig.WristWatch.FirstPerson
local BIND = "CoverStoryWristWatch"

local janitor = Janitor.new()
local watch: Part? = nil
local bar: Frame? = nil
local caption: TextLabel? = nil
local raised = 0 -- 0 down, 1 up (tweened)
local raiseTween: Tween? = nil
local startedAt = 0
local seconds = 0
local active = false
local lifted = Instance.new("NumberValue")

function WristWatchController.raised(): number
	return raised
end

-- The left hand's frame in camera space with the watch up: the forearm comes in from the lower left, the back of the hand faces the camera.
local function raisedHand(): CFrame
	local forearm = config.Forearm.Unit
	local back = (Vector3.zAxis - forearm * forearm:Dot(Vector3.zAxis)).Unit
	return CFrame.fromMatrix(config.HandPosition, forearm:Cross(back), forearm, back)
end

-- The hand's frame in camera space at this height: lowered a little off the bottom of the screen at 0, up at 1.
local function handAt(amount: number): CFrame
	local up = raisedHand()
	return up - up.Position + (up.Position + config.DownShift * (1 - amount))
end

function WristWatchController.leftHand(camera: Camera): CFrame?
	if raised <= 0.001 then
		return nil
	end
	return camera.CFrame * handAt(raised)
end

local function build(): Part
	local part = Instance.new("Part")
	part.Name = "ViewWatch"
	part.Size = config.Size
	part.Color = Color3.new(0.1, 0.1, 0.12)
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = false, false, false, false
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 200
	gui.LightInfluence = 0
	gui.AlwaysOnTop = true
	gui.Parent = part
	local screen = Instance.new("Frame")
	screen.Size = UDim2.fromScale(1, 1)
	screen.AnchorPoint = Vector2.new(0.5, 0.5)
	screen.Position = UDim2.fromScale(0.5, 0.5)
	screen.Rotation = config.ScreenRotation
	screen.BackgroundColor3 = config.ScreenColor
	screen.BorderSizePixel = 0
	screen.Parent = gui
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 0.4)
	text.Position = UDim2.fromScale(0, 0.12)
	text.BackgroundTransparency = 1
	text.TextColor3 = config.TextColor
	text.TextScaled = true
	text.Font = Enum.Font.Code
	text.Text = ""
	text.Parent = screen
	local track = Instance.new("Frame")
	track.Size = UDim2.fromScale(0.8, 0.12)
	track.Position = UDim2.fromScale(0.1, 0.65)
	track.BackgroundColor3 = Color3.new(0, 0, 0)
	track.BorderSizePixel = 0
	track.Parent = screen
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = config.BarColor
	fill.BorderSizePixel = 0
	fill.Parent = track
	caption, bar = text, fill
	return part
end

local function render()
	local part, camera = watch, workspace.CurrentCamera
	if not (part and camera) then
		return
	end
	if raised <= 0.001 then
		part.Parent = nil
		return
	end
	part.Parent = camera
	-- On the back of the wrist, face to the camera, its top edge toward the top of the screen so the words read the right way up.
	local hand = camera.CFrame * handAt(raised)
	local face = hand * CFrame.new(config.WatchOnHand)
	local normal = hand.ZVector -- the back of the hand
	local up = Vector3.yAxis - normal * normal:Dot(Vector3.yAxis)
	if up.Magnitude < 1e-3 then
		up = camera.CFrame.UpVector
	end
	up = up.Unit
	part.CFrame = CFrame.fromMatrix(face.Position, normal:Cross(-up), normal, -up)
	local fill = bar
	if fill then
		local progress = if active and seconds > 0 then math.clamp((os.clock() - startedAt) / seconds, 0, 1) else 1
		fill.Size = UDim2.fromScale(progress, 1)
	end
end

local function move(target: number)
	if raiseTween then
		raiseTween:Cancel()
	end
	lifted.Value = raised
	raiseTween = TweenService:Create(lifted, TweenInfo.new(config.RaiseSeconds), { Value = target });
	(raiseTween :: Tween):Play()
end

local function onState(info: Types.WristWatchInfo)
	if info.Active then
		active, startedAt, seconds = true, os.clock(), info.Seconds
		local label = (config.Labels :: { [string]: string })[info.Kind]
		if caption then
			caption.Text = label or ""
		end
		move(1)
	else
		active = false
		move(0)
	end
end

function WristWatchController.Init() end

function WristWatchController.Start()
	watch = build()
	janitor:Add(lifted:GetPropertyChangedSignal("Value"):Connect(function()
		raised = lifted.Value
	end))
	janitor:Add(RemoteController.connect("WristWatchState", onState))
	janitor:Add(Players.LocalPlayer.CharacterRemoving:Connect(function()
		active = false
		raised = 0
		lifted.Value = 0
	end))
	RunService:BindToRenderStep(BIND, Enum.RenderPriority.Camera.Value + 4, render)
	janitor:Add(function()
		RunService:UnbindFromRenderStep(BIND)
		if watch then
			watch:Destroy()
		end
	end)
	janitor:Add(script.Destroying:Connect(function()
		janitor:Destroy()
	end))
end

return WristWatchController
