--!strict
-- Agent Sense on the client (spec 8.3, STEP7_QUESTIONS G1 and G2).
--
--   Whatever character is under the crosshair within Agent Sense range is reported to the server, which decides if it
--   is an enemy agent. If so the server answers with a shimmer: a faint white outline on that character for a second.
--   When an Exposed enemy is close, the server sends their position and this draws a very faint red glow on the side
--   of the screen they are on, unless the player is already looking at them.
--
-- This client never knows who is a player: it only draws what the server sends.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Aim = require(Shared:WaitForChild("Util"):WaitForChild("Aim"))
local HudKit = require(Shared:WaitForChild("Util"):WaitForChild("HudKit"))
local Janitor = require(Shared.Util.Janitor)
local AgentSenseFx = require(script.Parent.Parent.Combat.AgentSenseFx)
local RemoteController = require(script.Parent.RemoteController)

local AgentSenseController = {}

local ui = GameConfig.UI

local reportedTarget: string? = nil
local nearExposed: { Vector3 } = {}
local glow: HudKit.EdgeGlow? = nil
local effects: AgentSenseFx.Effect? = nil
local janitor = Janitor.new()
local active = true

local function shimmer(id: string, seconds: number)
	local model = workspace:FindFirstChild(id)
	if not model or not model:IsA("Model") or not effects then
		return
	end
	effects:show(model, seconds, os.clock())
end

-- Which side of the screen a world position is on, or nil if the player is already looking at it.
local function sideOf(position: Vector3, camera: Camera): string?
	local offset = position - camera.CFrame.Position
	if offset.Magnitude < 1e-3 then
		return nil
	end
	if camera.CFrame.LookVector:Dot(offset.Unit) > ui.SenseLookCosine then
		return nil
	end
	local relative = camera.CFrame:PointToObjectSpace(position)
	if math.abs(relative.X) > math.abs(relative.Z) then
		return if relative.X > 0 then "Right" else "Left"
	end
	return if relative.Z > 0 then "Bottom" else "Top"
end

function AgentSenseController.Init() end

function AgentSenseController.Start()
	local screen = HudKit.screen("AgentSenseHud")
	janitor:Add(screen)
	local pool = AgentSenseFx.new()
	effects = pool
	janitor:Add(function()
		pool:destroy()
	end)
	glow = HudKit.edgeGlow(screen, ui.CoverColors.Exposed)

	janitor:Add(
		RemoteController.connect(
			"AgentSense",
			function(info: { Kind: string, Id: string?, Seconds: number?, Positions: { Vector3 }? })
				if not active then
					return
				end
				if info.Kind == "Shimmer" and info.Id then
					shimmer(info.Id, info.Seconds or GameConfig.Cover.AgentSenseShimmerSeconds)
				elseif info.Kind == "Near" then
					nearExposed = info.Positions or {}
				end
			end
		)
	)
	local function reset()
		reportedTarget = nil
		table.clear(nearExposed)
		pool:reset()
		if glow then
			glow.setAll(1)
		end
	end
	janitor:Add(RemoteController.connect("Downed", function()
		active = false
		reset()
	end))
	janitor:Add(RemoteController.connect("Eliminated", function()
		active = false
		reset()
	end))
	janitor:Add(RemoteController.connect("Revived", function()
		active = true
	end))
	janitor:Add(Players.LocalPlayer.CharacterAdded:Connect(function()
		active = true
		reset()
	end))

	janitor:Add(RunService.RenderStepped:Connect(function()
		pool:update(os.clock())
		if not active then
			return
		end
		-- Tell the server what we are looking at, whenever it changes.
		local target = Aim.characterName(GameConfig.Cover.AgentSenseRange)
		if target ~= reportedTarget then
			reportedTarget = target
			RemoteController.fire("RequestSense", target)
		end

		local edge = glow
		local camera = workspace.CurrentCamera
		if not (edge and camera) then
			return
		end
		edge.setAll(1)
		for _, position in nearExposed do
			local side = sideOf(position, camera)
			if side then
				edge.setSide(side, ui.SenseGlowTransparency)
			end
		end
	end))
	janitor:Add(script.Destroying:Connect(function()
		janitor:Destroy()
	end))
end

return AgentSenseController
