-- exit and require aren't tested here
-- require is tested at /tests/vm/require

-- libraries are the real, native ones, passed straight through
assert(type(string) == "table" and type(string.format) == "function", "string library should be present")
assert(type(bit32) == "table" and type(bit32.band) == "function", "bit32 library should be present")
assert(type(utf8) == "table" and type(utf8.len) == "function", "utf8 library should be present")
assert(type(buffer) == "table" and type(buffer.create) == "function", "buffer library should be present")
assert(type(vector) == "table" and type(vector.create) == "function", "vector library should be present")
assert(type(table) == "table" and type(table.insert) == "function", "table library should be present")
assert(type(os) == "table" and type(os.clock) == "function", "os library should be present")
assert(type(debug) == "table", "debug library should at least be present as a table")

-- math: spot-check a few things not exercised by the other files
do
	assert(math.pi > 3.14 and math.pi < 3.15, "math.pi")
	assert(math.huge > 1e300, "math.huge should be a very large number")
	assert(math.abs(-5) == 5, "math.abs")
	assert(math.floor(1.9) == 1, "math.floor")
	assert(math.ceil(1.1) == 2, "math.ceil")
	assert(math.max(1, 5, 3) == 5, "math.max")
	assert(math.min(1, 5, 3) == 1, "math.min")
	assert(math.sqrt(16) == 4, "math.sqrt")
	assert(math.clamp(10, 0, 5) == 5, "math.clamp should clamp a value above the range down to the max")
	local rolled = math.random(1, 6)
	assert(rolled >= 1 and rolled <= 6, "math.random(1, 6) should stay within the requested range")
end

-- os: only the subset Roblox actually exposes (no os.execute/getenv/etc)
do
	assert(type(os.clock()) == "number", "os.clock should return a number")
	assert(type(os.time()) == "number", "os.time should return a number")
	assert(type(os.date()) == "string", "os.date with no format should return a string")
end

-- Roblox datatypes are passed through as the real global classes
do
	local v3 = Vector3.new(1, 2, 3)
	assert(v3.X == 1 and v3.Y == 2 and v3.Z == 3, "Vector3.new should be the real constructor")

	local cf = CFrame.new(0, 0, 0)
	assert(cf.Position == Vector3.new(0, 0, 0), "CFrame.new should be the real constructor")

	local dt = DateTime.now()
	assert(type(dt.UnixTimestamp) == "number", "DateTime.now() should be the real constructor")
end

-- Roblox time globals: all real, all return plain numbers
assert(type(tick()) == "number", "tick() should return a number")
assert(type(time()) == "number", "time() should return a number")
assert(type(elapsedTime()) == "number", "elapsedTime() should return a number")

-- deliberately disabled globals still exist as callables, but error when used
do
	local Ok1 = pcall(getfenv)
	assert(Ok1 == false, "getfenv should be disabled and error when called")

	local Ok2 = pcall(setfenv)
	assert(Ok2 == false, "setfenv should be disabled and error when called")

	local Ok3 = pcall(loadstring, "return 1")
	assert(Ok3 == false, "loadstring should be disabled and error when called")
end

-- newproxy creates a blank userdata, optionally with a settable metatable
do
	local Plain = newproxy()
	assert(typeof(Plain) == "userdata", "a plain newproxy() should still honestly report as userdata, not get caught by the thread-handle override")

	local WithMeta = newproxy(true)
	local Meta = getmetatable(WithMeta)
	assert(type(Meta) == "table", "newproxy(true) should produce a settable metatable")
	Meta.__tostring = function()
		return "custom"
	end
	assert(tostring(WithMeta) == "custom", "the metatable set on a newproxy result should actually take effect")
end

-- the type()/typeof() override is specifically for our thread handles, not
-- userdata in general - a real coroutine handle should report "thread",
-- while an unrelated plain userdata should still report "userdata"
do
	local co = coroutine.create(function() end)
	assert(type(co) == "thread", "type() should report a thread handle as 'thread'")
	assert(typeof(co) == "thread", "typeof() should report a thread handle as 'thread'")

	local Unrelated = newproxy()
	assert(type(Unrelated) == "userdata", "type() should not treat unrelated userdata as a thread")
	assert(typeof(Unrelated) == "userdata", "typeof() should not treat unrelated userdata as a thread")
end

-- gcinfo reports a number (KB in use), regardless of the exact value
assert(type(gcinfo()) == "number", "gcinfo() should return a number")

-- the rest of the base library surface, presence + a trivial sanity call
assert(type(assert) == "function", "assert should be present")
assert(type(getmetatable) == "function", "getmetatable should be present")
assert(type(ipairs) == "function", "ipairs should be present")
assert(type(next) == "function", "next should be present")
assert(type(pairs) == "function", "pairs should be present")
assert(type(pcall) == "function", "pcall should be present")
assert(type(rawequal) == "function" and rawequal(1, 1) == true, "rawequal should be present and work")
assert(type(rawget) == "function", "rawget should be present")
assert(type(rawlen) == "function" and rawlen({ 1, 2, 3 }) == 3, "rawlen should be present and work")
assert(type(rawset) == "function", "rawset should be present")
assert(type(select) == "function" and select("#", 1, 2, 3) == 3, "select should be present and work")
assert(type(setmetatable) == "function", "setmetatable should be present")
assert(type(tonumber) == "function" and tonumber("42") == 42, "tonumber should be present and work")
assert(type(tostring) == "function" and tostring(42) == "42", "tostring should be present and work")
assert(type(type) == "function", "type should be present")
assert(type(typeof) == "function", "typeof should be present")
assert(type(unpack) == "function", "unpack should be present")
do
	local a, b = unpack({ 1, 2 })
	assert(a == 1 and b == 2, "the global unpack should behave like table.unpack")
end
assert(type(xpcall) == "function", "xpcall should be present")

-- coroutine/task tables exist with the expected shape (see coroutines.luau
-- and the header comment above for why their yielding members aren't called)
assert(type(coroutine) == "table", "coroutine table should be present")
assert(type(coroutine.create) == "function", "coroutine.create should be present")
assert(type(coroutine.resume) == "function", "coroutine.resume should be present")
assert(type(coroutine.yield) == "function", "coroutine.yield should be present")
assert(type(coroutine.status) == "function", "coroutine.status should be present")
assert(type(coroutine.wrap) == "function", "coroutine.wrap should be present")
assert(type(coroutine.close) == "function", "coroutine.close should be present")
assert(type(coroutine.running) == "function", "coroutine.running should be present")
assert(type(coroutine.isyieldable) == "function", "coroutine.isyieldable should be present")

assert(type(task) == "table", "task table should be present")
assert(type(task.wait) == "function", "task.wait should be present")
assert(type(task.spawn) == "function", "task.spawn should be present")
assert(type(task.defer) == "function", "task.defer should be present")
assert(type(task.delay) == "function", "task.delay should be present")
assert(type(task.cancel) == "function", "task.cancel should be present")
assert(type(wait) == "function", "the legacy global wait should be present")
assert(type(spawn) == "function", "the legacy global spawn should be present")

-- _G and shared are the SAME table (per-process, not per-script)
do
	assert(_G == shared, "_G and shared should be the exact same table")
	_G.globalsTestMarker = "set via _G"
	assert(shared.globalsTestMarker == "set via _G", "a write through _G should be visible through shared, since they're the same table")
end

assert(_VERSION == "Fiu Interpreter", "_VERSION should identify this as the Fiu interpreter")

return "OK"
