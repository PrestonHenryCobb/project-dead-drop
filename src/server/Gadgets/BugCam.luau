--!strict
-- Bug Cam (docs/GADGETS_DRAFT.md, Recon): a small camera stuck to the surface the user aims at within ReachStuds. For Seconds it
-- watches a cone of FovDegrees out to RangeStuds; an enemy agent who breaks Cover there, with a clear line to the cam, glows for the
-- user's team for TagSeconds. The user views their cams with a key (the client is told where they are: BugCamState, to them only).
-- A shot that hits one destroys it. Discreet.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Types = require(Shared:WaitForChild("Types"))
local History = require(script.Parent.Parent.Combat.History)
local Shields = require(script.Parent.Parent.Combat.Shields)
local CoverService = require(script.Parent.Parent.Services.CoverService)
local DownedService = require(script.Parent.Parent.Services.DownedService)
local RemoteService = require(script.Parent.Parent.Services.RemoteService)
local TeamService = require(script.Parent.Parent.Services.TeamService)
local Gadget = require(script.Parent.Gadget)
local Spot = require(script.Parent.Spot)

type Cam = { shield: Shields.Shield, owner: Player, view: CFrame }

local config = GameConfig.Gadgets.BugCam
local HALF_FOV_COS = math.cos(math.rad(config.FovDegrees / 2))
local cams: { Cam } = {}

-- Rays in the character group meet only the map.
local sight = RaycastParams.new()
sight.CollisionGroup = GameConfig.Rig.CollisionGroup
sight.RespectCanCollide = true

-- Tells the owner where their cams are.
local function sendList(owner: Player)
	local info: Types.BugCamStateInfo = { Cams = {} }
	for _, cam in cams do
		if cam.owner == owner then
			table.insert(info.Cams, cam.view)
		end
	end
	RemoteService.fireClient("BugCamState", owner, info)
end

local function forget(cam: Cam)
	Shields.destroy(cam.shield)
	local index = table.find(cams, cam)
	if index then
		table.remove(cams, index)
		sendList(cam.owner)
	end
end

-- Someone broke Cover: every cam that can see it tags them for its owner's team.
local function onExposed(player: Player, position: Vector3)
	local target: History.Target? = nil
	for _, candidate in History.targets do
		if candidate.player == player then
			target = candidate
		end
	end
	if not target then
		return
	end
	for _, cam in cams do
		local eye = cam.shield.part.Position
		local offset = position - eye
		if
			cam.owner ~= player
			and not TeamService.areTeammates(cam.owner, player)
			and offset.Magnitude <= config.RangeStuds
			and offset.Magnitude > 0
			and offset.Unit:Dot(cam.view.LookVector) >= HALF_FOV_COS
			and workspace:Raycast(eye, offset, sight) == nil
		then
			local teamId = TeamService.teamOf(cam.owner)
			local recipients = if teamId then TeamService.members(teamId) else { cam.owner }
			local glow: Types.TargetGlowInfo =
				{ TargetId = target.id, ExpiresAt = workspace:GetServerTimeNow() + config.TagSeconds }
			RemoteService.fireClients("TargetGlow", recipients, glow)
		end
	end
end

local BugCam: Gadget.Gadget = {
	deploy = function(player: Player, _: { [string]: any }, aim: Vector3?): (boolean, string?)
		local character = player.Character
		local head = character and character:FindFirstChild("Head")
		if not (head and head:IsA("BasePart") and aim) or DownedService.isOut(player) then
			return false, nil
		end
		local position, normal = Spot.surface(head.Position, aim, config.ReachStuds)
		if not (position and normal) then
			return false, "Nothing to stick it to"
		end
		CoverService.useDiscreetly(player, "BugCam")
		local at = position + normal * (config.Size.Z / 2)
		local part = Instance.new("Part")
		part.Name = "Device"
		part.Size = config.Size
		part.Color = config.Color
		part.Material = Enum.Material.Metal
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CastShadow = false
		part.CFrame = CFrame.lookAt(at, at + normal)
		local cam: Cam?
		local shield = Shields.adopt(player, part, config.HP, function()
			if cam then
				forget(cam) -- shot
			end
		end)
		cam = {
			shield = shield,
			owner = player,
			view = CFrame.lookAt(at + normal * config.ViewOffsetStuds, at + normal * 2),
		}
		table.insert(cams, cam :: Cam)
		sendList(player)
		task.delay(config.Seconds, function()
			forget(cam :: Cam)
		end)
		return true, nil
	end,

	-- A Jammer blinds other teams' cams: it takes them out.
	jamAt = function(position: Vector3, radius: number, jammer: Player, _: number)
		for _, cam in table.clone(cams) do
			if
				cam.owner ~= jammer
				and not TeamService.areTeammates(jammer, cam.owner)
				and (cam.shield.part.Position - position).Magnitude <= radius
			then
				forget(cam)
			end
		end
	end,

	start = function()
		CoverService.onExposed(onExposed)
		Players.PlayerRemoving:Connect(function(player)
			for _, cam in table.clone(cams) do
				if cam.owner == player then
					forget(cam)
				end
			end
		end)
	end,
}

return BugCam
