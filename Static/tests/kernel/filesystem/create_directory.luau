local fs = require("@osiris/fs")

-- CreateDirectory creates missing intermediate directories
do
	local Ok = fs.CreateDirectory("./create_directory_a/nested")
	assert(Ok, "CreateDirectory should create missing intermediate directories")

	assert(fs.CreateFile("./create_directory_a/nested/leaf.txt"), "should be able to create a file inside a freshly created directory")

	local Handle = fs.Open("./create_directory_a/nested/leaf.txt")
	assert(Handle ~= nil, "should be able to open a file inside a freshly created directory")
	fs.Close(Handle)
end

-- CreateDirectory is idempotent
do
	local Ok = fs.CreateDirectory("./create_directory_a/nested")
	assert(Ok, "creating an already-existing directory should still succeed")
end

-- CreateDirectory fails when a path component above the leaf is a file
do
	assert(fs.CreateFile("./create_directory_b.txt"), "setup: create a file")

	local Ok, Err = fs.CreateDirectory("./create_directory_b.txt/inner")
	assert(not Ok, "CreateDirectory should fail when a path component is a file")
	assert(Err ~= "", "a failed CreateDirectory should report a non-empty error message")
end

return "OK"
