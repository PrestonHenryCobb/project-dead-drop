--!strict
-- Step 8B.8: attach a local gun visually to any rig wearing a visible True Form outfit (the plain one or an agent's own). No roster, attributes,
-- tags, player names or new server messages. The display model stays in a client-only workspace folder.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local AgentLooks = require(Shared:WaitForChild("Defs"):WaitForChild("AgentLooks"))
local OutfitDefs = require(Shared:WaitForChild("Defs"):WaitForChild("OutfitDefs"))
local Types = require(Shared:WaitForChild("Types"))
local WeaponDefs = require(Shared:WaitForChild("Defs"):WaitForChild("WeaponDefs"))
local Janitor = require(Shared:WaitForChild("Util"):WaitForChild("Janitor"))
local ViewModel = require(script.Parent.Parent:WaitForChild("Combat"):WaitForChild("ViewModel"))

local WeaponVisualController = {}
local config = GameConfig.Combat.ThirdPersonWeapon
local janitor = Janitor.new()
local visuals: { [Model]: ViewModel.ViewModel } = {}
local elapsed = 0
local folder: Folder? = nil

-- A player who is Exposed wears their agent's True Form (or the plain one), so any of these looks marks a model that holds a weapon.
local function bodyColors(look: Types.OutfitDef): { [string]: Color3 }
	return {
		Head = look.BodyColors.Skin,
		UpperTorso = look.Shirt.Color,
		LowerTorso = look.Pants.Color,
		RightUpperArm = look.Shirt.Color,
		LeftUpperArm = look.Shirt.Color,
		RightLowerArm = if look.Shirt.LongSleeves then look.Shirt.Color else look.BodyColors.Skin,
		LeftLowerArm = if look.Shirt.LongSleeves then look.Shirt.Color else look.BodyColors.Skin,
		RightHand = look.BodyColors.Skin,
		LeftHand = look.BodyColors.Skin,
		RightUpperLeg = look.Pants.Color,
		LeftUpperLeg = look.Pants.Color,
		RightFoot = look.BodyColors.Shoes,
		LeftFoot = look.BodyColors.Shoes,
	}
end
local lookColors: { { [string]: Color3 } } = { bodyColors(OutfitDefs.trueForm) }
for _, look in AgentLooks.all() do
	table.insert(lookColors, bodyColors(look))
end

local function matches(model: Model): boolean
	if model == Players.LocalPlayer.Character then
		return false
	end
	for _, colors in lookColors do
		local all = true
		for name, color in colors do
			local part = model:FindFirstChild(name)
			if not (part and part:IsA("BasePart") and part.Color == color) then
				all = false
				break
			end
		end
		if all then
			return true
		end
	end
	return false
end

local function sweep()
	for model, visual in visuals do
		if model.Parent ~= workspace or not matches(model) then
			visual:destroy()
			visuals[model] = nil
		end
	end
	for _, child in workspace:GetChildren() do
		if child:IsA("Model") and not visuals[child] and matches(child) then
			-- Everyone currently carries Combat.DefaultWeapon. Step 8.5/loadout integration must supply the
			-- correct visible weapon when loadouts can differ; never infer loadout or agent from hidden metadata.
			local def = WeaponDefs.get(GameConfig.Combat.DefaultWeapon)
			if def then
				local visual = ViewModel.new(def)
				visual.model.Name = "HeldWeapon"
				visual.model.Parent = folder
				visual:setVisible(false)
				visuals[child] = visual
			end
		end
	end
end

local function render()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	for model, visual in visuals do
		local hand = model:FindFirstChild("RightHand")
		-- Recheck appearance each frame so a disguise swap removes the gun immediately, even between sweeps.
		local visible = hand and hand:IsA("BasePart") and matches(model)
		if visible and hand and hand:IsA("BasePart") then
			visible = (hand.Position - camera.CFrame.Position).Magnitude <= config.CullStuds
			if visible then
				local left = model:FindFirstChild("LeftHand")
				visual:placeAtRightHand(hand.CFrame, if left and left:IsA("BasePart") then left.CFrame else nil)
			end
		end
		visual:setVisible(visible == true)
	end
end

function WeaponVisualController.Init() end

function WeaponVisualController.Start()
	local container = Instance.new("Folder")
	container.Name = "CombatHeldWeapons"
	container.Parent = workspace
	folder = container
	janitor:Add(container)
	janitor:Add(function()
		for _, visual in visuals do
			visual:destroy()
		end
		table.clear(visuals)
	end)
	janitor:Add(RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= config.ScanSeconds then
			elapsed %= config.ScanSeconds
			sweep()
		end
	end))
	janitor:Add(RunService.RenderStepped:Connect(render))
	janitor:Add(script.Destroying:Connect(function()
		janitor:Destroy()
	end))
	sweep()
end

return WeaponVisualController
