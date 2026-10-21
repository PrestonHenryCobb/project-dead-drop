--!strict
-- Cleanup helper (CLAUDE.md rule 5). Collect connections, instances, threads and callbacks, then clean them all
-- up at once, for example on death or at round end.
--
--   local janitor = Janitor.new()
--   janitor:Add(part.Touched:Connect(onTouched))
--   janitor:Add(part)                 -- destroyed on cleanup
--   janitor:Add(function() ... end)   -- called on cleanup
--   janitor:Cleanup()                 -- everything above is cleaned up; the janitor can be reused
--   janitor:Destroy()                 -- Cleanup, and the janitor can't be used again

export type Cleanable = Instance | RBXScriptConnection | thread | (() -> ()) | { Destroy: (any) -> () }

local Janitor = {}
Janitor.__index = Janitor

export type Janitor = typeof(setmetatable(
	{} :: {
		_items: { Cleanable },
		_destroyed: boolean,
	},
	Janitor
))

function Janitor.new(): Janitor
	return setmetatable({
		_items = {},
		_destroyed = false,
	}, Janitor)
end

local function cleanItem(item: Cleanable)
	local itemType = typeof(item)
	if itemType == "function" then
		(item :: () -> ())()
	elseif itemType == "RBXScriptConnection" then
		(item :: RBXScriptConnection):Disconnect()
	elseif itemType == "Instance" then
		(item :: Instance):Destroy()
	elseif itemType == "thread" then
		task.cancel(item :: thread)
	elseif itemType == "table" then
		(item :: { Destroy: (any) -> () }):Destroy()
	else
		error(`Janitor can't clean up a {itemType}`)
	end
end

-- Adds an item and returns it. If the janitor is already destroyed, the item is cleaned up immediately.
function Janitor.Add<T>(self: Janitor, item: T & Cleanable): T
	if self._destroyed then
		cleanItem(item)
		return item
	end
	table.insert(self._items, item)
	return item
end

-- Cleans up in reverse order of adding.
function Janitor.Cleanup(self: Janitor)
	local items = self._items
	self._items = {}
	for index = #items, 1, -1 do
		cleanItem(items[index])
	end
end

function Janitor.Destroy(self: Janitor)
	self:Cleanup()
	self._destroyed = true
end

return Janitor
