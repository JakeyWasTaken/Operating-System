local fs = require("@osiris/fs")

-- CreateFile creates a new file; Open is needed afterwards to get a usable handle
do
	local Ok = fs.CreateFile("./create_file_a.txt")
	assert(Ok, "CreateFile should succeed for a new file")

	local Handle = fs.Open("./create_file_a.txt")
	assert(Handle ~= nil, "should be able to open the freshly created file")

	fs.Write(Handle, "hello", 0)
	assert(fs.Read(Handle) == "hello", "the freshly created file should be empty and writable")

	fs.Close(Handle)
end

-- CreateFile fails when the file already exists
do
	local Ok, Err = fs.CreateFile("./create_file_a.txt")
	assert(not Ok, "CreateFile should fail when the file already exists")
	assert(Err ~= "", "a failed CreateFile should report a non-empty error message")
end

-- CreateFile fails when the parent directory doesn't exist
do
	local Ok, Err = fs.CreateFile("./missing_dir/leaf.txt")
	assert(not Ok, "CreateFile should fail when the parent directory doesn't exist")
	assert(Err ~= "", "a failed CreateFile should report a non-empty error message")
end

return "OK"
