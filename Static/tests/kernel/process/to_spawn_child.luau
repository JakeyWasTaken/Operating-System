local process = require("@osiris/process")

local Child = process.Spawn("./to_spawn_fast.luau", {}, {}, {})
local ChildStatus = Child.Status()

exit(ChildStatus)
