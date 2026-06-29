-- echo - write arguments to stdout
local process = require("@osiris/process")

local Arguments = process.GetArguments() or {}
print(table.concat(Arguments, " "))
