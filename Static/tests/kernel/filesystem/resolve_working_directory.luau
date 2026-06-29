local fs = require("@osiris/fs")
local process = require("@osiris/process")

-- Relative paths resolve against the process's working directory, not against
-- the script's own location.
do
	assert(fs.CreateDirectory("resolve_wd"), "setup: create the working directory")

	-- The child's script lives in this test directory, but it runs with its
	-- working directory set to /resolve_wd and writes to a relative path.
	local Spawned = process.Spawn("./resolve_wd_child.luau", {}, {}, {
		FileContext = { WorkingDirectory = "/tmp/tests/resolve_wd", HomeDirectory = "/" },
	})
	assert(Spawned ~= nil, "setup: spawn the child that writes a relative file")
	assert(Spawned.Status() == 0, "the child should create and write its relative file successfully")

	-- "./marker.txt" must have landed under the working directory.
	local Handle = fs.Open("resolve_wd/marker.txt")
	assert(Handle ~= nil, "a relative create should land under the working directory")
	assert(fs.Read(Handle) == "cwd", "the child's relative write should be readable via the working-directory path")
	fs.Close(Handle)

	-- ...and nothing should have been created next to the child's script.
	local Stray = fs.Open("/tests/kernel/filesystem/marker.txt")
	assert(Stray == nil, "a relative path must not resolve against the script's own directory")
end

return "OK"
