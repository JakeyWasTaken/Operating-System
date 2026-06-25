local fs = require("@osiris/fs")

-- CreateFile creates a new file; Open is needed afterwards to get a usable handle
do
	assert(fs.CreateFile("./create_file_a.txt"), "CreateFile should succeed for a new file")

	local Handle = fs.Open("./create_file_a.txt")
	assert(Handle ~= nil, "should be able to open the freshly created file")

	fs.Write(Handle, "hello", 0)
	assert(fs.Read(Handle) == "hello", "the freshly created file should be empty and writable")

	fs.Close(Handle)
end

-- CreateFile fails when the file already exists
do
	assert(fs.CreateFile("./create_file_a.txt") == false, "CreateFile should fail when the file already exists")
end

-- CreateFile fails when the parent directory doesn't exist
do
	assert(fs.CreateFile("./missing_dir/leaf.txt") == false, "CreateFile should fail when the parent directory doesn't exist")
end

return "OK"
