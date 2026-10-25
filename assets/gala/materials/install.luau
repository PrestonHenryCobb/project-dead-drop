--!strict
-- Run in the Studio EDIT command bar after filling ids from Asset Manager.
local ids: { [string]: string } = {}
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
