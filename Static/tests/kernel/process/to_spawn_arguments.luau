local process = require("@osiris/process")
local arguments = process.GetArguments()

local exitCode = arguments[1]

exit(tonumber(exitCode))
