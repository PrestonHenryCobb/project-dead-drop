--!strict
-- Run in the Studio EDIT command bar. Verified Image IDs come from asset-ids.json.
local ids: { [string]: string } = {
	["flat-normal.png"] = "rbxassetid://140129741768422",
	["metalness-0.png"] = "rbxassetid://98244287935634",
	["metalness-204.png"] = "rbxassetid://119308465636214",
	["metalness-235.png"] = "rbxassetid://123793328813029",
	["neutral-albedo.png"] = "rbxassetid://124864115250702",
	["roughness-107.png"] = "rbxassetid://75205409603128",
	["roughness-184.png"] = "rbxassetid://82169046589228",
	["roughness-199.png"] = "rbxassetid://89335186353011",
	["roughness-209.png"] = "rbxassetid://134062253561531",
	["roughness-230.png"] = "rbxassetid://112027768122213",
	["roughness-56.png"] = "rbxassetid://104344164591784",
	["walnut-albedo.png"] = "rbxassetid://138881370879660",
}
local maps = {
	Ivory = {
		ColorMap = assert(ids["neutral-albedo.png"], "Supply uploaded ID for neutral-albedo.png"),
		NormalMap = assert(ids["flat-normal.png"], "Supply uploaded ID for flat-normal.png"),
		RoughnessMap = assert(ids["roughness-199.png"], "Supply uploaded ID for roughness-199.png"),
		MetalnessMap = assert(ids["metalness-0.png"], "Supply uploaded ID for metalness-0.png"),
	},
	Walnut = {
		ColorMap = assert(ids["walnut-albedo.png"], "Supply uploaded ID for walnut-albedo.png"),
		NormalMap = assert(ids["flat-normal.png"], "Supply uploaded ID for flat-normal.png"),
		RoughnessMap = assert(ids["roughness-107.png"], "Supply uploaded ID for roughness-107.png"),
		MetalnessMap = assert(ids["metalness-0.png"], "Supply uploaded ID for metalness-0.png"),
	},
	Brass = {
		ColorMap = assert(ids["neutral-albedo.png"], "Supply uploaded ID for neutral-albedo.png"),
		NormalMap = assert(ids["flat-normal.png"], "Supply uploaded ID for flat-normal.png"),
		RoughnessMap = assert(ids["roughness-56.png"], "Supply uploaded ID for roughness-56.png"),
		MetalnessMap = assert(ids["metalness-235.png"], "Supply uploaded ID for metalness-235.png"),
	},
	Steel = {
		ColorMap = assert(ids["neutral-albedo.png"], "Supply uploaded ID for neutral-albedo.png"),
		NormalMap = assert(ids["flat-normal.png"], "Supply uploaded ID for flat-normal.png"),
		RoughnessMap = assert(ids["roughness-184.png"], "Supply uploaded ID for roughness-184.png"),
		MetalnessMap = assert(ids["metalness-204.png"], "Supply uploaded ID for metalness-204.png"),
	},
	Velvet = {
		ColorMap = assert(ids["neutral-albedo.png"], "Supply uploaded ID for neutral-albedo.png"),
		NormalMap = assert(ids["flat-normal.png"], "Supply uploaded ID for flat-normal.png"),
		RoughnessMap = assert(ids["roughness-230.png"], "Supply uploaded ID for roughness-230.png"),
		MetalnessMap = assert(ids["metalness-0.png"], "Supply uploaded ID for metalness-0.png"),
	},
	Suit = {
		ColorMap = assert(ids["neutral-albedo.png"], "Supply uploaded ID for neutral-albedo.png"),
		NormalMap = assert(ids["flat-normal.png"], "Supply uploaded ID for flat-normal.png"),
		RoughnessMap = assert(ids["roughness-209.png"], "Supply uploaded ID for roughness-209.png"),
		MetalnessMap = assert(ids["metalness-0.png"], "Supply uploaded ID for metalness-0.png"),
	},
}
local clone = game.ServerScriptService.Server.Tools.Gala:Clone()
local shared = game.ReplicatedStorage.Shared:Clone()
shared.Name = "SharedOverride"
shared.Parent = clone
clone.Parent = game.ServerStorage
local ok, problem = pcall(function() require(clone.Materials).install(maps) end)
clone:Destroy()
assert(ok, tostring(problem))
