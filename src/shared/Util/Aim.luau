--!strict
-- What the local player's crosshair is on. Client only. The result is only a hint for the server, which checks range
-- and sight itself (spec 25.6): the client never decides who is an agent.
--
--   Aim.characterName(range) -> string?   the name of the character under the centre of the screen, if its body is
--                                          within `range` studs (flat distance) of the local player's body

local Players = game:GetService("Players")

local Aim = {}

local EXTRA_REACH = 2 -- studs past the range the ray travels, so a target at the edge is still hit

function Aim.characterName(range: number): string?
	local camera = workspace.CurrentCamera
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (camera and character and root and root:IsA("BasePart")) then
		return nil
	end
	local viewport = camera.ViewportSize
	local ray = camera:ViewportPointToRay(viewport.X / 2, viewport.Y / 2)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local reach = (camera.CFrame.Position - root.Position).Magnitude + range + EXTRA_REACH
	local hit = workspace:Raycast(ray.Origin, ray.Direction * reach, params)
	local model = hit and hit.Instance:FindFirstAncestorOfClass("Model")
	if
		not model or not (model:FindFirstChildOfClass("Humanoid") or model:FindFirstChildOfClass("AnimationController"))
	then
		return nil
	end
	local targetRoot = model:FindFirstChild("HumanoidRootPart")
	if not (targetRoot and targetRoot:IsA("BasePart")) then
		return nil
	end
	local offset = targetRoot.Position - root.Position
	if Vector3.new(offset.X, 0, offset.Z).Magnitude > range then
		return nil
	end
	return model.Name
end

return Aim
