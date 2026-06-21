-- pcall catches a runtime error and returns it as a normal string value
do
	local Ok, Err = pcall(function()
		error("boom")
	end)
	assert(Ok == false, "pcall should report failure when the function errors")
	assert(tostring(Err):find("boom") ~= nil, "pcall should hand back the error message")
end

-- error() can throw any value, not just strings - pcall must hand it back as-is
do
	local Sentinel = { code = 42 }
	local Ok, Err = pcall(function()
		error(Sentinel)
	end)
	assert(Ok == false, "pcall should report failure when the function errors with a non-string value")
	assert(Err == Sentinel, "pcall should hand back the exact error value, not a stringified copy")
end

-- error(msg, 0) should still be a catchable error - not checking the exact
-- message text, since Fiu wraps anything crossing a closure boundary in
-- its own envelope on top of whatever level/prefix the raw error() call used
do
	local Ok = pcall(function()
		error("no location please", 0)
	end)
	assert(Ok == false, "error(msg, 0) should still raise a catchable error")
end

-- a successful pcall returns true plus the function's real return values
do
	local Ok, A, B = pcall(function()
		return 1, 2
	end)
	assert(Ok == true and A == 1 and B == 2, "a successful pcall should return true followed by the function's own return values")
end

-- xpcall runs its handler in the context of the error, and returns the
-- handler's result rather than the raw error
do
	local Ok, Result = xpcall(function()
		error("inner")
	end, function(Err)
		return `handled: {Err}`
	end)
	assert(Ok == false, "xpcall should still report failure even though the handler ran")
	assert(tostring(Result):find("handled: ") ~= nil, "xpcall should return the handler's result, not the raw error")
end

-- xpcall on success just passes the function's return values through
do
	local Ok, Value = xpcall(function()
		return 99
	end, function(Err)
		return Err
	end)
	assert(Ok == true and Value == 99, "xpcall on success should pass the function's return value through untouched")
end

-- assert returns all of its arguments on success, raises on failure
do
	local A, B = assert(1, 2)
	assert(A == 1 and B == 2, "assert should return all of its arguments when the condition is truthy")

	local Ok, Err = pcall(assert, false, "custom message")
	assert(Ok == false and tostring(Err):find("custom message") ~= nil, "assert should raise its custom message when the condition is false")

	local Ok2 = pcall(assert, nil)
	assert(Ok2 == false, "assert should raise when the condition is nil")
end

-- errors thrown across nested pcalls only unwind to the nearest one
do
	local Outer = pcall(function()
		local Inner = pcall(function()
			error("inner error")
		end)
		assert(Inner == false, "the inner pcall should catch the inner error") -- caught here, doesn't propagate further
		error("outer error") -- this one does propagate
	end)
	assert(Outer == false, "the outer pcall should catch the outer error, since the inner one already swallowed its own")
end

-- calling a non-function value is itself a catchable error
do
	local NotAFunction = 5
	local Ok = pcall(function()
		return (NotAFunction :: any)()
	end)
	assert(Ok == false, "calling a non-function value should be a catchable runtime error")
end

-- indexing nil is a catchable error too
do
	local Missing = nil
	local Ok = pcall(function()
		return (Missing :: any).field
	end)
	assert(Ok == false, "indexing a nil value should be a catchable runtime error")
end

return "OK"
