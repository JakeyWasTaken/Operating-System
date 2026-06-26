local fs = require("@osiris/fs")

fs.CreateFile("./read_write_a.txt")
local Handle = fs.Open("./read_write_a.txt")
assert(Handle ~= nil, "setup: open the file to read/write")

-- Write/Read round-trip
do
	fs.Write(Handle, "hello", 0)
	assert(fs.Read(Handle) == "hello", "Write/Read should round-trip")
end

-- Writing at an offset overwrites only that region, keeping the tail intact
do
	fs.Write(Handle, "world", 0)
	fs.Write(Handle, "XY", 1)
	assert(fs.Read(Handle) == "wXYld", "Write with an offset should overwrite only the targeted region")
end

fs.Close(Handle)

return "OK"
