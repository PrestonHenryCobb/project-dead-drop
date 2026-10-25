--!strict
-- Ticket gala-art-direction. Run in Studio's EDIT command bar after importing the supplied PNG maps.
-- Plugin-security properties cannot be assigned by ordinary server/client scripts.
local RunService = game:GetService("RunService")
local MaterialService = game:GetService("MaterialService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = script.Parent:FindFirstChild("SharedOverride") or ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Materials = {}

type Maps = { ColorMap: string, RoughnessMap: string, MetalnessMap: string, NormalMap: string }

function Materials.install(maps: { [string]: Maps })
	assert(not RunService:IsRunning(), "Install Gala materials in Edit mode")
	-- Validate the entire manifest before replacing any installed material.
	for role in GameConfig.Art.Materials do
		local entry = maps[role]
		assert(entry, `Missing maps for {role}`)
		for _, field in { "ColorMap", "RoughnessMap", "MetalnessMap", "NormalMap" } do
			local value = (entry :: any)[field]
			assert(type(value) == "string" and string.match(value, "^rbxassetid://%d+$"), `Invalid {role}.{field}`)
		end
	end
	for role, definition in GameConfig.Art.Materials do
		local variant = Instance.new("MaterialVariant")
		variant.Name = "Gala" .. role
		variant.BaseMaterial = definition.Base
		variant.ColorMap = maps[role].ColorMap
		variant.RoughnessMap = maps[role].RoughnessMap
		variant.MetalnessMap = maps[role].MetalnessMap
		variant.NormalMap = maps[role].NormalMap
		variant.StudsPerTile = GameConfig.Art.MaterialTileStuds
		local old = MaterialService:FindFirstChild(variant.Name)
		if old then
			old:Destroy()
		end
		variant.Parent = MaterialService
	end
end

return Materials
