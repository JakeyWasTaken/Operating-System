-- both type() and typeof() report our handles as "thread", even though
-- they're actually a newproxy() under the hood - see EnvironmentFactory's
-- Type/Typeof overrides.
do
	local co = coroutine.create(function() end)
	assert(typeof(co) == "thread", "typeof() should report our handle as a thread")
	assert(type(co) == "thread", "type() should also report our handle as a thread")
end

-- a freshly created coroutine is suspended until resumed
do
	local co = coroutine.create(function() end)
	assert(coroutine.status(co) == "suspended", "a freshly created coroutine should be suspended, not running")
end

-- resume runs the body, forwards arguments, and returns (true, ...returns)
do
	local co = coroutine.create(function(a, b)
		return a + b
	end)
	local Ok, Sum = coroutine.resume(co, 3, 4)
	assert(Ok == true and Sum == 7, "resume should forward its arguments to the coroutine body and return its result")
	assert(coroutine.status(co) == "dead", "a coroutine that ran to completion should be dead")
end

-- yield suspends mid-body and hands values back to resume's caller; the
-- next resume's arguments become yield's return values
do
	local co = coroutine.create(function(start)
		local fromResume = coroutine.yield(start + 1)
		return fromResume + 1
	end)

	local Ok1, Yielded = coroutine.resume(co, 10)
	assert(Ok1 == true and Yielded == 11, "the first resume's value should come back as yield's argument")
	assert(coroutine.status(co) == "suspended", "a coroutine that yielded should be suspended, not dead")

	local Ok2, Final = coroutine.resume(co, 100)
	assert(Ok2 == true and Final == 101, "the second resume's argument should become yield's return value inside the coroutine")
	assert(coroutine.status(co) == "dead", "a coroutine that ran to completion after resuming should be dead")
end

-- an error inside the coroutine comes back as (false, err) from resume,
-- rather than propagating up through the caller
do
	local co = coroutine.create(function()
		error("inner failure")
	end)
	local Ok, Err = coroutine.resume(co)
	assert(Ok == false, "resume should report failure when the coroutine body errors")
	assert(tostring(Err):find("inner failure") ~= nil, "resume should hand back the coroutine's error message")
	assert(coroutine.status(co) == "dead", "a coroutine that errored should be dead, not resumable again")
end

-- resuming an already-dead coroutine fails cleanly instead of erroring outright
do
	local co = coroutine.create(function() end)
	coroutine.resume(co)
	assert(coroutine.status(co) == "dead", "the coroutine should be dead after its first, completing resume")

	local Ok = coroutine.resume(co)
	assert(Ok == false, "resuming an already-dead coroutine should fail cleanly rather than erroring outright")
end

-- wrap behaves like resume but raises on failure and returns values directly on success
do
	local gen = coroutine.wrap(function()
		coroutine.yield(1)
		coroutine.yield(2)
		return 3
	end)

	assert(gen() == 1, "wrap's first call should return the first yielded value")
	assert(gen() == 2, "wrap's second call should return the second yielded value")
	assert(gen() == 3, "wrap's third call should return the final returned value")

	local failing = coroutine.wrap(function()
		error("wrapped failure")
	end)
	local Ok = pcall(failing)
	assert(Ok == false, "wrap should re-raise the coroutine's error instead of returning (false, err) like resume does")
end

-- a multi-step generator pattern: resume repeatedly until the coroutine dies
do
	local function counter(limit: number)
		return coroutine.create(function()
			for i = 1, limit do
				coroutine.yield(i)
			end
		end)
	end

	local co = counter(3)
	local seen = {}
	while coroutine.status(co) ~= "dead" do
		local Ok, Value = coroutine.resume(co)
		if Ok and Value then
			table.insert(seen, Value)
		end
	end
	assert(#seen == 3 and seen[1] == 1 and seen[3] == 3, "repeatedly resuming a generator-style coroutine should yield every value in order")
end

-- isyieldable reflects whether we're currently running underneath a resume
do
	assert(coroutine.isyieldable() == true, "isyieldable should be true, since this whole script runs as a kernel thread under a resume") -- this whole script runs as a kernel thread
end

-- running() returns this script's own handle while at the top level
do
	local Self = coroutine.running()
	assert(typeof(Self) == "thread", "coroutine.running() should return a handle that reports as a thread")
end

-- task.spawn and coroutine.* operate on the exact same kind of handle under
-- the hood (both go through ProcessScheduler), so a thread spawned via
-- task.spawn should be fully introspectable via coroutine.status too.
do
	local Started = false
	local Handle = task.spawn(function()
		Started = true
	end)

	-- task.spawn yields the calling thread via JumpExecution and only
	-- returns control here once Tick resumes it again, by which point the
	-- spawned thread (which ran in that same earlier tick) has already
	-- finished - so this is reliably true, not a race.
	assert(Started == true, "task.spawn should have already run its function by the time it returns control here")
	assert(typeof(Handle) == "thread", "task.spawn should return a thread handle")
	assert(coroutine.status(Handle) == "dead", "coroutine.status should introspect a task.spawn'd thread just like one made via coroutine.create")
end

return "OK"
