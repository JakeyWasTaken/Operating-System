-- touch - create files if they don't already exist
local Ansi = require("/system/lib/Ansi.luau")
local fs = require("@osiris/fs")
local process = require("@osiris/process")

local Arguments = process.GetArguments() or {}
if #Arguments == 0 then
	warn(Ansi.Style("touch: missing operand", "Red"))
	exit(-1)
end

for _, Path in Arguments do
	local Ok, Err = fs.CreateFile(Path)
	if not Ok then
		-- An already-existing file is fine for touch; anything else is an error.
		local Existing = fs.Open(Path)
		if Existing then
			fs.Close(Existing)
		else
			warn(Ansi.Style(`touch: {Path}: {Err}`, "Red"))
		end
	end
end
