--!strict
-- Original native-part extraction silhouette; cosmetic only, with no camera or world-physics authority.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared").GameConfig)
local config = GameConfig.ExtractionVisuals
local ExtractionAircraft = {}

function ExtractionAircraft.new(parent: Instance)
	local parts: { { part: BasePart, offset: CFrame, rotor: boolean, alpha: number } } = {}
	local function add(name: string, size: Vector3, offset: CFrame, color: Color3, rotor: boolean?, glass: boolean?)
		local part = Instance.new("Part")
		part.Name, part.Size = name, size
		part.Anchored = true
		part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
		part.Material = if glass then Enum.Material.Glass else Enum.Material.SmoothPlastic
		part.Color = color
		part.Transparency = 1
		part.Parent = parent
		table.insert(parts, { part = part, offset = offset, rotor = rotor == true, alpha = if glass then 0.3 else 0 })
	end
	add("Cabin", Vector3.new(4.2, 2.5, 6.5), CFrame.identity, config.BodyColor)
	add("Nose", Vector3.new(3.6, 1.9, 2.2), CFrame.new(0, -0.1, -3.7), config.BodyColor)
	add("Windshield", Vector3.new(3.3, 1.2, 0.1), CFrame.new(0, 0.5, -4.82), config.WindowColor, false, true)
	add("TailBoom", Vector3.new(0.65, 0.65, 7), CFrame.new(0, 0.35, 5.7), config.BodyColor)
	add("TailFin", Vector3.new(0.22, 2.4, 1.4), CFrame.new(0, 1.1, 8.5), config.AccentColor)
	add("Mast", Vector3.new(0.3, 1, 0.3), CFrame.new(0, 1.75, 0), config.AccentColor)
	add("Rotor", Vector3.new(13, 0.12, 0.35), CFrame.new(0, 2.3, 0), config.BodyColor, true)
	add("CrossRotor", Vector3.new(0.35, 0.12, 13), CFrame.new(0, 2.3, 0), config.BodyColor, true)
	for _, side in { -1, 1 } do
		add("Skid", Vector3.new(0.2, 0.2, 6), CFrame.new(side * 2.1, -2.2, 0), config.AccentColor)
		add("Strut", Vector3.new(0.2, 1, 0.2), CFrame.new(side * 2.1, -1.7, 0), config.BodyColor)
	end
	return {
		update = function(position: Vector3?, state: string?, clock: number, progress: number)
			local visible = position ~= nil and (state == "Hover" or state == "Open" or state == "Extracted")
			local height = config.HoverStuds + math.sin(clock * config.HoverBobSpeed) * config.HoverBobStuds
			if state == "Extracted" then
				height += config.RiseStuds * progress
			end
			local frame = CFrame.new((position or Vector3.zero) + Vector3.new(0, height, 0))
			for _, entry in parts do
				local spin = if entry.rotor
					then CFrame.Angles(0, clock * config.RotorRadiansPerSecond, 0)
					else CFrame.identity
				entry.part.CFrame = frame * entry.offset * spin
				entry.part.Transparency = if visible then entry.alpha else 1
			end
		end,
	}
end

return ExtractionAircraft
