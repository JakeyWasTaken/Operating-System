--[[

Exists to test the ConditionVariable process side thread blocking/waking

]]

local Ok, test = pcall(require, "@osiris/test")
if not Ok then
	return "OK" -- We are testing outside of studio, just skip
end

-- a blocked kernel-thread waiter wakes with the value provided to ::Notify
do
	local ConditionVariable = test.Core.MakeConditionVariable()

	task.defer(function()
		ConditionVariable:Notify("hello")
	end)

	local Result = ConditionVariable:Wait()
	assert(Result == "hello", "a kernel-thread waiter blocked on Wait should wake with the value passed to Notify")
end

-- Notify with no listeners does not error and does not block
do
	local ConditionVariable = test.Core.MakeConditionVariable()
	ConditionVariable:Notify("nobody home")
end

-- Notify wakes multiple blocked kernel-thread waiters with the same values
do
	local ConditionVariable = test.Core.MakeConditionVariable()
	local Results = {}

	task.defer(function()
		table.insert(Results, ConditionVariable:Wait())
	end)
	task.defer(function()
		table.insert(Results, ConditionVariable:Wait())
	end)

	-- give both waiters a chance to actually start and block before notifying
	task.wait(0.05)

	ConditionVariable:Notify("data")

	task.wait(0.05)

	assert(#Results == 2, "all blocked waiters should be woken by a single Notify call")
	assert(Results[1] == "data" and Results[2] == "data", "every woken waiter should receive the value passed to Notify")
end

-- a second Wait after Notify blocks again until the next Notify
do
	local ConditionVariable = test.Core.MakeConditionVariable()

	task.defer(function()
		ConditionVariable:Notify("first")
	end)
	assert(ConditionVariable:Wait() == "first", "the first Wait should wake with the first Notify's value")

	task.defer(function()
		ConditionVariable:Notify("second")
	end)
	assert(ConditionVariable:Wait() == "second", "a subsequent Wait should block again and wake with the next Notify's value")
end

return "OK"
