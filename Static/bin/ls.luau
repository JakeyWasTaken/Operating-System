-- ls - list directory contents
local Ansi = require("/system/lib/Ansi.luau")
local fs = require("@osiris/fs")
local process = require("@osiris/process")

local Arguments = process.GetArguments() or {}
local Target = Arguments[1] or "."

local Entries, Err = fs.List(Target)
if not Entries then
	warn(Ansi.Style(`ls: {Target}: {Err}`, "Red"))
	exit(-1)
end

-- Directories first, then alphabetical.
table.sort(Entries, function(A, B)
	if A.IsDirectory ~= B.IsDirectory then
		return A.IsDirectory
	end
	return A.Name < B.Name
end)

local Lines = {}
for _, Entry in Entries do
	if Entry.IsDirectory then
		table.insert(Lines, Ansi.Style(Entry.Name .. "/", "Blue", "Bold"))
	else
		table.insert(Lines, Entry.Name)
	end
end

print(table.concat(Lines, "\n"))
