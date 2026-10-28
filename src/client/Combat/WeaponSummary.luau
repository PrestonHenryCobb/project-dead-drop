--!strict
-- Armory copy follows the registered data, including weapons which do not use firearm ammunition/reloads.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage:WaitForChild("Shared").Types)
local WeaponSummary = {}

function WeaponSummary.short(def: Types.WeaponDef): string
	local melee = def.Melee
	if melee then
		return `{melee.SwingDamage} SWING · {melee.SwingReach} STUDS\n{melee.SwingSeconds}s CADENCE · V TO STRIKE / HOLD`
	end
	if def.Projectile and def.Projectile.Kind == "Knife" then
		return `{def.Damage} BODY · {def.Damage * def.HeadshotMult} HEAD\n{def.MagSize} CARRIED · RECOVERABLE · NO RELOAD`
	end
	local damage = if def.Pellets then `{def.Pellets} × {def.Damage}` else tostring(def.Damage)
	local reload = if def.ReloadPerShell then "PER SHELL" else "RELOAD"
	return `{damage} DMG · {def.RPM} RPM · {def.MagSize}/{def.ReserveAmmo} AMMO\n{def.ReloadSeconds}s {reload} · {def.AimZoom}x FOV`
end

function WeaponSummary.detail(def: Types.WeaponDef): string
	local melee = def.Melee
	if melee then
		local special = if melee.ChargeDamage and melee.ChargeSeconds
			then `{melee.ChargeDamage} CHARGED · HOLD {melee.ChargeSeconds}s`
			elseif
				melee.TakedownDamage and melee.TakedownSeconds
			then `{melee.TakedownDamage} REAR HOLD · {melee.TakedownSeconds}s`
			else "V: STRIKE / HOLD"
		return `{melee.SwingDamage} SWING · {melee.SwingReach} STUDS · {melee.SwingSeconds}s\n{special}\nNO AMMUNITION`
	end
	if def.Projectile and def.Projectile.Kind == "Knife" then
		return WeaponSummary.short(def) .. `\nSILENT THROW · {60 / def.RPM}s BETWEEN THROWS`
	end
	local sound = if def.HearStuds == 0 then "SILENT" elseif def.Quiet then "SUPPRESSED" else "UNSUPPRESSED"
	return WeaponSummary.short(def) .. `\n{def.HeadshotMult}x HEAD · {sound}`
end

return WeaponSummary
