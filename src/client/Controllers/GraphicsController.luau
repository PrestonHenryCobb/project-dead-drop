--!strict
-- Graphics quality (BUILD_ORDER Step 7B): Low, Medium or High scenery detail, so weaker machines run smoothly.
--
-- Auto follows the Roblox graphics slider (GameConfig.Graphics.AutoMediumFrom / AutoHighFrom). The cycle key (F7)
-- steps through Auto, Low, Medium and High until the Step 19 settings menu takes over; Step 21 saves the choice.
--
-- Only scenery changes, on this client: the city's window textures (by each tower's Band) and roof detail, how many
-- ceiling lights shine (by each lamp's LightIndex), shadows, bloom, haze, and the void's layers (by VoidLayer). The
-- map, NPCs and players are the same on every level. What is taken out is kept, so a higher level puts it back.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

type Level = "Low" | "Medium" | "High"
type Mode = "Auto" | Level
type LevelConfig = {
	WindowBands: { [string]: boolean },
	RoofDetail: boolean,
	LightEvery: number,
	Shadows: boolean,
	Bloom: boolean,
	HazeScale: number,
	MergeVoid: boolean,
}

local config = GameConfig.Graphics
local levels = config.Levels :: { [Level]: LevelConfig }
local CYCLE: { Mode } = { "Auto", "Low", "Medium", "High" }
local ROOF_DETAIL = { ["Roof plant"] = true, ["Water tank"] = true, Mast = true, Spire = true }
local CITY_WAIT_SECONDS = 30

local GraphicsController = {}

local mode: Mode = "Auto"
local current: LevelConfig? = nil
-- Everything the setting can take out of the city, with where it goes back.
local windowTextures: { { texture: Texture, part: BasePart, band: string } } = {}
local roofDetail: { { part: BasePart, parent: Instance } } = {}
local voidLayers: { { part: BasePart, parent: Instance, layer: number } } = {}
local topVoidLayer, bottomVoidLayer = math.huge, -math.huge
local baseDensity: number?, baseHaze: number? = nil, nil
local noticeLabel: TextLabel? = nil
local noticeToken = 0

-- The level Auto picks from the Roblox graphics slider.
local function autoLevel(): Level
	local quality = 0
	local ok = pcall(function()
		quality = (UserSettings():GetService("UserGameSettings") :: any).SavedQualityLevel.Value
	end)
	if not ok or quality == 0 then
		return "High" -- Roblox's Automatic
	end
	return if quality >= config.AutoHighFrom then "High" elseif quality >= config.AutoMediumFrom then "Medium" else "Low"
end

local function chosenLevel(): Level
	return if mode == "Auto" then autoLevel() else mode :: Level
end

-- Collect what the setting acts on, once the city has arrived.
local function gatherCity(model: Model)
	for _, item in model:GetDescendants() do
		if item:IsA("Texture") then
			local part = item.Parent
			if part and part:IsA("BasePart") then
				local band = part:GetAttribute("Band")
				if type(band) == "string" then
					table.insert(windowTextures, { texture = item :: Texture, part = part, band = band })
				end
			end
		elseif item:IsA("BasePart") then
			if ROOF_DETAIL[item.Name] then
				table.insert(roofDetail, { part = item, parent = item.Parent :: Instance })
			end
			local layer = item:GetAttribute("VoidLayer")
			if type(layer) == "number" then
				table.insert(voidLayers, { part = item, parent = item.Parent :: Instance, layer = layer })
				topVoidLayer, bottomVoidLayer = math.min(topVoidLayer, layer), math.max(bottomVoidLayer, layer)
			end
		end
	end
end

-- A ceiling light shines if its lamp's index fits the level's spacing.
local function applyToLight(light: PointLight, settings: LevelConfig)
	local lamp = light.Parent
	local index = if lamp then lamp:GetAttribute("LightIndex") else nil
	if type(index) == "number" then
		light.Enabled = (index - 1) % settings.LightEvery == 0
	end
end

local function apply(settings: LevelConfig)
	current = settings
	for _, entry in windowTextures do
		entry.texture.Parent = if settings.WindowBands[entry.band] then entry.part else nil
	end
	for _, entry in roofDetail do
		entry.part.Parent = if settings.RoofDetail then entry.parent else nil
	end
	for _, entry in voidLayers do
		local keep = not settings.MergeVoid or entry.layer == topVoidLayer or entry.layer == bottomVoidLayer
		entry.part.Parent = if keep then entry.parent else nil
	end
	local gala = workspace:FindFirstChild("Gala")
	if gala then
		for _, item in gala:GetDescendants() do
			if item:IsA("PointLight") then
				applyToLight(item, settings)
			end
		end
	end
	Lighting.GlobalShadows = settings.Shadows
	-- Ticket gala-art-direction: preserve warm/cool readability when dynamic lights/shadows are reduced.
	local low = settings == levels.Low
	Lighting.Ambient = if low then GameConfig.Art.Lighting.LowAmbient else GameConfig.Art.Lighting.Ambient
	Lighting.OutdoorAmbient = if low
		then GameConfig.Art.Lighting.LowOutdoorAmbient
		else GameConfig.Art.Lighting.OutdoorAmbient
	local bloom = Lighting:FindFirstChild("GalaBloom")
	if bloom and bloom:IsA("BloomEffect") then
		bloom.Enabled = settings.Bloom
	end
	local atmosphere = Lighting:FindFirstChild("GalaAtmosphere")
	if atmosphere and atmosphere:IsA("Atmosphere") then
		baseDensity = baseDensity or atmosphere.Density
		baseHaze = baseHaze or atmosphere.Haze
		atmosphere.Density = (baseDensity :: number) * settings.HazeScale
		atmosphere.Haze = (baseHaze :: number) * settings.HazeScale
	end
end

local function showNotice(text: string)
	local label = noticeLabel
	if not label then
		return
	end
	noticeToken += 1
	local token = noticeToken
	label.Text = text
	label.Visible = true
	task.delay(config.NoticeSeconds, function()
		if noticeToken == token then
			label.Visible = false
		end
	end)
end

local function refresh(announce: boolean)
	local level = chosenLevel()
	apply(levels[level])
	if announce then
		showNotice(if mode == "Auto" then `Graphics: Auto ({level})` else `Graphics: {level}`)
	end
end

-- Ticket gala-sculptures: shared entry point for the existing shortcut and settings UI.
function GraphicsController.setMode(nextMode: Mode)
	assert(table.find(CYCLE, nextMode), `Unknown graphics mode {nextMode}`)
	mode = nextMode
	refresh(true)
end

function GraphicsController.Init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "GraphicsNotice"
	gui.ResetOnSpawn = false
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, 0, 12)
	label.Size = UDim2.fromOffset(260, 28)
	label.BackgroundTransparency = 0.35
	label.BackgroundColor3 = Color3.new(0, 0, 0)
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 16
	label.Visible = false
	label.Parent = gui
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	noticeLabel = label
end

function GraphicsController.Start()
	local gala = workspace:WaitForChild("Gala", CITY_WAIT_SECONDS)
	local model = if gala then gala:WaitForChild("Cityscape", CITY_WAIT_SECONDS) else nil
	if model and model:IsA("Model") then
		gatherCity(model)
	end
	refresh(false)

	-- Ceiling lights stream in and out with the rooms; set each one as it arrives.
	if gala then
		gala.DescendantAdded:Connect(function(item)
			if item:IsA("PointLight") and current then
				applyToLight(item, current :: LevelConfig)
			end
		end)
	end
	local ok, settings = pcall(function()
		return UserSettings():GetService("UserGameSettings")
	end)
	if ok and settings then
		settings:GetPropertyChangedSignal("SavedQualityLevel"):Connect(function()
			if mode == "Auto" then
				refresh(true)
			end
		end)
	end
	UserInputService.InputBegan:Connect(function(input)
		-- A function key cannot be typed into chat, so it counts even when Roblox marks the input as handled.
		if input.KeyCode ~= config.CycleKey then
			return
		end
		local position = table.find(CYCLE, mode) or 1
		GraphicsController.setMode(CYCLE[position % #CYCLE + 1])
	end)
end

return GraphicsController
