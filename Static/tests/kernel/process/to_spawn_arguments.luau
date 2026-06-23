local process = require("@process")
local arguments = process.GetArguments()

local exitCode = arguments[1]

exit(tonumber(exitCode))
