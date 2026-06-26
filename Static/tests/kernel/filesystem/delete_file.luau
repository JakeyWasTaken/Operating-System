local fs = require("@osiris/fs")

-- Delete removes a file so it can no longer be opened
do
	fs.CreateFile("./delete_file_a.txt")

	local Ok = fs.Delete("./delete_file_a.txt")
	assert(Ok, "Delete should succeed for an unlocked file")

	local Handle = fs.Open("./delete_file_a.txt")
	assert(Handle == nil, "a deleted file should no longer be openable")
end

-- Delete fails while the file is exclusively locked, and succeeds once released
do
	fs.CreateFile("./delete_file_b.txt")

	local Locked = fs.Open("./delete_file_b.txt", true)
	assert(Locked ~= nil, "setup: exclusively open the file")

	local Ok, Err = fs.Delete("./delete_file_b.txt")
	assert(not Ok, "Delete should fail while the file is exclusively locked")
	assert(Err ~= "", "a failed Delete should report a non-empty error message")

	fs.Close(Locked)

	Ok = fs.Delete("./delete_file_b.txt")
	assert(Ok, "Delete should succeed once the lock is released")
end

-- Delete fails for a path that doesn't exist
do
	local Ok, Err = fs.Delete("./does_not_exist.txt")
	assert(not Ok, "Delete should fail for a path that doesn't exist")
	assert(Err ~= "", "a failed Delete should report a non-empty error message")
end

return "OK"
