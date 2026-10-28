--!strict
-- Tripwire (docs/GADGETS_DRAFT.md, Recon): a thin red beam set across the way ahead of the user, wall to wall, for Seconds. An
-- enemy agent who crosses it glows for the user's team for PingSeconds and is slowed; only the one who crossed is shown, never the
-- owner. NPCs and teammates pass. A shot that hits the beam destroys it, and the aim button recalls the user's wires. Discreet.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Types = require(Shared:WaitForChild("Types"))
local History = require(script.Parent.Parent.Combat.History)
local Shields = require(script.Parent.Parent.Combat.Shields)
local CoverService = require(script.Parent.Parent.Services.CoverService)
local DisguiseService = require(script.Parent.Parent.Services.DisguiseService)
local DownedService = require(script.Parent.Parent.Services.DownedService)
local MatchService = require(script.Parent.Parent.Services.MatchService)
local RemoteService = require(script.Parent.Parent.Services.RemoteService)
local TeamService = require(script.Parent.Parent.Services.TeamService)
local Gadget = require(script.Parent.Gadget)
local Spot = require(script.Parent.Spot)

type Wire = {
	shield: Shields.Shield,
	owner: Player,
	from: Vector3,
	to: Vector3,
	endsAt: number,
	jammedUntil: number,
	lastTriggered: { [Player]: number },
}

local config = GameConfig.Gadgets.Tripwire
local wires: { Wire } = {}

local function forget(wire: Wire)
	Shields.destroy(wire.shield)
	local index = table.find(wires, wire)
	if index then
		table.remove(wires, index)
	end
end

-- How far a point is from the wire's segment.
local function distanceTo(wire: Wire, point: Vector3): number
	local line = wire.to - wire.from
	local along = math.clamp((point - wire.from):Dot(line) / line:Dot(line), 0, 1)
	return (wire.from + line * along - point).Magnitude
end

local function step()
	local now = os.clock()
	for _, wire in table.clone(wires) do
		if now >= wire.endsAt or not MatchService.isInMatch() then
			forget(wire)
		elseif now >= wire.jammedUntil then
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if
					humanoid
					and humanoid.Health > 0
					and root
					and root:IsA("BasePart")
					and player ~= wire.owner
					and not TeamService.areTeammates(wire.owner, player)
					and not DownedService.isOut(player)
					and now - (wire.lastTriggered[player] or -math.huge) >= config.RetriggerSeconds
					and distanceTo(wire, root.Position) <= config.HitStuds
				then
					wire.lastTriggered[player] = now
					DisguiseService.applySlow(player, config.SlowMult, config.SlowSeconds)
					local teamId = TeamService.teamOf(wire.owner)
					local recipients = if teamId then TeamService.members(teamId) else { wire.owner }
					for _, target in History.targets do
						if target.player == player then
							local glow: Types.TargetGlowInfo =
								{ TargetId = target.id, ExpiresAt = workspace:GetServerTimeNow() + config.PingSeconds }
							RemoteService.fireClients("TargetGlow", recipients, glow)
						end
					end
				end
			end
		end
	end
end

local Tripwire: Gadget.Gadget = {
	deploy = function(player: Player): (boolean, string?)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not (root and root:IsA("BasePart")) or DownedService.isOut(player) then
			return false, nil
		end
		local floor, facing = Spot.ahead(root, config.Ahead, config.FloorProbe.Up, config.FloorProbe.Down)
		local middle = floor + Vector3.new(0, config.Height, 0)
		local side = facing:Cross(Vector3.yAxis)
		local from = Spot.reachAlong(middle, -side, config.HalfWidthStuds)
		local to = Spot.reachAlong(middle, side, config.HalfWidthStuds)
		if (to - from).Magnitude < config.MinLengthStuds then
			return false, "No room for a tripwire here"
		end
		CoverService.useDiscreetly(player, "Tripwire")
		local part = Instance.new("Part")
		part.Name = "Beam"
		part.Size = Vector3.new(config.Thickness, config.Thickness, (to - from).Magnitude)
		part.Color = config.Color
		part.Material = Enum.Material.Neon
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CastShadow = false
		part.CFrame = CFrame.lookAt((from + to) / 2, to)
		local wire: Wire?
		local shield = Shields.adopt(player, part, config.HP, function()
			if wire then
				forget(wire) -- shot
			end
		end)
		wire = {
			shield = shield,
			owner = player,
			from = from,
			to = to,
			endsAt = os.clock() + config.Seconds,
			jammedUntil = 0,
			lastTriggered = {},
		}
		table.insert(wires, wire :: Wire)
		return true, nil
	end,

	-- The aim button recalls the user's wires.
	alternate = function(player: Player)
		for _, wire in table.clone(wires) do
			if wire.owner == player then
				forget(wire)
			end
		end
	end,

	-- A Jammer stops other teams' wires from seeing anyone while it holds them.
	jamAt = function(position: Vector3, radius: number, jammer: Player, seconds: number)
		for _, wire in wires do
			if
				wire.owner ~= jammer
				and not TeamService.areTeammates(jammer, wire.owner)
				and (wire.shield.part.Position - position).Magnitude <= radius
			then
				wire.jammedUntil = os.clock() + seconds
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
				if #wires > 0 then
					step()
				end
			end
		end)
	end,
}

return Tripwire
