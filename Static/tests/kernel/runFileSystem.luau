local results = {}

local function reqAndCheck(target: string)
	local Success, Error = pcall(function(...)
		local IsOk = require(target) == "OK"
		assert(IsOk, `Was not ok`)
	end)

	table.insert(results, `[{target}] {Success and "Succeeded" or `Failed with error: {Error}`}`)
end

do -- require file checks
	reqAndCheck("./filesystem/create_file.luau")
	reqAndCheck("./filesystem/create_directory.luau")
	reqAndCheck("./filesystem/open_close.luau")
	reqAndCheck("./filesystem/read_write.luau")
	reqAndCheck("./filesystem/exclusive_lock.luau")
	reqAndCheck("./filesystem/metadata.luau")
	reqAndCheck("./filesystem/delete_file.luau")
	reqAndCheck("./filesystem/delete_directory.luau")
end

for _, result in results do
	warn(result)
end
