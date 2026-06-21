local function errors(fn, ...): boolean
	local Ok = pcall(fn, ...)
	return Ok == false
end

-- create/len, and reads default to zero before anything is written
do
	local b = buffer.create(16)
	assert(buffer.len(b) == 16, "buffer.len should report the size passed to buffer.create")
	assert(buffer.readi8(b, 0) == 0, "an unwritten buffer byte should read back as zero")
end

-- 8/16/32-bit signed and unsigned integers round-trip, including how
-- signed vs unsigned interpretation of the same bytes differs
do
	local b = buffer.create(32)

	buffer.writei8(b, 0, -1)
	assert(buffer.readi8(b, 0) == -1, "readi8 should interpret the byte as signed")
	assert(buffer.readu8(b, 0) == 255, "readu8 should interpret the same byte as unsigned")

	buffer.writei16(b, 2, -1)
	assert(buffer.readi16(b, 2) == -1, "readi16 should interpret the bytes as signed")
	assert(buffer.readu16(b, 2) == 65535, "readu16 should interpret the same bytes as unsigned")

	buffer.writeu32(b, 4, 0xffffffff)
	assert(buffer.readi32(b, 4) == -1, "readi32 should interpret the bytes as signed")
	assert(buffer.readu32(b, 4) == 4294967295, "readu32 should interpret the same bytes as unsigned")
end

-- float round-trips
do
	local b = buffer.create(16)

	buffer.writef32(b, 0, 1.5)
	assert(buffer.readf32(b, 0) == 1.5, "a 32-bit float should round-trip exactly for a simple value like 1.5")

	buffer.writef64(b, 8, 1.0 / 3.0)
	assert(buffer.readf64(b, 8) == 1.0 / 3.0, "a 64-bit float should round-trip exactly")
end

-- string read/write, including an explicit length and an overwrite
do
	local b = buffer.create(32)
	buffer.writestring(b, 0, "hello world")
	assert(buffer.readstring(b, 0, 11) == "hello world", "writestring/readstring should round-trip a plain string")

	buffer.writestring(b, 0, "HELLO", 3) -- only copy the first 3 bytes
	assert(buffer.readstring(b, 0, 11) == "HELlo world", "writestring with an explicit length should only overwrite that many bytes")
end

-- copy between two buffers, and within the same buffer (overlap-safe)
do
	local a = buffer.create(16)
	local b = buffer.create(16)
	buffer.writestring(a, 0, "abcdef")

	buffer.copy(b, 0, a, 0, 6)
	assert(buffer.readstring(b, 0, 6) == "abcdef", "buffer.copy should copy bytes from one buffer into another")

	buffer.copy(a, 2, a, 0, 4) -- overlapping shift within the same buffer
	assert(buffer.readstring(a, 0, 6) == "ababcd", "buffer.copy within the same buffer should handle an overlapping range correctly")
end

-- fill stamps a single byte value across a range
do
	local b = buffer.create(8)
	buffer.fill(b, 0, 0x61) -- 'a'
	assert(buffer.readstring(b, 0, 8) == "aaaaaaaa", "buffer.fill with no length should fill to the end of the buffer")

	buffer.fill(b, 2, 0x62, 3) -- 'b' x3 starting at offset 2
	assert(buffer.readstring(b, 0, 8) == "aabbbaaa", "buffer.fill with an explicit length should only fill that many bytes")
end

-- fromstring/tostring round-trip, including embedded NUL bytes
do
	local b = buffer.fromstring("a\0b")
	assert(buffer.len(b) == 3, "buffer.fromstring should size the buffer to the string's byte length, including embedded NULs")
	assert(buffer.tostring(b) == "a\0b", "buffer.tostring should round-trip a string with an embedded NUL byte")
end

-- out-of-bounds access is a catchable error, not a crash
do
	local b = buffer.create(4)
	assert(errors(function()
		buffer.readi8(b, 4)
	end), "reading one byte past the end of the buffer should be out of bounds")
	assert(errors(function()
		buffer.readi8(b, -1)
	end), "reading at a negative offset should be out of bounds")
	assert(errors(function()
		buffer.writei32(b, 1, 0)
	end), "writing a 4-byte value that overruns the buffer should be out of bounds")
end

-- bit-level reads/writes
do
	local b = buffer.create(4)
	buffer.writebits(b, 0, 4, 0b1010)
	assert(buffer.readbits(b, 0, 4) == 0b1010, "writebits/readbits should round-trip a 4-bit field")

	buffer.writebits(b, 4, 4, 0b0101)
	assert(buffer.readu8(b, 0) == 0b01011010, "two adjacent 4-bit fields should combine into the expected byte")
end

return "OK"
