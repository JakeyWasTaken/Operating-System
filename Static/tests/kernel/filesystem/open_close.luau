local fs = require("@osiris/fs")

assert(fs.CreateFile("./open_close_a.txt"), "setup: create a file to open")
local Setup = fs.Open("./open_close_a.txt")
assert(Setup ~= nil, "setup: open the file to write its initial contents")
fs.Write(Setup, "hello", 0)
fs.Close(Setup)

-- Open resolves an existing file relative to the script's own location
do
	local Opened = fs.Open("./open_close_a.txt")
	assert(Opened ~= nil, "Open should resolve a path relative to the script")
	assert(fs.Read(Opened) == "hello", "Open should hand back the same file that was written to during setup")
	fs.Close(Opened)
end

-- Open fails for a path that doesn't exist
do
	assert(fs.Open("./does_not_exist.txt") == nil, "Open should fail for a file that doesn't exist")
end

-- Re-opening the same file from the same process reuses the same scoped handle
do
	local A = fs.Open("./open_close_a.txt")
	local B = fs.Open("./open_close_a.txt")
	assert(A == B, "opening the same file twice from one process should hand back the same scoped handle")
	fs.Close(A)
end

-- Operating on a handle after it has been closed should not silently succeed
do
	local Opened = fs.Open("./open_close_a.txt")
	fs.Close(Opened)
	assert(fs.Read(Opened) == nil, "reading a closed handle should fail")
end

return "OK"
