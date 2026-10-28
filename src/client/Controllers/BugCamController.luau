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

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Janitor = require(Shared:WaitForChild("Util"):WaitForChild("Janitor"))
local Types = require(Shared:WaitForChild("Types"))
local RemoteController = require(script.Parent.RemoteController)

local BugCamController = {}

local ACTION = "CoverStoryBugCam"
local STEP_NAME = "CoverStoryBugCamView"

local cams: { CFrame } = {}
local index = 0 -- the cam being looked through, 0 for your own eyes

function BugCamController.viewing(): boolean
	return index > 0
end

local function stop()
	if index == 0 then
		return
	end
	index = 0
	RunService:UnbindFromRenderStep(STEP_NAME)
	local camera = workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Custom
	end
end

local function step()
	local camera = workspace.CurrentCamera
	local view = cams[index]
	if not (camera and view) then
		stop()
		return
	end
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = view
end

local function onKey(_: string, state: Enum.UserInputState): Enum.ContextActionResult
	if state ~= Enum.UserInputState.Begin or UserInputService:GetFocusedTextBox() ~= nil then
		return Enum.ContextActionResult.Pass
	end
	if index >= #cams then
		stop()
		return Enum.ContextActionResult.Pass
	end
	if index == 0 then
		RunService:BindToRenderStep(STEP_NAME, Enum.RenderPriority.Camera.Value + 2, step)
	end
	index += 1
	return Enum.ContextActionResult.Pass
end

function BugCamController.Init() end

function BugCamController.Start()
	local janitor = Janitor.new()
	ContextActionService:BindAction(ACTION, onKey, false, GameConfig.Controls.BugCam)
	janitor:Add(function()
		ContextActionService:UnbindAction(ACTION)
		stop()
	end)
	janitor:Add(RemoteController.connect("BugCamState", function(info: Types.BugCamStateInfo)
		cams = info.Cams
		if index > #cams then
			stop()
		end
	end))
	janitor:Add(script.Destroying:Connect(function()
		janitor:Destroy()
	end))
end

return BugCamController
