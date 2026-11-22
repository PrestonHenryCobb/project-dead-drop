--!strict
-- Wrist watch cosmetics (owner answers 2026-11-22): the watch an Exposed agent wears is one shared design, and which colours it wears is a
-- cosmetic category ("Watch", in CosmeticDefs and the Dossiers). A look only changes colours, so every watch reads the same to the other players.
--
--   WatchDefs.look(cosmeticId) -> WatchLook       the colours for an equipped Watch cosmetic id (nil or unknown: the default watch)

local GameConfig = require(script.Parent.Parent.GameConfig)

export type WatchLook = { BandColor: Color3, FaceColor: Color3 }

local config = GameConfig.WristWatch

local default: WatchLook = { BandColor = config.BandColor, FaceColor = config.FaceColor }

local looks: { [string]: WatchLook } = {
	WatchBrass = { BandColor = Color3.fromRGB(150, 115, 55), FaceColor = Color3.fromRGB(255, 214, 140) },
	WatchBlackout = { BandColor = Color3.fromRGB(14, 14, 16), FaceColor = Color3.fromRGB(235, 235, 240) },
	WatchCrimson = { BandColor = Color3.fromRGB(70, 18, 26), FaceColor = Color3.fromRGB(255, 90, 100) },
}

local WatchDefs = {}

function WatchDefs.look(cosmeticId: string?): WatchLook
	return if cosmeticId then looks[cosmeticId] or default else default
end

-- True if the id names a watch look (CosmeticDefs checks its Watch cosmetics against this).
function WatchDefs.has(cosmeticId: string): boolean
	return looks[cosmeticId] ~= nil
end

return WatchDefs
