local results = {}

local function reqAndCheck(target: string)
	local Success, Error = pcall(function(...)
		local IsOk = require(target) == "OK"
		assert(IsOk, `Was not ok`)
	end)

	table.insert(results, `[{target}] {Success and "Succeeded" or `Failed with error: {Error}`}`)
end

do -- require conformance checks
	reqAndCheck("./conformance/basic.luau")
	reqAndCheck("./conformance/closures.luau")
	reqAndCheck("./conformance/metatables.luau")
	reqAndCheck("./conformance/iteration.luau")
	reqAndCheck("./conformance/errors.luau")
	reqAndCheck("./conformance/strings.luau")
	reqAndCheck("./conformance/patterns.luau")
	reqAndCheck("./conformance/tables.luau")
	reqAndCheck("./conformance/globals.luau")
	reqAndCheck("./conformance/bitwise_utf8.luau")
	reqAndCheck("./conformance/buffers.luau")
	reqAndCheck("./conformance/vectors.luau")
	reqAndCheck("./conformance/coroutines.luau")
	reqAndCheck("./conformance/task.luau")
end

for _, result in results do
	warn(result)
end
