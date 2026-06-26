local fs = require("@osiris/fs")

fs.CreateFile("./metadata_a.txt")
local Handle = fs.Open("./metadata_a.txt")
assert(Handle ~= nil, "setup: open the file to inspect")

-- GetMetadata reports CreatedAt and UpdatedAt
do
	local Metadata = fs.GetMetadata(Handle)
	assert(Metadata ~= nil, "GetMetadata should return metadata for an open handle")
	assert(Metadata.CreatedAt ~= nil, "files should report a CreatedAt timestamp")
	assert(Metadata.UpdatedAt ~= nil, "files should report an UpdatedAt timestamp")
end

-- Writing bumps UpdatedAt
do
	local Before = fs.GetMetadata(Handle)
	fs.Write(Handle, "hello", 0)
	local After = fs.GetMetadata(Handle)

	assert(After.UpdatedAt >= Before.UpdatedAt, "writing should bump UpdatedAt")
end

fs.Close(Handle)

return "OK"
