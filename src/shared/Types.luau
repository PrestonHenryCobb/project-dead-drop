--!strict
-- Shared type definitions. Keep these in step with Enums.luau.

export type Phase = "Lobby" | "Insertion" | "Infiltration" | "VaultBreach" | "PackageHeist" | "Overtime" | "Results"

export type CoverState = "Covered" | "Suspicious" | "Exposed"

export type Mode = "Squads" | "Duos" | "Solos"

export type Role = "Guest" | "Staff" | "Security" | "Executive"

export type Tier = number -- 0 Public, 1 Staff, 2 Security, 3 Executive

export type Activity = "Walk" | "Idle" | "Talk" | "Sit" | "Lean" | "Drink" | "Work" | "Guard"

export type PickupType = "ArmorPlate" | "AmmoBox" | "Funds" | "MedKit"

export type ModeConfig = {
	TeamSize: number,
	MaxTeams: number,
	MinPlayers: number,
	MaxPlayers: number,
}

-- Spec 25.3: an outfit is a data record. Characters are built from these, never from Roblox avatar items.
export type AccessoryKind = "Tie" | "BowTie" | "Armband" | "LapelPin" | "Apron"

export type AccessoryDef = {
	Kind: AccessoryKind,
	Color: Color3,
}

export type HairStyle = "Bald" | "Crop" | "Short" | "Long" | "Bun"

export type OutfitDef = {
	OutfitId: string,
	Role: Role,
	Tier: Tier,
	BodyColors: { Skin: Color3, Shoes: Color3 },
	Shirt: { Color: Color3, LongSleeves: boolean },
	Pants: { Color: Color3 },
	Accessories: { AccessoryDef },
	Hair: { Style: HairStyle, Color: Color3 },
	Face: string,
	Scale: { Height: number, Width: number, Depth: number, Head: number },
}

-- Spec 5.3, 6.7: animations built from code. A joint pose is rotation in degrees about x, y, z and an optional
-- offset in studs: { rx, ry, rz, tx, ty, tz }. Missing trailing numbers are zero.
export type JointPose = { number }

export type PoseKeyframe = {
	Time: number,
	Joints: { [string]: JointPose },
}

export type PoseDef = {
	Loop: boolean,
	Priority: "Action" | "Action2",
	Keyframes: { PoseKeyframe },
}

-- Token-bucket limits for one client -> server remote (GameConfig.Network).
export type RateLimit = {
	PerSecond: number,
	Burst: number,
}

return {}
