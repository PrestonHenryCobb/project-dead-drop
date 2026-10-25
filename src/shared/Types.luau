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
export type AccessoryKind = "Tie" | "BowTie" | "Lapels" | "PocketSquare" | "LapelPin" | "Fedora" | "Sunglasses"

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

-- Spec 6.3, 6.4: what a player knows about their own disguises. Sent only to that player. Slots has `false` for an
-- empty slot, so it stays a plain array on the wire.
export type DisguiseUpdate = {
	Exposed: boolean, -- true while in True Form
	Worn: string, -- OutfitId currently worn
	Insertion: string, -- OutfitId given at spawn
	Slots: { string | boolean },
}

-- Spec 7: a player's own cover. Sent only to that player; enemies never learn it (spec 25.7).
export type CoverInfo = {
	State: CoverState,
	CanRecover: boolean, -- the conditions for putting a disguise back on are all met
	Blocker: string, -- what stops it: "Lockout", "Minimum", "Seen" or "Zone"; "" if nothing does
	LockoutSeconds: number, -- combat lockout left
	ExposedMinSeconds: number, -- time left before an Exposed player may re-cover at all
}

export type SuspicionInfo = {
	Value: number, -- 0 to SuspicionMax
	Security: number, -- witnesses seeing the player now, by kind
	Npc: number,
	Camera: number,
}

export type TrespassInfo = {
	Restricted: boolean,
	ZoneTier: number,
	Clearance: number,
}

-- Spec 13: weapons. Stats live in Defs/WeaponDefs.luau; the rest of combat's tuning is GameConfig.Combat.
export type Falloff = {
	StartStuds: number, -- full damage up to here
	EndStuds: number, -- damage falls off linearly to MinMult from StartStuds to here, then stays there
	MinMult: number,
}

export type WeaponSpread = {
	Hip: number, -- degrees of cone, hip fire
	Aim: number, -- degrees of cone, aimed
	PerShot: number, -- degrees added by each shot
	MaxExtra: number, -- most the shots can add
	RecoverPerSecond: number, -- degrees lost per second while not firing
	MoveMult: number, -- cone multiplier while moving
}

export type WeaponRecoil = {
	PitchPerShot: number, -- degrees the view climbs per shot
	YawPerShot: number, -- degrees the view drifts per shot, left or right at random
	RecoverRate: number, -- per second, the share of the climb that settles back
	ViewKick: number, -- studs the gun model jolts back per shot
}

export type WeaponSounds = {
	Fire: string,
	Reload: string,
	Empty: string,
}

export type WeaponDef = {
	Id: string,
	Name: string,
	Agent: string,
	Automatic: boolean, -- holding the trigger keeps firing
	Damage: number,
	HeadshotMult: number,
	RPM: number,
	MagSize: number,
	ReserveAmmo: number,
	ReloadSeconds: number,
	Falloff: Falloff?, -- nil: no falloff
	Quiet: boolean, -- heard only GameConfig.Combat.QuietHearStuds away (spec 23), and no muzzle flash
	Spread: WeaponSpread,
	Recoil: WeaponRecoil,
	AimZoom: number, -- the field of view is multiplied by this while aiming
	Sounds: WeaponSounds,
	-- Ticket 8.11: optional per-weapon visuals; omitted fields use WeaponDefs.ShotDefaults. Quiet suppresses both.
	TracerColor: Color3?,
	TracerWidth: number?,
	TracerLength: number?,
	TracerSpeed: number?,
	FlashColor: Color3?,
	FlashSize: Vector3?,
}

-- Combat messages. All are sent only to the player they concern, except ShotInfo (to players within earshot).
export type HitConfirm = { Kind: "Npc" | "Agent", Head: boolean } -- the shooter's hitmarker (spec 8.4)
export type AmmoInfo = { Mag: number, Reserve: number, ReloadSeconds: number } -- ReloadSeconds > 0 as a reload starts
export type HealthInfo = { HP: number, Armor: number }
export type DamageInfo = { Position: Vector3, Amount: number } -- where the shot came from, for the direction marker
export type ShotInfo = { Origin: Vector3, Hit: Vector3, WeaponId: string, Struck: boolean } -- Struck: a person was hit
export type MeleeState = { Kind: "Takedown", Seconds: number, Active: boolean } -- a takedown began or ended

-- Token-bucket limits for one client -> server remote (GameConfig.Network).
export type RateLimit = {
	PerSecond: number,
	Burst: number,
}

return {}
