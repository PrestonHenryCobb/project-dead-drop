--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Types)
local Kit = require(script.Parent.Parent.Components.ViewKit)
local Janitor = require(ReplicatedStorage.Shared.Util.Janitor)
local cleanup = Janitor.new()
local content = Janitor.new()
local view = { Tab = "Dossiers" } :: Types.MenuView
function view.Unmount()
	content:Cleanup()
	cleanup:Cleanup()
end
function view.Mount(stage, navigator)
	view.Unmount()
	local session = Kit.session(stage, "DOSSIERS / THE OPERATIONS ARCHIVE", navigator)
	cleanup:Add(session.destroy)
	session.watch(function(data: Types.MetaSnapshot)
		content:Cleanup()
		local root = Kit.frame(session.Body, "Archive", UDim2.new(), UDim2.fromScale(1, 1))
		content:Add(root)
		local right = Kit.frame(root, "IllustratedArchive", UDim2.fromScale(0.35, 0), UDim2.fromScale(0.65, 1))
		Kit.documentArt(right, "OPERATIONS\nARCHIVE", UDim2.new(), UDim2.fromScale(1, 0.65))
		local list = Kit.scroll(root, "Dossiers", UDim2.new(), UDim2.fromScale(0.32, 1))
		Kit.stack(list)
		local count = 0
		for id, progress in data.Profile.Dossiers do
			count += 1
			local panel = Kit.panel(list, "Dossier", UDim2.new(), UDim2.new(1, -6, 0, 200))
			Kit.text(panel, id, 0, 48, true)
			Kit.text(
				panel,
				`{progress.XP} DIRECT XP\n{#progress.Claimed} rewards claimed\n{if progress.Premium
					then "PREMIUM ACCESS"
					else "FREE ACCESS"}`,
				52,
				80
			)
			Kit.button(
				panel,
				if data.Profile.ActiveDossierId == id then "ACTIVE DOSSIER" else "SET ACTIVE DOSSIER",
				132,
				function()
					session.request("RequestSelectActiveDossier", id)
				end,
				data.Profile.ActiveDossierId ~= id
			)
		end
		if count == 0 then
			local empty = Kit.frame(list, "EmptyArchive", UDim2.new(), UDim2.new(1, -14, 0, 260))
			Kit.text(empty, "NO DOSSIERS ISSUED", 0, 70, true)
			Kit.text(
				empty,
				"Permanent tracks will appear here when their rewards are published. Your profile has no Dossier tracks yet.",
				84,
				160
			)
		end
		Kit.text(right, "NON-EXPIRING / DIRECT MATCH XP", 0, 40, true).Position = UDim2.new(0, 0, 0.71, 0)
		Kit.text(
			right,
			"No event tokens. Reward inspection and claiming become available when the server supplies a reward catalogue and tier requirements.",
			0,
			100
		).Position =
			UDim2.new(0, 0, 0.81, 0)
	end)
end
return view
