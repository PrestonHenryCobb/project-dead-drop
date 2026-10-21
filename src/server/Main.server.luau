--!strict
-- Server entry point. Requires every module in Services, calls every Init, then every Start.
-- Init sets up state and must not call other services. Start connects events and may call other services.

local Services = script.Parent:WaitForChild("Services")

type Service = {
	Init: () -> (),
	Start: () -> (),
}

local children = Services:GetChildren()
table.sort(children, function(a, b)
	return a.Name < b.Name
end)

local loaded: { { name: string, service: Service } } = {}
for _, child in children do
	if child:IsA("ModuleScript") then
		local service = require(child) :: any
		assert(
			type(service) == "table" and type(service.Init) == "function" and type(service.Start) == "function",
			`Service {child.Name} must return a table with Init() and Start()`
		)
		table.insert(loaded, { name = child.Name, service = service :: Service })
	end
end

for _, entry in loaded do
	entry.service.Init()
	print(`[Server] Init: {entry.name}`)
end

for _, entry in loaded do
	task.spawn(function()
		entry.service.Start()
		print(`[Server] Started: {entry.name}`)
	end)
end

print(`[Server] {#loaded} service(s) running`)
