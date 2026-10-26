--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Types = require(ReplicatedStorage.Shared.Types)
local Agents = require(ReplicatedStorage.Shared.Defs.AgentDefs)
local Janitor = require(ReplicatedStorage.Shared.Util.Janitor)
local Kit = require(script.Parent.Parent.Components.ViewKit)
local Preview = require(script.Parent.Parent.Components.WeaponPreview)
local Weapons = require(ReplicatedStorage.Shared.Defs.WeaponDefs)
local cleanup = Janitor.new()
local content = Janitor.new()
local view = { Tab = "Profile" } :: Types.MenuView
function view.Unmount()
	content:Cleanup()
	cleanup:Cleanup()
end
function view.Mount(stage, navigator)
	view.Unmount()
	local session = Kit.session(stage, "PROFILE / OPERATIVE DOSSIER", navigator)
	cleanup:Add(session.destroy)
	session.watch(function(data: Types.MetaSnapshot)
		content:Cleanup()
		local root, region = Kit.scrollRegion(
			session.Body,
			"Career",
			UDim2.new(),
			UDim2.fromScale(1, 1),
			"SCROLL / CAREER & SIX OPERATIVE MASTERY RECORDS"
		)
		content:Add(region)
		Kit.text(root, Players.LocalPlayer.DisplayName, 0, 42, true)
		Kit.text(root, `LEVEL {data.Profile.Level} · {data.Profile.Career.Matches} COMPLETED MATCHES`, 48, 30)
		local stats = data.Profile.Career
		local values = {
			{ "PACKAGE EXTRACTIONS", tostring(stats.Extractions) },
			{ "INTEL GATHERED", tostring(stats.IntelGathered) },
			{ "UNCOMPROMISED MATCHES", tostring(stats.MatchesUncompromised) },
			{ "RIVAL ELIMINATIONS", tostring(stats.Eliminations) },
		}
		for index, value in values do
			local card = Kit.panel(
				root,
				"Telemetry" .. index,
				UDim2.new((index - 1) * 0.25, 0, 0, 96),
				UDim2.new(0.25, -12, 0, 120)
			)
			Kit.text(card, value[1], 0, 42)
			Kit.text(card, value[2], 48, 50, true)
		end
		Kit.text(root, `SILENT TAKEDOWNS / {stats.Takedowns}`, 236, 36)
		Kit.text(root, "OPERATIVE MASTERY / SCROLL TO BROWSE", 290, 42, true)
		for index, id in Agents.order do
			local mastery = data.Profile.Mastery[id]
			local panel = Kit.panel(
				root,
				"Mastery" .. id,
				UDim2.new(((index - 1) % 3) / 3, 0, 0, 346 + math.floor((index - 1) / 3) * 216),
				UDim2.new(1 / 3, -12, 0, 200)
			)
			Kit.text(panel, string.upper(id) .. (if mastery then ` · LVL {mastery.Level}` else " · LOCKED"), 0, 36)
			local hardware = Weapons.getForAgent(id)[1]
			if hardware.Def then
				local art = Kit.frame(panel, "Hardware", UDim2.fromOffset(0, 42), UDim2.new(1, 0, 1, -42))
				Preview.mount(art, hardware.Def, content)
			end
		end
		Kit.text(
			root,
			"Match history and calling cards have not been published. No sample operations are presented as your career.",
			800,
			80
		)
	end)
end
return view
