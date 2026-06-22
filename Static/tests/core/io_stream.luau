--[[

Exists to test the IOStream process side thread blocking/waking

]]

local Ok, test = pcall(require, "@test")
if not Ok then
	return "OK" -- We are testing outside of studio, just skip
end

-- a blocked kernel-thread reader wakes with the written data once Write runs
do
	local IOStream = test.Core.MakeIOStream()

	task.defer(function()
		IOStream:Write("hello")
	end)

	local Result = IOStream:Read()
	assert(Result == "hello", "a kernel-thread reader blocked on Read should wake with the written data once Write is called")
end

-- Read does not block at all when data is already available
do
	local IOStream = test.Core.MakeIOStream()
	IOStream:Write("hello")

	assert(IOStream:Read() == "hello", "Read should return immediately when data is already buffered, even on a real kernel thread")
end

-- Close wakes a blocked kernel-thread reader with nil, same as it does for
-- a plain-coroutine reader
do
	local IOStream = test.Core.MakeIOStream()

	task.defer(function()
		IOStream:Close()
	end)

	local Result = IOStream:Read()
	assert(Result == nil, "a kernel-thread reader blocked on Read should wake with nil once the stream is closed")
end

-- SandboxReader/SandboxWriter delegate correctly under the kernel-thread path too
do
	local IOStream = test.Core.MakeIOStream()
	local Reader = IOStream:SandboxReader()
	local Writer = IOStream:SandboxWriter()

	task.defer(function()
		Writer:Write("hi")
	end)

	assert(Reader:Read() == "hi", "SandboxReader/SandboxWriter should delegate correctly for a kernel-thread blocked read")
end

do
	local IOStream = test.Core.MakeIOStream()
	local Results = {}

	task.defer(function()
		table.insert(Results, IOStream:Read())
	end)
	task.defer(function()
		table.insert(Results, IOStream:Read())
	end)

	-- give both readers a chance to actually start and block before writing
	task.wait(0.05)

	IOStream:Write("data")

	task.wait(0.05)

	assert(Results[1] == "data", "the first-resumed blocked reader should get the written data")
	assert(
		#Results == 1,
		"the second-resumed blocked reader currently gets nil (indistinguishable from the stream closing) since the buffer is already drained by the time it wakes - table.insert with a nil value doesn't grow the array"
	)
end

return "OK"
