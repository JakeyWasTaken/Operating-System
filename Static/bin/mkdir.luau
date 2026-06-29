-- mkdir - create directories
local Ansi = require("/system/lib/Ansi.luau")
local fs = require("@osiris/fs")
local process = require("@osiris/process")

local Arguments = process.GetArguments() or {}
if #Arguments == 0 then
	warn(Ansi.Style("mkdir: missing operand", "Red"))
	exit(-1)
end

for _, Path in Arguments do
	local Ok, Err = fs.CreateDirectory(Path)
	if not Ok then
		warn(Ansi.Style(`mkdir: {Path}: {Err}`, "Red"))
	end
end
