--!strict
-- Noise Maker (docs/GADGETS_DRAFT.md, Evasion): put down ahead of the user; ArmSeconds later it sounds a loud alarm-like noise
-- for Seconds. Guards within InvestigateStuds walk over to look; other NPCs near it turn to face it. Nothing on it says whose it
-- is, and it points nowhere but to itself. A shot that hits it destroys it. Discreet.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local Shields = require(script.Parent.Parent.Combat.Shields)
local CoverService = require(script.Parent.Parent.Services.CoverService)
local DownedService = require(script.Parent.Parent.Services.DownedService)
local NPCService = require(script.Parent.Parent.Services.NPCService)
local Gadget = require(script.Parent.Gadget)
local Spot = require(script.Parent.Spot)

local config = GameConfig.Gadgets.NoiseMaker

local NoiseMaker: Gadget.Gadget = {
	deploy = function(player: Player): (boolean, string?)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not (root and root:IsA("BasePart")) or DownedService.isOut(player) then
			return false, nil
		end
		CoverService.useDiscreetly(player, "NoiseMaker")
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
		task.delay(config.ArmSeconds, function()
			if not Shields.isUp(shield) then
				return
			end
			local sound = Instance.new("Sound")
			sound.SoundId = config.SoundId
			sound.Volume = config.Volume
			sound.RollOffMaxDistance = config.RollOffMaxStuds
			sound.Looped = true
			sound.Parent = part
			sound:Play()
			NPCService.noise(part.Position, config.InvestigateStuds)
			task.delay(config.Seconds, function()
				Shields.destroy(shield)
			end)
		end)
		return true, nil
	end,
}

return NoiseMaker
