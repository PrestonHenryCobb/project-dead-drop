--!strict
-- Category card emblems, shared by the local gadget HUD and agent select. Static geometry; no decorative motion.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)
local Types = require(Shared.Types)
local GadgetCard = {}

function GadgetCard.emblem(parent: Instance, category: Types.GadgetCategory, pixels: number): Frame
	local style = GameConfig.GadgetHud.Categories[category]
	local root = Instance.new("Frame")
	root.Name = style.Shape
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromOffset(pixels, pixels)
	root.Parent = parent
	local function surface(position: UDim2, size: UDim2, rotation: number): Frame
		local frame = Instance.new("Frame")
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.Position, frame.Size, frame.Rotation = position, size, rotation
		frame.BackgroundColor3 = style.Color
		frame.BorderSizePixel = 0
		frame.Parent = root
		return frame
	end
	if style.Shape == "Chevron" then
		-- Normalized icon drawing coordinates, like HudKit's vector icons.
		for _, segment in { { 0.25, 0.2, 0.75, 0.5 }, { 0.75, 0.5, 0.25, 0.8 } } do
			local x, y = segment[3] - segment[1], segment[4] - segment[2]
			surface(
				UDim2.fromScale((segment[1] + segment[3]) / 2, (segment[2] + segment[4]) / 2),
				UDim2.fromOffset(
					math.sqrt(x * x + y * y) * pixels,
					pixels * GameConfig.UI.GraphicHud.IconStrokeFraction
				),
				math.deg(math.atan2(y, x))
			)
		end
	elseif style.Shape == "Diamond" then
		surface(UDim2.fromScale(0.5, 0.5), UDim2.fromScale(1 / math.sqrt(2), 1 / math.sqrt(2)), 45)
	else
		local frame = surface(UDim2.fromScale(0.5, 0.5), UDim2.fromScale(1, 1), 0)
		local corner = Instance.new("UICorner")
		corner.CornerRadius = if style.Shape == "Circle"
			then UDim.new(0.5, 0)
			else UDim.new(0, math.min(GameConfig.UI.GraphicHud.CornerPixels, pixels / 4))
		corner.Parent = frame
	end
	return root
end

return GadgetCard
