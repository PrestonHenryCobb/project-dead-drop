--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Types = require(ReplicatedStorage.Shared.Types)
local Janitor = require(ReplicatedStorage.Shared.Util.Janitor)
local Kit = require(script.Parent.Parent.Components.ViewKit)
local cleanup = Janitor.new()
local modalCleanup = Janitor.new()
local view = { Tab = "Mint" } :: Types.MenuView & { OpenInspection: (Frame, string, string, (() -> ())?) -> () }

-- Shared inspection overlay. Call only with server catalogue data; an omitted confirm is a read-only inspection.
function view.OpenInspection(parent: Frame, title: string, description: string, confirm: (() -> ())?)
	modalCleanup:Cleanup()
	local previous = GuiService.SelectedObject
	local overlay = Instance.new("TextButton")
	overlay.Name = "InspectionModal"
	overlay.Text = ""
	overlay.AutoButtonColor = false
	overlay.BackgroundColor3 = Kit.Theme.Colors.Canvas
	overlay.BackgroundTransparency = 0.12
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.ZIndex = 20
	overlay.Modal = true
	overlay.Selectable = false
	overlay.Parent = parent
	modalCleanup:Add(overlay)
	local panel = Kit.panel(overlay, "Inspection", UDim2.fromScale(0.19, 0.12), UDim2.fromScale(0.62, 0.76))
	panel.SelectionGroup = true
	panel.SelectionBehaviorUp = Enum.SelectionBehavior.Stop
	panel.SelectionBehaviorDown = Enum.SelectionBehavior.Stop
	panel.SelectionBehaviorLeft = Enum.SelectionBehavior.Stop
	panel.SelectionBehaviorRight = Enum.SelectionBehavior.Stop
	local body = Kit.scroll(panel, "InspectionBody", UDim2.new(), UDim2.new(1, 0, 1, -58))
	Kit.text(body, title, 0, 80, true)
	Kit.text(body, description, 100, 180)
	local function close()
		modalCleanup:Cleanup()
		if previous and previous.Parent then
			GuiService.SelectedObject = previous
		end
	end
	local button = Kit.button(panel, "CLOSE INSPECTION", 0, close)
	button.Instance.Position = UDim2.new(0, 0, 1, -46)
	if confirm then
		Kit.button(body, "CONFIRM", 300, function()
			close()
			confirm()
		end, true, true)
	end
	for _, child in overlay:GetDescendants() do
		if child:IsA("GuiObject") then
			child.ZIndex = 21
		end
	end
	GuiService.SelectedObject = button.Instance
end

function view.Unmount()
	modalCleanup:Cleanup()
	cleanup:Cleanup()
end
function view.Mount(stage, navigator)
	view.Unmount()
	local session = Kit.session(stage, "THE MINT / STOCK CERTIFICATES", navigator)
	cleanup:Add(session.destroy)
	local rail = Kit.scroll(session.Body, "TreasuryRail", UDim2.new(), UDim2.fromScale(0.4, 1))
	local left = Kit.flowPanel(rail, "Treasury")
	Kit.flowText(left, "TreasuryTitle", "YOUR STOCKS", 1, true)
	local balance = Kit.flowText(left, "VerifiedBalance", "Loading verified balance…", 2, true)
	Kit.flowText(
		left,
		"TreasuryNotice",
		"Stocks buy cosmetics. Robux purchases are coming soon; no Robux payment is available here yet.",
		3
	)
	Kit.button(left, "BACK TO BLACK MARKET", 0, function()
		navigator.navigateTo("BlackMarket")
	end).Instance.LayoutOrder =
		5
	Kit.button(left, "INSPECT MINT POLICY", 0, function()
		view.OpenInspection(
			session.Root,
			"THE MINT",
			"The listed packages show planned prices. Robux purchases are coming soon. Studio preview grants are confirmed by the server."
		)
	end).Instance.LayoutOrder =
		6
	local packages = Kit.scroll(session.Body, "StockPackages", UDim2.fromScale(0.44, 0), UDim2.fromScale(0.56, 1))
	Kit.stack(packages)
	for order, package in GameConfig.Shop.Mint.Packages do
		local card = Kit.flowPanel(packages, package.Id)
		card.LayoutOrder = order
		Kit.flowText(card, "Stocks", `{package.Stocks} STOCKS`, 1, true)
		Kit.flowText(card, "Price", `PLANNED PRICE · {package.Robux} ROBUX`, 2)
		Kit.flowText(
			card,
			"Availability",
			if RunService:IsStudio()
				then "Studio preview only. No Robux charge."
				else "COMING SOON · Robux purchases are not available yet.",
			3
		)
		Kit.button(card, if RunService:IsStudio() then "PREVIEW STOCKS IN STUDIO" else "COMING SOON", 0, function()
			session.request("RequestMintStrikeStocks", package.Id)
		end, true, true).Instance.LayoutOrder =
			4
	end
	session.watch(function(data: Types.MetaSnapshot)
		balance.Text = tostring(data.Profile.Stocks) .. " STOCKS"
	end)
end
return view
