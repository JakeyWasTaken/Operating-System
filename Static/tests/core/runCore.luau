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

do -- require file checks
	reqAndCheck("./io_stream.luau")
	reqAndCheck("./condition_variable.luau")
end

for _, result in results do
	warn(result)
end

exit(failed and -1 or 0)
