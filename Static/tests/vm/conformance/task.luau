-- task.spawn runs its function and forwards extra arguments. The calling
-- thread is yielded via JumpExecution and only resumes once Tick comes back
-- around to it, by which point the spawned thread (which ran earlier in
-- that same tick) has already finished - so checking the result right
-- after task.spawn returns is reliable, not a race.
do
	local Ran = false
	task.spawn(function()
		Ran = true
	end)
	assert(Ran == true, "task.spawn should run its function before returning control here")

	local SpawnArgResult = nil
	task.spawn(function(a, b)
		SpawnArgResult = a + b
	end, 3, 4)
	assert(SpawnArgResult == 7, "task.spawn should forward its extra arguments to the spawned function")
end

-- task.spawn returns a thread handle for whatever it ran
do
	local Handle = task.spawn(function() end)
	assert(typeof(Handle) == "thread", "task.spawn should return a thread handle")
end

-- task.wait should not return before the requested duration has elapsed
do
	local Start = os.clock()
	task.wait(0.05)
	local Elapsed = os.clock() - Start
	assert(Elapsed >= 0.05, "task.wait should not return before the requested duration has elapsed")
end

-- task.defer does NOT run synchronously - it only runs once Tick's normal
-- round-robin gets to it, which requires actually yielding (task.wait)
-- before it'll have had a chance to run.
do
	local DeferRan = false
	task.defer(function()
		DeferRan = true
	end)
	assert(DeferRan == false, "task.defer should not run its function synchronously")

	task.wait(0.05)
	assert(DeferRan == true, "task.defer's function should have run by now, after yielding at least once")
end

-- task.delay waits approximately the given duration before running
do
	local DelayRan = false
	task.delay(0.05, function()
		DelayRan = true
	end)
	assert(DelayRan == false, "task.delay should not run its function immediately")

	task.wait(0.15)
	assert(DelayRan == true, "task.delay's function should have run after its delay elapsed")
end

-- task.cancel on a still-pending task.delay should stop it from ever running
do
	local CancelRan = false
	local Handle = task.delay(0.05, function()
		CancelRan = true
	end)

	task.cancel(Handle)
	task.wait(0.15) -- well past the original 0.05s delay

	assert(CancelRan == false, "cancelling a delayed task before it fires should prevent it from ever running")
end

-- task.cancel can also target the currently-running thread (self-cancel).
-- TerminateThread only marks the thread Dead for FUTURE resumption - it
-- doesn't interrupt code that's already running, so the rest of the
-- function body still executes normally after cancelling itself.
do
	local ReachedAfterCancel = false
	local Handle = task.spawn(function()
		local Self = coroutine.running()
		task.cancel(Self)
		ReachedAfterCancel = true
	end)

	assert(ReachedAfterCancel == true, "self-cancelling should not interrupt the currently-running code, only prevent future resumption")
	assert(coroutine.status(Handle) == "dead", "the thread should be dead once it finishes running, regardless of the self-cancel")
end

return "OK"
