--!strict
-- A view ending after lobby destruction replicated must not hand the reopened menu's camera to Roblox's player camera.
local Players = game:GetService("Players")
local CameraGuard = {}
local remoteViews: { [Instance]: boolean } = {}

function CameraGuard.setRemoteView(owner: Instance, viewing: boolean)
	remoteViews[owner] = if viewing then true else nil
end

function CameraGuard.remoteViewing(): boolean
	return next(remoteViews) ~= nil
end

function CameraGuard.menuOpen(): boolean
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local menu = playerGui and playerGui:FindFirstChild("CoverStoryMenuGui")
	return menu ~= nil and menu:IsA("ScreenGui") and menu.Enabled
end

function CameraGuard.restoreGameplay()
	local camera = workspace.CurrentCamera
	if camera and not CameraGuard.menuOpen() and not CameraGuard.remoteViewing() then
		camera.CameraType = Enum.CameraType.Custom
	end
end

return table.freeze(CameraGuard)
