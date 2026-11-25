--!strict
-- The loading screen at game start (owner 2026-11-25). It replaces Roblox's default screen, pre-loads the game's sounds, images and meshes with a real
-- progress bar, and fades out when the game has loaded. The scene depends on the place: the Gala at the match place, the safehouse at the lobby place.
-- Teleports away from a place are covered by LoadingController (a client controller); this script only handles arrival.

local Players = game:GetService("Players")
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
player:WaitForChild("PlayerGui")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local LoadingDefs = require(Shared:WaitForChild("Defs"):WaitForChild("LoadingDefs"))
local LoadingScreen = require(Shared:WaitForChild("Util"):WaitForChild("LoadingScreen"))
local StudioIntro = require(Shared:WaitForChild("Util"):WaitForChild("StudioIntro"))

local config = GameConfig.Loading

local sceneId = config.PreviewScene
if sceneId == "" then
	sceneId = LoadingDefs.bootSceneFor(game.PlaceId)
end
local screen = LoadingScreen.show(sceneId)
ReplicatedFirst:RemoveDefaultLoadingScreen()

-- The studio intro plays over the loading screen while the assets load underneath; the loading screen is only read once the intro is over.
local introPlaying = config.PreviewScene == "" and GameConfig.StudioIntro.Enabled
local introEndedAt = os.clock()
if introPlaying then
	task.spawn(function()
		StudioIntro.play()
		introEndedAt = os.clock()
		introPlaying = false
	end)
end

if config.PreviewScene ~= "" then
	return -- layout review: the screen stays up
end

-- The property that names the asset for each class that has one; a class missing here is always loaded.
local ASSET_PROPERTY: { [string]: string } = {
	Sound = "SoundId",
	Decal = "Texture",
	Texture = "Texture",
	ImageLabel = "Image",
	ImageButton = "Image",
	MeshPart = "MeshId",
	Animation = "AnimationId",
}

local function collect(): { Instance }
	local found: { Instance } = {}
	local seen: { [string]: boolean } = {}
	for _, serviceName in config.PreloadRoots do
		for _, item in game:GetService(serviceName):GetDescendants() do
			for _, className in config.PreloadClasses do
				if item:IsA(className) then
					local property = ASSET_PROPERTY[item.ClassName]
					local id = if property then (item :: any)[property] else nil
					if property == nil then
						table.insert(found, item)
					elseif type(id) == "string" and id ~= "" and not seen[id] then
						seen[id] = true
						table.insert(found, item)
					end
					break
				end
			end
		end
	end
	return found
end

local startedAt = os.clock()
local assets = collect()
local total = #assets
local done = 0
screen.setProgress(0)

local index = 1
while index <= total and os.clock() - startedAt < config.MaxPreloadSeconds do
	local batch: { Instance } = {}
	for position = index, math.min(index + config.PreloadBatch - 1, total) do
		table.insert(batch, assets[position])
	end
	pcall(function()
		ContentProvider:PreloadAsync(batch)
	end)
	index += #batch
	done = index - 1
	screen.setProgress(done / total)
end
screen.setProgress(1)

if not game:IsLoaded() then
	local waitStart = os.clock()
	while not game:IsLoaded() and os.clock() - waitStart < config.MaxPreloadSeconds do
		task.wait(0.1)
	end
end
while introPlaying do
	task.wait(0.1)
end
local remaining = config.MinShowSeconds - (os.clock() - math.max(startedAt, introEndedAt))
if remaining > 0 then
	task.wait(remaining)
end
screen.close()
