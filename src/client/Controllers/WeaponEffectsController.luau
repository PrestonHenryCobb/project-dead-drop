--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Janitor = require(Shared.Util.Janitor)
local Types = require(Shared.Types)
local RemoteController = require(script.Parent.RemoteController)
local Effects = require(script.Parent.Parent.Combat.WeaponEffects)
local WeaponEffectsController = {}
local janitor = Janitor.new()

function WeaponEffectsController.Init() end

function WeaponEffectsController.Start()
	Effects.start(janitor)
	janitor:Add(RemoteController.connect("ProjectileLaunched", Effects.launched))
	janitor:Add(RemoteController.connect("ProjectileImpact", Effects.impact))
	janitor:Add(RemoteController.connect("TargetGlow", Effects.glow))
	janitor:Add(RemoteController.connect("SmokeCloud", Effects.smoke))
	janitor:Add(RemoteController.connect("PhaseChanged", function(phase: Types.Phase)
		if phase == "Lobby" or phase == "Insertion" then
			Effects.clear()
		end
	end))
	janitor:Add(RunService.RenderStepped:Connect(Effects.step))
	janitor:Add(script.Destroying:Connect(function()
		janitor:Destroy()
	end))
end

return WeaponEffectsController
