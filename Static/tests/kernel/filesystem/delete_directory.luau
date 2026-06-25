local fs = require("@osiris/fs")

-- Delete removes a directory along with its descendants
do
	assert(fs.CreateDirectory("./delete_directory_a/inner"), "setup: create nested directories")
	assert(fs.CreateFile("./delete_directory_a/inner/leaf.txt"), "setup: create a file inside the nested directory")

	assert(fs.Delete("./delete_directory_a"), "Delete should remove a directory along with its descendants")
	assert(fs.Open("./delete_directory_a/inner/leaf.txt") == nil, "files under a deleted directory should no longer resolve")
end

-- Delete fails when a descendant is still open exclusively
do
	assert(fs.CreateDirectory("./delete_directory_b"), "setup: create a directory")
	assert(fs.CreateFile("./delete_directory_b/leaf.txt"), "setup: create a file inside the directory")

	local Locked = fs.Open("./delete_directory_b/leaf.txt", true)
	assert(Locked ~= nil, "setup: exclusively open the descendant")

	assert(fs.Delete("./delete_directory_b") == false, "Delete should fail while a descendant is exclusively locked")

	fs.Close(Locked)
	assert(fs.Delete("./delete_directory_b"), "Delete should succeed once the descendant's lock is released")
end

return "OK"
