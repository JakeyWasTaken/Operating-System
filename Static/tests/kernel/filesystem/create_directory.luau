local fs = require("@osiris/fs")

-- CreateDirectory creates missing intermediate directories
do
	assert(fs.CreateDirectory("./create_directory_a/nested"), "CreateDirectory should create missing intermediate directories")
	assert(fs.CreateFile("./create_directory_a/nested/leaf.txt"), "should be able to create a file inside a freshly created directory")
end

-- CreateDirectory is idempotent
do
	assert(fs.CreateDirectory("./create_directory_a/nested"), "creating an already-existing directory should still succeed")
end

-- CreateDirectory fails when a path component above the leaf is a file
do
	assert(fs.CreateFile("./create_directory_b.txt"), "setup: create a file")
	assert(fs.CreateDirectory("./create_directory_b.txt/inner") == false, "CreateDirectory should fail when a path component is a file")
end

return "OK"
