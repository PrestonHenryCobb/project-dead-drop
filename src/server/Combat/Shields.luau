--!strict
-- Things in the world that stop other people's shots and wear out: Parapet's Riot Wall (spec 15.2) and Lattice's Sparrow
-- Drone (spec 15.3, 40 HP, can be shot down). A shield is a part; a ray from anyone but its owner ends where it hits it, and the
-- shot's damage is taken off its HP. The owner's own shots pass through. Nothing about it is put on a character.
--
--   Shields.create(owner, root, carried?) -> Shield    a shield welded in front of the owner's root (the Riot Wall unless given)
--   Shields.adopt(owner, part, hp, onBreak?) -> Shield  a part someone else made (a drone); onBreak runs when shots destroy it
--   Shields.raycast(shooter, origin, direction, reach) -> (Shield?, number?)   the nearest shield, not the shooter's, within reach
--   Shields.damage(shield, amount)     wears it down; destroys it at 0 HP
--   Shields.destroy(shield)
--   Shields.isUp(shield) -> boolean

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

export type Fade = { Full: number, Worn: number }

-- A shield carried in front of its owner: Offset studs ahead of the root and Lift above it. Transparency runs from Full at full
-- HP to Worn at none.
export type Carried = {
	Size: Vector3,
	Offset: number,
	Lift: number?,
	HP: number,
	Color: Color3,
	Material: Enum.Material,
	Transparency: Fade,
}

export type Shield = {
	part: Part,
	owner: Player,
	hp: number,
	maxHp: number,
	fade: Fade?, -- the part grows more see-through as it wears (a carried shield)
	onBreak: (() -> ())?,
	up: boolean,
}

local Shields = {}

local config = GameConfig.Agents.Parapet.RiotWall
local shields: { [Part]: Shield } = {}
local folder: Folder? = nil

local function container(): Folder
	if not folder then
		local made = Instance.new("Folder")
		made.Name = "Shields"
		made.Parent = workspace
		folder = made
	end
	return folder :: Folder
end

local function look(shield: Shield)
	local fade = shield.fade
	if fade then
		local worn = 1 - math.clamp(shield.hp / shield.maxHp, 0, 1)
		shield.part.Transparency = fade.Full + (fade.Worn - fade.Full) * worn
	end
end

function Shields.adopt(owner: Player, part: Part, hp: number, onBreak: (() -> ())?): Shield
	part.Parent = container()
	local shield: Shield = { part = part, owner = owner, hp = hp, maxHp = hp, fade = nil, onBreak = onBreak, up = true }
	shields[part] = shield
	return shield
end

-- A shield welded in front of the owner's root; `carried` defaults to Parapet's Riot Wall.
function Shields.create(owner: Player, root: BasePart, carried: Carried?): Shield
	local spec: Carried = carried or config
	local part = Instance.new("Part")
	part.Name = "Shield"
	part.Size = spec.Size
	part.Color = spec.Color
	part.Material = spec.Material
	part.CanCollide = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
	part.CFrame = root.CFrame * CFrame.new(0, spec.Lift or 0, -spec.Offset)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
	local shield = Shields.adopt(owner, part, spec.HP, nil)
	shield.fade = spec.Transparency
	look(shield)
	return shield
end

function Shields.isUp(shield: Shield): boolean
	return shield.up
end

function Shields.destroy(shield: Shield)
	if shield.up then
		shield.up = false
		shields[shield.part] = nil
		shield.part:Destroy()
	end
end

function Shields.damage(shield: Shield, amount: number)
	if not shield.up then
		return
	end
	shield.hp -= amount
	if shield.hp <= 0 then
		Shields.destroy(shield)
		if shield.onBreak then
			shield.onBreak()
		end
	else
		look(shield)
	end
end

function Shields.raycast(shooter: Player, origin: Vector3, direction: Vector3, reach: number): (Shield?, number?)
	local parts: { Instance } = {}
	for part, shield in shields do
		if shield.owner ~= shooter then
			table.insert(parts, part)
		end
	end
	if #parts == 0 then
		return nil, nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = parts
	local result = workspace:Raycast(origin, direction * reach, params)
	if not result then
		return nil, nil
	end
	return shields[result.Instance :: Part], result.Distance
end

return Shields
