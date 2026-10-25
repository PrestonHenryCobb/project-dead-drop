--!strict
-- Ticket gala-art-direction: shared material application, never dependent on character identity.
local MaterialService = game:GetService("MaterialService")
local GameConfig = require(script.Parent.Parent.GameConfig)
local ArtSurface = {}

function ArtSurface.apply(part: BasePart, role: string, preserveColor: boolean?)
	local materials =
		GameConfig.Art.Materials :: { [string]: { Color: Color3, Base: Enum.Material, Roughness: number, Metalness: number } }
	local definition = materials[role]
	assert(definition, `Unknown Gala surface {role}`)
	-- A visual finish must not change floor friction, body mass or collision behavior.
	part.CustomPhysicalProperties = part.CurrentPhysicalProperties
	part.Material = definition.Base
	part.MaterialVariant = ""
	if not preserveColor then
		part.Color = definition.Color
	end
	local variant = MaterialService:FindFirstChild("Gala" .. role)
	if variant and variant:IsA("MaterialVariant") and variant.BaseMaterial == definition.Base then
		part.MaterialVariant = variant.Name
	end
end

return ArtSurface
