local process = require("@process")
local environment = process.GetEnvironment()

local exitCode = environment.ExitCode

exit(tonumber(exitCode))
