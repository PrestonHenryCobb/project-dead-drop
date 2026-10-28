--!strict
-- Spring Pad (docs/GADGETS_DRAFT.md, Evasion): a flat pad set down ahead of the user. A player who steps on it (the user, a
-- teammate or an enemy alike) is thrown LaunchHeight studs up and ForwardSpeed forward along the pad's facing, and is exposed:
-- being thrown breaks Cover. It goes after Seconds, after MaxLaunches throwings, when a shot hits it, or when the user recalls it
-- (the aim button); a recalled pad is gone and its charge is not given back. Setting it down is Discreet. Nothing on the pad
-- says whose it is.
--
-- The throw is the player's own physics, so the server only tells them the velocity to take (Launch) and exposes them.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local Shields = require(script.Parent.Parent.Combat.Shields)
local CoverService = require(script.Parent.Parent.Services.CoverService)
local DownedService = require(script.Parent.Parent.Services.DownedService)
local MatchService = require(script.Parent.Parent.Services.MatchService)
local RemoteService = require(script.Parent.Parent.Services.RemoteService)
local TeamService = require(script.Parent.Parent.Services.TeamService)
local Gadget = require(script.Parent.Gadget)
local Spot = require(script.Parent.Spot)

type Pad = {
	shield: Shields.Shield,
	owner: Player,
	facing: Vector3,
	endsAt: number,
	launches: number,
	jammedUntil: number, -- a Jammer holds it down until then
}

local config = GameConfig.Gadgets.SpringPad
local pads: { Pad } = {}
local lastLaunch: { [Player]: number } = {}

local function forget(pad: Pad)
	Shields.destroy(pad.shield)
	local index = table.find(pads, pad)
	if index then
		table.remove(pads, index)
	end
end

-- Is the body on the pad: inside its footprint and not more than StepHeight above its top?
local function onPad(pad: Pad, position: Vector3): boolean
	local offset = pad.shield.part.CFrame:PointToObjectSpace(position)
	return math.abs(offset.X) <= config.Size.X / 2
		and math.abs(offset.Z) <= config.Size.Z / 2
		and offset.Y >= 0
		and offset.Y <= config.StepHeight + config.Size.Y / 2
end

local function launch(player: Player, pad: Pad)
	-- v = sqrt(2 g h): the speed that carries a body LaunchHeight studs up under the world's gravity.
	local up = math.sqrt(2 * workspace.Gravity * config.LaunchHeight)
	RemoteService.fireClient("Launch", player, pad.facing * config.ForwardSpeed + Vector3.new(0, up, 0))
	CoverService.expose(player, "SpringPad")
	lastLaunch[player] = os.clock()
	pad.launches += 1
end

local function step()
	local now = os.clock()
	for _, pad in table.clone(pads) do
		if now >= pad.endsAt or pad.launches >= config.MaxLaunches or not MatchService.isInMatch() then
			forget(pad)
		else
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if
					humanoid
					and humanoid.Health > 0
					and root
					and root:IsA("BasePart")
					and not DownedService.isOut(player)
					and now - (lastLaunch[player] or -math.huge) >= config.ReLaunchSeconds
					and pad.launches < config.MaxLaunches
					and now >= pad.jammedUntil
					and onPad(pad, root.Position)
				then
					launch(player, pad)
				end
			end
		end
	end
end

local SpringPad: Gadget.Gadget = {
	deploy = function(player: Player): (boolean, string?)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not (root and root:IsA("BasePart")) or DownedService.isOut(player) then
			return false, nil
		end
		CoverService.useDiscreetly(player, "SpringPad")
		local at, facing = Spot.ahead(root, config.Ahead, config.FloorProbe.Up, config.FloorProbe.Down)
		local part = Instance.new("Part")
		part.Name = "Pad"
		part.Size = config.Size
		part.Color = config.Color
		part.Material = config.Material
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CastShadow = false
		part.CFrame =
			CFrame.lookAt(at + Vector3.new(0, config.Size.Y / 2, 0), at + Vector3.new(0, config.Size.Y / 2, 0) + facing)
		local shield = Shields.adopt(player, part, config.HP, function()
			for _, pad in table.clone(pads) do
				if pad.shield.part == part then
					forget(pad) -- shot
				end
			end
		end)
		table.insert(pads, {
			shield = shield,
			owner = player,
			facing = facing,
			endsAt = os.clock() + config.Seconds,
			launches = 0,
			jammedUntil = 0,
		})
		return true, nil
	end,

	-- A Jammer stops other teams' pads from throwing anyone while it holds them.
	jamAt = function(position: Vector3, radius: number, jammer: Player, seconds: number)
		for _, pad in pads do
			if
				pad.owner ~= jammer
				and not TeamService.areTeammates(jammer, pad.owner)
				and (pad.shield.part.Position - position).Magnitude <= radius
			then
				pad.jammedUntil = os.clock() + seconds
			end
		end
	end,

	-- The aim button recalls the user's pads.
	alternate = function(player: Player)
		for _, pad in table.clone(pads) do
			if pad.owner == player then
				forget(pad)
			end
		end
	end,

	start = function()
		local interval = 1 / config.CheckHz
		local elapsed = 0
		RunService.Heartbeat:Connect(function(dt)
			elapsed += dt
			if elapsed >= interval then
				elapsed = 0
				if #pads > 0 then
					step()
				end
			end
		end)
		Players.PlayerRemoving:Connect(function(player)
			lastLaunch[player] = nil
		end)
	end,
}

return SpringPad
