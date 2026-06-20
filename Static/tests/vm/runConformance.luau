local results = {}

local function reqAndCheck(target: string)
	local Success, Error = pcall(function(...)
		local IsOk = require(target) == "OK"
		assert(IsOk, `Was not ok`)
	end)

	table.insert(results, `[{target}] {Success and "Succeeded" or `Failed with error: {Error}`}`)
end

do -- require conformance checks
	reqAndCheck("./conformance/apicalls.luau")
	reqAndCheck("./conformance/assert.luau")
	reqAndCheck("./conformance/attrib.luau")
	reqAndCheck("./conformance/basic.luau")
	reqAndCheck("./conformance/bitwise.luau")
	reqAndCheck("./conformance/buffers.luau")
	reqAndCheck("./conformance/calls.luau")
	reqAndCheck("./conformance/clear.luau")
	reqAndCheck("./conformance/constructs.luau")
	reqAndCheck("./conformance/coroutine.luau")
	reqAndCheck("./conformance/datetime.luau")
	reqAndCheck("./conformance/debug.luau")
	reqAndCheck("./conformance/events.luau")
	reqAndCheck("./conformance/exceptions.luau")
	reqAndCheck("./conformance/ifelseexpr.luau")
	reqAndCheck("./conformance/iter.luau")
	reqAndCheck("./conformance/iter_fenv.luau")
	reqAndCheck("./conformance/locals.luau")
	reqAndCheck("./conformance/math.luau")
	reqAndCheck("./conformance/move.luau")
	reqAndCheck("./conformance/pcall.luau")
	reqAndCheck("./conformance/safeenv.luau")
	reqAndCheck("./conformance/sort.luau")
	reqAndCheck("./conformance/strconv.luau")
	reqAndCheck("./conformance/stringinterp.luau")
	reqAndCheck("./conformance/strings.luau")
	reqAndCheck("./conformance/tables.luau")
	reqAndCheck("./conformance/tmerror.luau")
	reqAndCheck("./conformance/tpack.luau")
	reqAndCheck("./conformance/types.luau")
	reqAndCheck("./conformance/utf8.luau")
	reqAndCheck("./conformance/vararg.luau")
	reqAndCheck("./conformance/vector.luau")
	reqAndCheck("./conformance/vector_library.luau")
end

for _, result in results do
	warn(result)
end

return 0
