--!strict
-- Things in the world that stop other people's shots and wear out: Parapet's Riot Wall (spec 15.2) and Lattice's Sparrow
-- Drone (spec 15.3, 40 HP, can be shot down). A shield is a part; a ray from anyone but its owner ends where it hits it, and the
-- shot's damage is taken off its HP. The owner's own shots pass through. Nothing about it is put on a character.
--
--   Shields.create(owner, root) -> Shield              a Riot Wall welded in front of the owner's root
--   Shields.adopt(owner, part, hp, onBreak?) -> Shield  a part someone else made (a drone); onBreak runs when shots destroy it
--   Shields.raycast(shooter, origin, direction, reach) -> (Shield?, number?)   the nearest shield, not the shooter's, within reach
--   Shields.damage(shield, amount)     wears it down; destroys it at 0 HP
--   Shields.destroy(shield)
--   Shields.isUp(shield) -> boolean

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

export type Shield = {
	part: Part,
	owner: Player,
	hp: number,
	maxHp: number,
	fades: boolean, -- the part grows more see-through as it wears (a Riot Wall)
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
	if shield.fades then
		local worn = 1 - math.clamp(shield.hp / shield.maxHp, 0, 1)
		shield.part.Transparency = config.Transparency.Full
			+ (config.Transparency.Worn - config.Transparency.Full) * worn
	end
end

function Shields.adopt(owner: Player, part: Part, hp: number, onBreak: (() -> ())?): Shield
	part.Parent = container()
	local shield: Shield =
		{ part = part, owner = owner, hp = hp, maxHp = hp, fades = false, onBreak = onBreak, up = true }
	shields[part] = shield
	return shield
end

function Shields.create(owner: Player, root: BasePart): Shield
	local part = Instance.new("Part")
	part.Name = "Shield"
	part.Size = config.Size
	part.Color = config.Color
	part.Material = config.Material
	part.CanCollide = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
	part.CFrame = root.CFrame * CFrame.new(0, 0, -config.Offset)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
	local shield = Shields.adopt(owner, part, config.HP, nil)
	shield.fades = true
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
