--!strict
-- Suture's ability and passive (spec 15.5). Triage: teammates near him regain health once they have been out of combat a while
-- (the loop in start()), and his revives take half the time (AbilityService, InteractService). Mend Field: a first-aid kit set
-- down ahead of him that heals his team, himself included, for a few seconds. Looking like an ordinary first-aid kit, it is
-- no giveaway in a public zone; in a Tier 1+ zone setting it down breaks his Cover.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local CombatService = require(script.Parent.Parent.Services.CombatService)
local CoverService = require(script.Parent.Parent.Services.CoverService)
local DownedService = require(script.Parent.Parent.Services.DownedService)
local MatchService = require(script.Parent.Parent.Services.MatchService)
local TeamService = require(script.Parent.Parent.Services.TeamService)
local ZoneService = require(script.Parent.Parent.Services.ZoneService)
local Spot = require(script.Parent.Parent.Gadgets.Spot)
local Ability = require(script.Parent.Ability)

local mend = GameConfig.Agents.Suture.MendField
local triage = GameConfig.Agents.Suture.Triage

local folder: Folder? = nil

local function bodyOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") and not DownedService.isOut(player) then
		return root
	end
	return nil
end

-- A white box with a red cross: what a first-aid kit looks like to everyone, whoever put it there.
local function makeKit(at: Vector3): Model
	local kit = Instance.new("Model")
	kit.Name = "FirstAidKit"
	local box = Instance.new("Part")
	box.Name = "Box"
	box.Size = mend.KitSize
	box.Color = mend.KitColor
	box.Material = Enum.Material.SmoothPlastic
	box.Anchored = true
	box.CanCollide = false
	box.CanTouch = false
	box.CanQuery = false
	box.CFrame = CFrame.new(at + Vector3.new(0, mend.KitSize.Y / 2, 0))
	box.Parent = kit
	local topY = mend.KitSize.Y / 2 + 0.02
	local bar = math.min(mend.KitSize.X, mend.KitSize.Z) * 0.6
	for _, size in { Vector3.new(bar, 0.04, bar / 3), Vector3.new(bar / 3, 0.04, bar) } do
		local arm = Instance.new("Part")
		arm.Name = "Cross"
		arm.Size = size
		arm.Color = mend.CrossColor
		arm.Material = Enum.Material.SmoothPlastic
		arm.Anchored = true
		arm.CanCollide = false
		arm.CanTouch = false
		arm.CanQuery = false
		arm.CFrame = box.CFrame * CFrame.new(0, topY, 0)
		arm.Parent = kit
	end
	kit.PrimaryPart = box
	if not folder then
		local made = Instance.new("Folder")
		made.Name = "FieldKits"
		made.Parent = workspace
		folder = made
	end
	kit.Parent = folder
	return kit
end

local function healField(owner: Player, at: Vector3, kit: Model)
	local ownerTeam = TeamService.teamOf(owner)
	local endsAt = os.clock() + mend.Seconds
	local interval = 1 / mend.HealHz
	while os.clock() < endsAt and MatchService.isInMatch() do
		task.wait(interval)
		for _, player in Players:GetPlayers() do
			local root = bodyOf(player)
			if
				root
				and (root.Position - at).Magnitude <= mend.Radius
				and (player == owner or (ownerTeam ~= nil and TeamService.teamOf(player) == ownerTeam))
			then
				CombatService.heal(player, mend.HealPerSecond * interval)
			end
		end
	end
	kit:Destroy()
end

local Suture: Ability.Ability = {
	activate = function(player: Player): (boolean, string?)
		local root = bodyOf(player)
		if not root or not MatchService.isInMatch() then
			return false, nil
		end
		if ZoneService.tierAt(root.Position) >= 1 then
			CoverService.expose(player, "MendField")
		end
		local at = Spot.ahead(root, mend.Ahead, mend.FloorProbe.Up, mend.FloorProbe.Down)
		local kit = makeKit(at)
		task.spawn(healField, player, at, kit)
		return true, nil
	end,

	-- Triage: teammates (not himself) within Radius regain PerSecond once they have been out of combat OutOfCombatSeconds.
	start = function(agentOf: (Player) -> string?)
		local interval = 1 / triage.TickHz
		local elapsed = 0
		RunService.Heartbeat:Connect(function(dt)
			elapsed += dt
			if elapsed < interval then
				return
			end
			elapsed = 0
			if not MatchService.isInMatch() then
				return
			end
			for _, medic in Players:GetPlayers() do
				local medicRoot = if agentOf(medic) == "Suture" then bodyOf(medic) else nil
				local teamId = if medicRoot then TeamService.teamOf(medic) else nil
				if medicRoot and teamId then
					for _, mate in Players:GetPlayers() do
						local root = if mate ~= medic and TeamService.teamOf(mate) == teamId then bodyOf(mate) else nil
						if
							root
							and (root.Position - medicRoot.Position).Magnitude <= triage.Radius
							and CombatService.secondsSinceDamaged(mate) >= triage.OutOfCombatSeconds
						then
							CombatService.heal(mate, triage.PerSecond * interval)
						end
					end
				end
			end
		end)
	end,
}

return Suture
