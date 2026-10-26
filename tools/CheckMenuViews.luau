--!strict
-- Paste into Studio's EDIT Command Bar. Isolated client-module copies and fake transport only;
-- no Play restart, map rebuild, real profile, server request, or purchase. Source needs Rojo synced first.
local ServerStorage = game:GetService("ServerStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local CoreGui = game:GetService("CoreGui")
local scratch = Instance.new("Folder")
scratch.Name = "MenuViewNativeFixture"
scratch.Parent = ServerStorage
local gui = Instance.new("ScreenGui")
gui.Name = "MenuViewNativeFixture"
gui.Parent = CoreGui
local client = StarterPlayer.StarterPlayerScripts.Client:Clone()
client.Parent = scratch
-- Fresh Shared copy prevents Edit-mode require caches from hiding newly synced art tokens.
local storage = Instance.new("Folder")
storage.Name = "ReplicatedStorageOverride"
storage.Parent = client
local sharedCopy = game:GetService("ReplicatedStorage").Shared:Clone()
sharedCopy.Parent = storage
for _, module in client:GetDescendants() do
	if module:IsA("ModuleScript") then
		module.Source = string.gsub(
			module.Source,
			'game:GetService%("ReplicatedStorage"%)',
			'script:FindFirstAncestor("Client"):WaitForChild("ReplicatedStorageOverride")'
		)
	end
end
local remoteModule = client.Controllers.RemoteController :: ModuleScript
remoteModule.Source = [==[
--!strict
local event = Instance.new("BindableEvent")
local profile = {
 Profile = {
  Level=1, Credits=0, Stocks=0, OwnedAgents={}, StarterPicksLeft={Deceiver=true, Enforcer=true, Specialist=true},
  Mastery={}, OwnedCosmetics={}, Dossiers={},
  Career={Matches=0, Extractions=0, IntelGathered=0, Eliminations=0, Takedowns=0, MatchesUncompromised=0},
 },
 Loadout=nil, Queue={Mode="Duos", Available={"Duos"}},
}
local remote = { value=profile, calls={} }
function remote.connect(_name, callback) return event.Event:Connect(callback) end
function remote.invoke(name, payload)
 if name == "GetPlayerMetaProfile" then return remote.value end
 table.insert(remote.calls, {name, payload})
 return false, "NativeFixtureDeclined"
end
function remote.push(value) remote.value=value; event:Fire(value) end
function remote.destroy() event:Destroy() end
return remote
]==]
-- Profile is a client view; Edit mode has no LocalPlayer. Replace only that identity access in the scratch copy.
local profileModule = client.Menu.Views.ProfileView :: ModuleScript
profileModule.Source = string.gsub(profileModule.Source, "Players.LocalPlayer.DisplayName", '"NATIVE FIXTURE"')
local remote = require(remoteModule)
local stage = Instance.new("Frame")
stage.Size = UDim2.fromOffset(1280, 608)
stage.Parent = gui
local count = 0
local function check(value: boolean, message: string)
	assert(value, message)
	count += 1
end
local views = {}
local camera = workspace.CurrentCamera
local cameraChildren = if camera then #camera:GetChildren() else 0
local previewStage: any = nil
local savedCamera = workspace.CurrentCamera
local savedFrame = if savedCamera then savedCamera.CFrame else CFrame.new()
local savedFov = if savedCamera then savedCamera.FieldOfView else 70
local savedType = if savedCamera then savedCamera.CameraType else Enum.CameraType.Custom
local ok, problem = xpcall(function()
	local navigator = {
		navigateTo = function() end,
		back = function() end,
		canOpen = function()
			return true
		end,
		focusAgent = function() end,
		snapshot = function()
			return remote.value
		end,
		onSnapshot = function(callback)
			local connection = remote.connect("ProfileStateUpdated", callback)
			return function()
				connection:Disconnect()
			end
		end,
	}
	for _, name in
		{
			"AgentsView",
			"HardwareInspectorView",
			"AssetsCodexView",
			"DossiersView",
			"BlackMarketView",
			"ProfileView",
			"MintModalView",
		}
	do
		local view = require(client.Menu.Views[name])
		table.insert(views, view)
		for _ = 1, 3 do
			view.Mount(stage, navigator)
			task.wait(0.1)
			check(#stage:GetChildren() == 1, name .. " must mount one root")
			check(#stage:GetDescendants() > 5, name .. " must render native content")
			for _, child in stage:GetDescendants() do
				if child.Name == "IllustrationTitle" and child:IsA("TextLabel") then
					check(child.TextFits, "Illustrated title must fit at the 1280x720 menu reference")
				end
			end
			if name == "MintModalView" then
				local treasury = stage:FindFirstChild("Treasury", true) :: Frame
				for _, child in treasury:GetChildren() do
					if child:IsA("TextButton") then
						check(
							child.AbsolutePosition.Y + child.AbsoluteSize.Y
								<= treasury.AbsolutePosition.Y + treasury.AbsoluteSize.Y,
							"Mint controls must stay inside Treasury"
						)
					end
				end
			end
			if name == "HardwareInspectorView" then
				local grid = stage:FindFirstChild("HardwareGrid", true)
				check(grid ~= nil, "Hardware grid missing")
				local cards = 0
				for _, child in (grid :: Instance):GetChildren() do
					if child:IsA("Frame") then
						cards += 1
					end
				end
				check(cards == 18, "Armory must show all eighteen designed weapons")
				local details = stage:FindFirstChild("Details", true) :: ScrollingFrame
				local actions = stage:FindFirstChild("Actions", true) :: Frame
				check(details.ClipsDescendants, "Inspector must clip content before pinned actions")
				check(
					details.AbsolutePosition.Y + details.AbsoluteSize.Y <= actions.AbsolutePosition.Y,
					"Inspector canvas cannot overlap pinned actions"
				)
				local rotate = details:FindFirstChild("Inspect1") :: TextButton
				check(
					rotate.AbsolutePosition.Y + rotate.AbsoluteSize.Y <= actions.AbsolutePosition.Y,
					"Rotate controls must be visible above equip"
				)
				local stats = details:FindFirstChild("HardwareStats") :: TextLabel
				check(stats.TextFits, "All weapon stats must fit their three-line readout")
				check(
					stats.AbsolutePosition.Y + stats.AbsoluteSize.Y <= actions.AbsolutePosition.Y,
					"Weapon stats must be above equip at 720p"
				)
			end
			view.Unmount()
			check(#stage:GetChildren() == 0, name .. " leaked GUI after Unmount")
			check(not camera or #camera:GetChildren() == cameraChildren, name .. " leaked a gameplay camera model")
		end
	end
	-- Test actual engraved plates and the authored static set without changing the game stage/camera.
	local art = require(client.Menu.Components.DecoArt)
	for _, kind in { "Mint", "Market", "Archive", "Asset" } do
		local plate = art.plate(stage, "NATIVE ILLUSTRATION", UDim2.new(), UDim2.fromOffset(620, 320), kind)
		task.wait(0.1)
		local label = plate:FindFirstChild("IllustrationTitle", true) :: TextLabel
		local band = label.Parent :: Frame
		check(label.TextColor3 ~= band.BackgroundColor3, "Illustration title must contrast with ivory band")
		check(#plate:GetDescendants() > 30, "Illustration must contain its original engraving")
		plate:Destroy()
	end
	local setFolder = Instance.new("Folder")
	setFolder.Parent = scratch
	require(client.Menu.Components.GalaSet).build(setFolder, CFrame.new())
	check(#setFolder:GetChildren() > 200, "Native Gala must contain authored set dressing")
	local lightCount = 0
	for _, object in setFolder:GetDescendants() do
		if object:IsA("BasePart") then
			check(
				not object.CanCollide and not object.CanTouch and not object.CanQuery,
				"Stage art must remain noninteractive"
			)
		end
		if object:IsA("Light") then
			lightCount += 1
		end
	end
	check(lightCount == 0, "Art pass must add no shadow or light budget")
	setFolder:Destroy()
	-- Exercise actual shell-owned art assembly and Play layout using only scratch transport.
	local lobbyModule = client.Menu.LobbyState :: ModuleScript
	lobbyModule.Source = "return {roster=function() return {} end,onChanged=function() return function() end end}"
	local play = require(client.Menu.LobbyViews.PlayLobbyView)
	table.insert(views, play)
	play.Mount(stage, navigator)
	task.wait(0.1)
	local brief = stage:FindFirstChild("Briefing", true) :: Frame
	local gradient = brief:FindFirstChildOfClass("UIGradient")
	check(
		gradient ~= nil and not (gradient :: UIGradient).Enabled,
		"Parchment briefing must not inherit the dark gradient"
	)
	local heading = brief:FindFirstChild("Title") :: TextLabel
	check(
		heading.TextFits and heading.TextColor3 ~= brief.BackgroundColor3,
		"Play briefing title must fit and contrast"
	)
	play.Unmount()
	check(#stage:GetChildren() == 0, "Play artwork must clean up on unmount")
	previewStage = require(client.Menu.MenuStage).new()
	check(#previewStage.folder:GetChildren() > 200, "Assembled lobby must include the authored Gala art")
	previewStage:show("Guise", "GuiseSMG")
	previewStage:frame("Play")
	previewStage:destroy()
	previewStage = nil
	local agents = require(client.Menu.Views.AgentsView)
	for _, id in { "Guise", "Parapet", "Lattice", "Reticle", "Suture", "Feint" } do
		agents.Mount(stage, navigator, { AgentId = id })
		task.wait(0.1)
		check(stage:FindFirstChild("HardwareArtwork", true) ~= nil, id .. " must show a real W1 model")
		agents.Unmount()
	end
	-- Transport refusal reaches the actual session status without optimistic state grants.
	local kit = require(client.Menu.Components.ViewKit)
	local session = kit.session(stage, "TRANSPORT FIXTURE")
	session.request("RequestEquipLoadout", { AgentId = "Guise", HardwareId = "GuiseSMG" })
	task.wait(0.1)
	local refusal = false
	for _, child in stage:GetDescendants() do
		if child:IsA("TextLabel") and child.Text == "NativeFixtureDeclined" then
			refusal = true
		end
	end
	check(refusal, "Server refusal must be readable")
	check(#remote.calls == 1, "A request must be sent only once")
	session.destroy()
	local hardware = require(client.Menu.Views.HardwareInspectorView)
	hardware.Mount(stage, navigator, { AgentId = "Guise" })
	task.wait(0.1)
	remote.value.Profile.OwnedAgents.Guise = true
	remote.value.Profile.Mastery.Guise = { Level = 10, XP = 0 }
	remote.value.Loadout = { AgentId = "Guise", HardwareId = "GuiseSMG" }
	remote.push(remote.value)
	task.wait(0.1)
	local equipped = false
	for _, child in stage:GetDescendants() do
		if child:IsA("TextButton") and child.Text == "EQUIPPED" then
			equipped = not child.Selectable
		end
	end
	check(equipped, "Profile update must display confirmed equipment and disable repeated equip")
	hardware.Unmount()
end, debug.traceback)
for _, view in views do
	pcall(view.Unmount)
end
if previewStage then
	previewStage:destroy()
end
if savedCamera then
	savedCamera.CFrame = savedFrame
	savedCamera.FieldOfView = savedFov
	savedCamera.CameraType = savedType
end
remote.destroy()
gui:Destroy()
scratch:Destroy()
assert(ok, problem)
print(
	`MENU_VIEWS_NATIVE_PASS: {count} checks; seven real views, nil first-launch loadout, all 18 Hardware, six W1 models, server refusal, profile push and teardown`
)
