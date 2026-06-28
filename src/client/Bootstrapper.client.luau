require("@client/Debug/DebugLoader")

require("@kernel/Boot/Prepare/PrepareBootInterface")

require("@kernel/Boot/Prepare/PrepareWindowInput")

task.wait(2)

require("@kernel/Boot/Prepare/PrepareFileSystem")

local TestSuccess = require("@kernel/Boot/RunTests")()
if not TestSuccess then
	return
end

local UserSuccess = require("@kernel/Boot/MakeUser")
if not UserSuccess then
	return
end

-- Wait before we jump to main interface, just so any boot logs can be read
task.wait(1)

require("@kernel/Boot/Prepare/PrepareMainInterface")

require("@kernel/Boot/Prepare/PrepareInit")
