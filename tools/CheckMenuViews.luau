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
stage.Size = UDim2.fromOffset(1240, 620)
stage.Parent = gui
local count = 0
local function check(value: boolean, message: string)
	assert(value, message)
	count += 1
end
local views = {}
local camera = workspace.CurrentCamera
local cameraChildren = if camera then #camera:GetChildren() else 0
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
			end
			view.Unmount()
			check(#stage:GetChildren() == 0, name .. " leaked GUI after Unmount")
			check(not camera or #camera:GetChildren() == cameraChildren, name .. " leaked a gameplay camera model")
		end
	end
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
remote.destroy()
gui:Destroy()
scratch:Destroy()
assert(ok, problem)
print(
	`MENU_VIEWS_NATIVE_PASS: {count} checks; seven real views, nil first-launch loadout, all 18 Hardware, six W1 models, server refusal, profile push and teardown`
)
