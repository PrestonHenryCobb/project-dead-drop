--!strict
-- Jammer (docs/GADGETS_DRAFT.md, Infiltration): a device set down ahead of the user. For Seconds, while it stands, cameras and
-- laser grids within RadiusStuds go dark, other teams' Spring Pads and Tripwires there stop working and their Noise Makers and
-- Bug Cams there are destroyed.
-- Every CheckSeconds it holds them down for HoldSeconds more, so a Jammer that is shot (one hit) frees them at once. Discreet.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local Shields = require(script.Parent.Parent.Combat.Shields)
local CameraService = require(script.Parent.Parent.Services.CameraService)
local CoverService = require(script.Parent.Parent.Services.CoverService)
local DownedService = require(script.Parent.Parent.Services.DownedService)
local LaserService = require(script.Parent.Parent.Services.LaserService)
local MatchService = require(script.Parent.Parent.Services.MatchService)
local BugCam = require(script.Parent.BugCam)
local Gadget = require(script.Parent.Gadget)
local NoiseMaker = require(script.Parent.NoiseMaker)
local Spot = require(script.Parent.Spot)
local SpringPad = require(script.Parent.SpringPad)
local Tripwire = require(script.Parent.Tripwire)

local config = GameConfig.Gadgets.Jammer

local Jammer: Gadget.Gadget = {
	deploy = function(player: Player): (boolean, string?)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not (root and root:IsA("BasePart")) or DownedService.isOut(player) then
			return false, nil
		end
		CoverService.useDiscreetly(player, "Jammer")
		local at = Spot.ahead(root, config.Ahead, config.FloorProbe.Up, config.FloorProbe.Down)
		local part = Instance.new("Part")
		part.Name = "Device"
		part.Size = config.Size
		part.Color = config.Color
		part.Material = Enum.Material.Metal
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CastShadow = false
		part.Position = at + Vector3.new(0, config.Size.Y / 2, 0)
		local shield = Shields.adopt(player, part, config.HP, nil)
		local endsAt = os.clock() + config.Seconds
		task.spawn(function()
			while Shields.isUp(shield) and os.clock() < endsAt and MatchService.isInMatch() do
				local position = part.Position
				CameraService.jamAt(position, config.RadiusStuds, config.HoldSeconds)
				LaserService.jamAt(position, config.RadiusStuds, config.HoldSeconds)
				for _, deployable in { SpringPad, NoiseMaker, Tripwire, BugCam } do
					if deployable.jamAt then
						deployable.jamAt(position, config.RadiusStuds, player, config.HoldSeconds)
					end
				end
				task.wait(config.CheckSeconds)
			end
			Shields.destroy(shield)
		end)
		return true, nil
	end,
}

return Jammer
