local fs = require("@osiris/fs")

fs.CreateFile("./exclusive_lock_a.txt")

-- Exclusive opens lock the file against further opens until Close releases the lock
do
	local First = fs.Open("./exclusive_lock_a.txt", true)
	assert(First ~= nil, "the first exclusive open should succeed")

	local Second, Err = fs.Open("./exclusive_lock_a.txt")
	assert(Second == nil, "a second open should fail while the file is exclusively locked")
	assert(Err ~= "", "a failed Open should report a non-empty error message")

	fs.Close(First)

	local Third = fs.Open("./exclusive_lock_a.txt")
	assert(Third ~= nil, "closing the exclusive handle should release the lock")
	fs.Close(Third)
end

-- A non-exclusive open does not lock the file
do
	local First = fs.Open("./exclusive_lock_a.txt")
	assert(First ~= nil, "a plain open should succeed")

	local Second = fs.Open("./exclusive_lock_a.txt")
	assert(Second ~= nil, "a non-exclusive open should not block further opens")

	fs.Close(First)
	fs.Close(Second)
end

return "OK"
