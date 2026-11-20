--!strict
-- Ticket 17d: viewing the Bug Cams you have stuck up (docs/GADGETS_DRAFT.md). The server says where they are (BugCamState, to you
-- only); Controls.BugCam looks through the first, then the next, and a press after the last returns to your own eyes. The view
-- is only a view: your body still stands where it was, so it is as exposed as ever. Tagging what the cams see is the server's.
--
--   BugCamController.viewing() -> boolean

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local InputHints = require(Shared:WaitForChild("Util"):WaitForChild("InputHints"))
local Janitor = require(Shared:WaitForChild("Util"):WaitForChild("Janitor"))
local Types = require(Shared:WaitForChild("Types"))
local RemoteController = require(script.Parent.RemoteController)
local HeldItemController = require(script.Parent.HeldItemController)
local CameraGuard = require(script.Parent.Parent.Combat.CameraGuard)
local HudKit = require(Shared.Util.HudKit)
local HudTheme = require(Shared.Util.HudTheme)

local BugCamController = {}

local ACTION = "CoverStoryBugCam"
local STEP_NAME = "CoverStoryBugCamView"

local cams: { CFrame } = {}
local index = 0 -- the cam being looked through, 0 for your own eyes
local savedMouse = Enum.MouseBehavior.Default
local phase: Types.Phase? = nil
local exitButton: TextButton? = nil

function BugCamController.viewing(): boolean
	return index > 0
end

local function stop()
	if index == 0 then
		return
	end
	index = 0
	RunService:UnbindFromRenderStep(STEP_NAME)
	HeldItemController.setInterfaceBlocked(script, false)
	CameraGuard.setRemoteView(script, false)
	UserInputService.MouseBehavior = savedMouse
	CameraGuard.restoreGameplay()
	if exitButton then
		exitButton.Visible = false
	end
end

local function step()
	local camera = workspace.CurrentCamera
	local view = cams[index]
	if not (camera and view) or not HeldItemController.canAct(script) or CameraGuard.menuOpen() then
		stop()
		return
	end
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = view
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	if exitButton then
		exitButton.Visible = true
		exitButton.Text =
			`BUG CAM {index}/{#cams} · {InputHints.bracket(GameConfig.Controls.BugCam, nil, "NEXT / EXIT")}`
	end
end

local function onKey(_: string, state: Enum.UserInputState): Enum.ContextActionResult
	if state ~= Enum.UserInputState.Begin or not HeldItemController.canAct(script) then
		return Enum.ContextActionResult.Pass
	end
	if index >= #cams then
		stop()
		return Enum.ContextActionResult.Pass
	end
	if index == 0 then
		savedMouse = UserInputService.MouseBehavior
		HeldItemController.setInterfaceBlocked(script, true, true)
		CameraGuard.setRemoteView(script, true)
		RunService:BindToRenderStep(STEP_NAME, Enum.RenderPriority.Camera.Value + 2, step)
	end
	index += 1
	return Enum.ContextActionResult.Pass
end

function BugCamController.Init() end

function BugCamController.Start()
	local janitor = Janitor.new()
	local theme = HudTheme.get()
	local gui = HudKit.screen("BugCamView")
	janitor:Add(gui)
	local button = Instance.new("TextButton")
	button.Name = "NextOrExitBugCam"
	button.AnchorPoint = Vector2.new(0.5, 1)
	button.Position = UDim2.new(0.5, 0, 1, -theme.MarginPixels)
	button.Size = UDim2.fromOffset(theme.ActionWidthPixels, theme.ActionHeightPixels)
	button.BackgroundColor3 = theme.PanelColor
	button.BackgroundTransparency = theme.PanelTransparency
	button.Font = theme.Font
	button.TextSize = theme.CaptionSize
	button.TextColor3 = theme.TextColor
	button.TextWrapped = true
	button.Modal = true
	button.Visible = false
	button.Parent = gui
	exitButton = button
	janitor:Add(button.Activated:Connect(function()
		onKey(ACTION, Enum.UserInputState.Begin)
	end))
	ContextActionService:BindAction(ACTION, onKey, false, GameConfig.Controls.BugCam)
	janitor:Add(function()
		ContextActionService:UnbindAction(ACTION)
		stop()
	end)
	janitor:Add(RemoteController.connect("BugCamState", function(info: Types.BugCamStateInfo)
		cams = if phase == "Lobby" or phase == "Insertion" or phase == "Results" then {} else info.Cams
		if index > #cams then
			stop()
		end
	end))
	janitor:Add(RemoteController.connect("PhaseChanged", function(value: Types.Phase)
		phase = value
		if value == "Lobby" or value == "Insertion" or value == "Results" then
			cams = {}
			stop()
		end
	end))
	janitor:Add(RemoteController.connect("Downed", stop))
	janitor:Add(RemoteController.connect("Eliminated", stop))
	janitor:Add(RemoteController.connect("SparrowState", function(info: Types.SparrowStateInfo)
		if info.Active then
			stop()
		end
	end))
	janitor:Add(Players.LocalPlayer.CharacterRemoving:Connect(stop))
	janitor:Add(script.Destroying:Connect(function()
		janitor:Destroy()
	end))
end

return BugCamController
