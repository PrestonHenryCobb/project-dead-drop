--!strict
-- Token-bucket rate limiter, one bucket per key (usually a Player).
-- Allows `burst` calls at once and refills at `perSecond`.

local RateLimiter = {}
RateLimiter.__index = RateLimiter

type Bucket = { tokens: number, updatedAt: number }

export type RateLimiter = typeof(setmetatable(
	{} :: {
		_perSecond: number,
		_burst: number,
		_buckets: { [any]: Bucket },
	},
	RateLimiter
))

function RateLimiter.new(perSecond: number, burst: number): RateLimiter
	assert(perSecond > 0 and burst >= 1, "RateLimiter needs perSecond > 0 and burst >= 1")
	return setmetatable({
		_perSecond = perSecond,
		_burst = burst,
		_buckets = {},
	}, RateLimiter)
end

-- Returns true and spends a token if the key is allowed to act now.
function RateLimiter.Allow(self: RateLimiter, key: any): boolean
	local now = os.clock()
	local bucket = self._buckets[key]
	if not bucket then
		bucket = { tokens = self._burst, updatedAt = now }
		self._buckets[key] = bucket
	end

	bucket.tokens = math.min(self._burst, bucket.tokens + (now - bucket.updatedAt) * self._perSecond)
	bucket.updatedAt = now

	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

-- Forget a key (call when a player leaves).
function RateLimiter.Remove(self: RateLimiter, key: any)
	self._buckets[key] = nil
end

return RateLimiter
