-- Spawned by resolve_working_directory.luau with its working directory set to
-- /resolve_wd. It writes to a relative path, which must resolve there.
local fs = require("@osiris/fs")

assert(fs.CreateFile("./marker.txt"), "child: should create a relative file")

local Handle = assert(fs.Open("./marker.txt"), "child: should open the relative file")
fs.Write(Handle, "cwd", 0)
fs.Close(Handle)

exit(0)
