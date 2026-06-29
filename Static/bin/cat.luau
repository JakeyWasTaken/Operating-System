-- cat - print file contents
local Ansi = require("/system/lib/Ansi.luau")
local fs = require("@osiris/fs")
local process = require("@osiris/process")

local Arguments = process.GetArguments() or {}
if #Arguments == 0 then
	warn(Ansi.Style("cat: missing file operand", "Red"))
	exit(-1)
end

for _, Path in Arguments do
	local Handle, Err = fs.Open(Path)
	if not Handle then
		warn(Ansi.Style(`cat: {Path}: {Err}`, "Red"))
		continue
	end

	local Contents = fs.Read(Handle) or ""
	fs.Close(Handle)

	print(Contents)
end
