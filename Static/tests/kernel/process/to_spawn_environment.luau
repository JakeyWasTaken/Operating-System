local process = require("@osiris/process")
local environment = process.GetEnvironment()

local exitCode = environment.ExitCode

exit(tonumber(exitCode))
