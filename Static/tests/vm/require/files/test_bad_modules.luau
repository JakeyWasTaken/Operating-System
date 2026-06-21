-- Every one of these is required exactly once, so none of them touch the
-- repeat-require caching bug (see test_cyclic.luau) - this file should
-- pass cleanly regardless of that, and is specifically about require()
-- failing gracefully (a catchable error) rather than crashing or hanging.

do
	local Ok = pcall(require, "./bad_syntax.luau")
	assert(Ok == false, "requiring a file with invalid syntax should fail to compile, not silently succeed")
end

do
	local Ok = pcall(require, "./runtime_error.luau")
	assert(Ok == false, "requiring a file that errors at the top level should fail, not silently succeed")
end

do
	local Ok = pcall(require, "./multiple_returns.luau")
	assert(Ok == false, "a module returning more than one value should be rejected")
end

do
	local Ok = pcall(require, "./no_return.luau")
	assert(Ok == false, "a module with no return statement at all should be rejected")
end

do
	local Ok = pcall(require, "./this_file_does_not_exist.luau")
	assert(Ok == false, "requiring a nonexistent file should fail cleanly")
end

do
	-- "./nested" resolves to a folder, not a file
	local Ok = pcall(require, "./nested")
	assert(Ok == false, "requiring a path that resolves to a folder, not a file, should fail")
end

do
	-- a trailing dot on a path segment is malformed per CPath's own rules
	local Ok = pcall(require, "./foo.")
	assert(Ok == false, "requiring a malformed path string should fail cleanly")
end

do
	local Ok = pcall(require, "")
	assert(Ok == false, "requiring an empty string should fail cleanly")
end

do
	-- "@" with no library name following it
	local Ok = pcall(require, "@")
	assert(Ok == false, "requiring '@' with no library name should fail cleanly")
end

do
	local Ok = pcall(require, "@this_library_does_not_exist")
	assert(Ok == false, "requiring a nonexistent library should fail cleanly")
end

return "OK"
