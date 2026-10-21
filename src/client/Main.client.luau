--!strict
-- Client entry point. Requires every module in Controllers, calls every Init, then every Start.
-- Init sets up state and must not call other controllers. Start connects events and may call other controllers.

local Controllers = script.Parent:WaitForChild("Controllers")

type Controller = {
	Init: () -> (),
	Start: () -> (),
}

local children = Controllers:GetChildren()
table.sort(children, function(a, b)
	return a.Name < b.Name
end)

local loaded: { { name: string, controller: Controller } } = {}
for _, child in children do
	if child:IsA("ModuleScript") then
		local controller = require(child) :: any
		assert(
			type(controller) == "table" and type(controller.Init) == "function" and type(controller.Start) == "function",
			`Controller {child.Name} must return a table with Init() and Start()`
		)
		table.insert(loaded, { name = child.Name, controller = controller :: Controller })
	end
end

for _, entry in loaded do
	entry.controller.Init()
	print(`[Client] Init: {entry.name}`)
end

for _, entry in loaded do
	task.spawn(function()
		entry.controller.Start()
		print(`[Client] Started: {entry.name}`)
	end)
end

print(`[Client] {#loaded} controller(s) running`)
