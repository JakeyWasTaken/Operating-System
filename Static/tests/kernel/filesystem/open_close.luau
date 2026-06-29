local fs = require("@osiris/fs")

fs.CreateFile("./open_close_a.txt")
local Setup = fs.Open("./open_close_a.txt")
assert(Setup ~= nil, "setup: open the file to write its initial contents")
fs.Write(Setup, "hello", 0)
fs.Close(Setup)

-- Open resolves an existing file relative to the working directory
do
	local Opened = fs.Open("./open_close_a.txt")
	assert(Opened ~= nil, "Open should resolve a path relative to the working directory")
	assert(fs.Read(Opened) == "hello", "Open should hand back the same file that was written to during setup")
	fs.Close(Opened)
end

-- Open fails for a path that doesn't exist
do
	local Handle, Err = fs.Open("./does_not_exist.txt")
	assert(Handle == nil, "Open should fail for a file that doesn't exist")
	assert(Err ~= "", "a failed Open should report a non-empty error message")
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

	local Data, Err = fs.Read(Opened)
	assert(Data == nil, "reading a closed handle should fail")
	assert(Err ~= "", "a failed Read should report a non-empty error message")
end

return "OK"
