-- rm - remove files or directories
local Ansi = require("/system/lib/Ansi.luau")
local fs = require("@osiris/fs")
local process = require("@osiris/process")

local Arguments = process.GetArguments() or {}
if #Arguments == 0 then
	warn(Ansi.Style("rm: missing operand", "Red"))
	exit(-1)
end

for _, Path in Arguments do
	local Ok, Err = fs.Delete(Path)
	if not Ok then
		warn(Ansi.Style(`rm: {Path}: {Err}`, "Red"))
	end
end
