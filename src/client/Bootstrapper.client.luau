require("@client/Debug/DebugLoader")

require("@kernel/Boot/Prepare/PrepareBootInterface")

task.wait(2)

require("@kernel/Boot/Prepare/PrepareFileSystem")

local Success = require("@kernel/Boot/RunTests")()
if not Success then
	return
end

require("@kernel/Boot/MakeUser")

-- Wait before we jump to main interface, just so any boot logs can be read
task.wait(1)

require("@kernel/Boot/Prepare/PrepareMainInterface")
