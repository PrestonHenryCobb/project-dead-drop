--!strict
-- Ticket 21-data (spec 20.4): the saved player profile, one DataStore key per player, with a session lock.
--
-- The lock is a record inside the saved value ({ JobId, At }), written and checked with UpdateAsync, so two servers can
-- never both hold a profile: a join waits for the other server to let go (or for its lock to go stale after a crash),
-- and a save from a server that no longer holds the lock is refused. Every call retries with a backoff.
--
-- Studio without API access (or an unpublished place) cannot reach the store; that is detected on the first call and
-- every later call returns "Unavailable" at once, so a test session joins instantly and simply does not save.
--
--   ProfileStore.load(userId) -> (status, data?)   yields. status "Loaded" (data is nil for a new player), "Locked"
--                                                  (another live server holds it; do not play on it) or "Unavailable"
--   ProfileStore.save(userId, data, release) -> boolean   yields. release also drops the lock. false: not saved
--
-- The data is whatever the caller gives (plain tables of strings, numbers and booleans); the caller reconciles it.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

local ProfileStore = {}

local config = GameConfig.Data

type Lock = { JobId: string, At: number }
type Record = { Version: number, Data: any, Lock: Lock?, SavedAt: number }

-- Studio and private servers have an empty JobId; a random id keeps each running copy distinct.
local sessionId: string = if game.JobId ~= "" then game.JobId else `local-{HttpService:GenerateGUID(false)}`

local store: DataStore? = nil
local unavailable = false

local function keyOf(userId: number): string
	return `P{userId}`
end

local function getStore(): DataStore?
	if unavailable then
		return nil
	end
	if not store then
		local ok, result = pcall(function()
			return DataStoreService:GetDataStore(config.StoreName)
		end)
		if not ok then
			unavailable = true
			warn(`[ProfileStore] no DataStore ({result}); profiles will not be saved`)
			return nil
		end
		store = result
	end
	return store
end

-- Errors that retrying cannot fix: switch the store off and say so once.
local function isHopeless(message: string): boolean
	return string.find(message, "StudioAccessToApisNotAllowed", 1, true) ~= nil
		or string.find(message, "Studio access to APIs", 1, true) ~= nil
		or string.find(message, "must publish this place", 1, true) ~= nil
		or string.find(message, "API Services", 1, true) ~= nil
end

-- Runs one UpdateAsync with retries. The transform may run more than once and must not yield.
local function update(userId: number, transform: (Record?) -> Record?): (boolean, Record?)
	local dataStore = getStore()
	if not dataStore then
		return false, nil
	end
	local delay = config.RetryBaseSeconds
	for attempt = 1, config.Retries do
		local ok, result = pcall(function()
			return dataStore:UpdateAsync(keyOf(userId), transform)
		end)
		if ok then
			return true, result
		end
		local message = tostring(result)
		if isHopeless(message) then
			unavailable = true
			warn(`[ProfileStore] the DataStore is not available here ({message}); profiles will not be saved`)
			return false, nil
		end
		warn(`[ProfileStore] UpdateAsync for {userId} failed (try {attempt} of {config.Retries}): {message}`)
		if attempt < config.Retries then
			task.wait(delay)
			delay = math.min(delay * 2, config.RetryMaxSeconds)
		end
	end
	return false, nil
end

local function heldByOther(record: Record?): boolean
	local lock = record and record.Lock
	return lock ~= nil and lock.JobId ~= sessionId and os.time() - lock.At < config.LockStaleSeconds
end

function ProfileStore.load(userId: number): (string, any?)
	local deadline = os.clock() + config.LockWaitSeconds
	while true do
		local outcome = "Claimed"
		local ok, record = update(userId, function(old: Record?): Record?
			if heldByOther(old) then
				outcome = "Locked"
				return nil -- cancels the write; the other server keeps its lock
			end
			outcome = "Claimed"
			return {
				Version = config.Version,
				Data = if old then old.Data else nil,
				Lock = { JobId = sessionId, At = os.time() },
				SavedAt = if old then old.SavedAt else 0,
			}
		end)
		if not ok then
			return "Unavailable", nil
		end
		if outcome == "Claimed" then
			return "Loaded", if record then record.Data else nil
		end
		if os.clock() >= deadline then
			return "Locked", nil
		end
		task.wait(config.LockRetrySeconds)
	end
end

function ProfileStore.save(userId: number, data: any, release: boolean): boolean
	local lost = false
	local ok = update(userId, function(old: Record?): Record?
		if heldByOther(old) then
			lost = true
			return nil -- another server took the profile over (our lock went stale); never overwrite it
		end
		lost = false
		return {
			Version = config.Version,
			Data = data,
			Lock = if release then nil else { JobId = sessionId, At = os.time() },
			SavedAt = os.time(),
		}
	end)
	if lost then
		warn(`[ProfileStore] {userId}'s profile is held by another server now; this save was dropped`)
		return false
	end
	return ok
end

return ProfileStore
