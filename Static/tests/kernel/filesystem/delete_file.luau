local fs = require("@osiris/fs")

-- Delete removes a file so it can no longer be opened
do
	assert(fs.CreateFile("./delete_file_a.txt"), "setup: create a file")

	assert(fs.Delete("./delete_file_a.txt"), "Delete should succeed for an unlocked file")
	assert(fs.Open("./delete_file_a.txt") == nil, "a deleted file should no longer be openable")
end

-- Delete fails while the file is exclusively locked, and succeeds once released
do
	assert(fs.CreateFile("./delete_file_b.txt"), "setup: create a file")

	local Locked = fs.Open("./delete_file_b.txt", true)
	assert(Locked ~= nil, "setup: exclusively open the file")
	assert(fs.Delete("./delete_file_b.txt") == false, "Delete should fail while the file is exclusively locked")

	fs.Close(Locked)
	assert(fs.Delete("./delete_file_b.txt"), "Delete should succeed once the lock is released")
end

-- Delete fails for a path that doesn't exist
do
	assert(fs.Delete("./does_not_exist.txt") == false, "Delete should fail for a path that doesn't exist")
end

return "OK"
