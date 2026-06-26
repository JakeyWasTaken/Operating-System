local fs = require("@osiris/fs")

-- Delete removes a directory along with its descendants
do
	fs.CreateDirectory("./delete_directory_a/inner")
	fs.CreateFile("./delete_directory_a/inner/leaf.txt")

	local Ok = fs.Delete("./delete_directory_a")
	assert(Ok, "Delete should remove a directory along with its descendants")

	local Handle = fs.Open("./delete_directory_a/inner/leaf.txt")
	assert(Handle == nil, "files under a deleted directory should no longer resolve")
end

-- Delete fails when a descendant is still open exclusively
do
	fs.CreateDirectory("./delete_directory_b")
	fs.CreateFile("./delete_directory_b/leaf.txt")

	local Locked = fs.Open("./delete_directory_b/leaf.txt", true)
	assert(Locked ~= nil, "setup: exclusively open the descendant")

	local Ok, Err = fs.Delete("./delete_directory_b")
	assert(not Ok, "Delete should fail while a descendant is exclusively locked")
	assert(Err ~= "", "a failed Delete should report a non-empty error message")

	fs.Close(Locked)

	Ok = fs.Delete("./delete_directory_b")
	assert(Ok, "Delete should succeed once the descendant's lock is released")
end

return "OK"
