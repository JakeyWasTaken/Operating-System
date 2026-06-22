local results = {}

local function reqAndCheck(target: string)
	local Success, Error = pcall(function(...)
		local IsOk = require(target) == "OK"
		assert(IsOk, `Was not ok`)
	end)

	table.insert(results, `[{target}] {Success and "Succeeded" or `Failed with error: {Error}`}`)
end

do -- require file checks
	reqAndCheck("./process/spawning.luau")
end

for _, result in results do
	warn(result)
end
