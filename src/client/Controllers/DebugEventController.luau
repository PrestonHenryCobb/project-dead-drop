--!strict
-- Development only (removed in Step 8, when real combat exists): the J, K and L keys ask the server for a gunshot, a
-- blast or a downed NPC where the mouse points, so NPC reactions can be tried. The server decides whether to act.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local RemoteController = require(script.Parent.RemoteController)

local DebugEventController = {}

local AIM_RANGE = 300 -- studs

local function aimedPoint(): Vector3?
	local camera = workspace.CurrentCamera
	if not camera then
		return nil
	end
	local mouse = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
	local params = RaycastParams.new()
	params.CollisionGroup = GameConfig.Rig.CollisionGroup -- aim through characters, at the map
	local hit = workspace:Raycast(ray.Origin, ray.Direction * AIM_RANGE, params)
	return if hit then hit.Position else nil
end

function DebugEventController.Init() end

function DebugEventController.Start()
	if not (GameConfig.Debug.TestEvents and RunService:IsStudio()) then
		return
	end
	local kinds: { [Enum.KeyCode]: string } = {
		[GameConfig.Debug.TestKeys.Gunshot] = "Gunshot",
		[GameConfig.Debug.TestKeys.Explosion] = "Explosion",
		[GameConfig.Debug.TestKeys.Body] = "Body",
	}
	UserInputService.InputBegan:Connect(function(input, processed)
		local kind = kinds[input.KeyCode]
		if processed or not kind or not Players.LocalPlayer.Character then
			return
		end
		local point = aimedPoint()
		if point then
			RemoteController.fire("RequestDebugEvent", kind, point)
		end
	end)
end

return DebugEventController
