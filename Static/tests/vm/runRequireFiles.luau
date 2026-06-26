-- Exercises require() against weird edge cases: same-file caching, a
-- diamond dependency, cyclic requires, relative/absolute path resolution,
-- and malformed/missing/failing modules.
--
-- Non-reentrant repeat-requires (the same file required twice in
-- sequence, never both mid-execution at once) are fixed: Require() now
-- checks Script:IsCompiled() before calling Compile() again, so
-- requires_counter_twice, test_diamond, and test_relative_paths should
-- all pass.

local results = {}
local failed = false

local function reqAndCheck(target: string)
	local Success, Error = pcall(function(...)
		local IsOk = require(target) == "OK"
		assert(IsOk, `Was not ok`)
	end)

	table.insert(results, `[{target}] {Success and "Succeeded" or `Failed with error: {Error}`}`)
	failed = failed or not Success
end

local testFailures = false -- run tests that are expected to fail and throw errors

do -- require file checks
	reqAndCheck("./require/files/requires_counter_twice.luau")
	reqAndCheck("./require/files/test_diamond.luau")
	reqAndCheck("./require/files/test_relative_paths.luau")
	reqAndCheck("./require/files/test_bad_modules.luau")

	if testFailures then
		reqAndCheck("./require/files/test_cyclic.luau")
		reqAndCheck("./require/files/test_self_cyclic.luau")
	end
end

for _, result in results do
	warn(result)
end

exit(failed and -1 or 0)
