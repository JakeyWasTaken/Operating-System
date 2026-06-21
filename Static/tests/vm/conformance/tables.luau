-- insert/remove, including positional insert and remove-from-middle
do
	local t = { 1, 2, 3 }
	table.insert(t, 4)
	assert(#t == 4 and t[4] == 4, "table.insert with no position should append to the end")

	table.insert(t, 1, 0)
	assert(#t == 5 and t[1] == 0 and t[2] == 1, "table.insert with a position should shift the later entries up")

	local removed = table.remove(t, 2)
	assert(removed == 1 and #t == 4 and t[2] == 2, "table.remove with a position should return that entry and shift later ones down")

	local last = table.remove(t)
	assert(last == 4 and #t == 3, "table.remove with no position should remove and return the last entry")
end

-- concat joins array entries with a separator over a sub-range
do
	local t = { "a", "b", "c", "d" }
	assert(table.concat(t) == "abcd", "table.concat with no separator")
	assert(table.concat(t, ",") == "a,b,c,d", "table.concat with a separator")
	assert(table.concat(t, ",", 2, 3) == "b,c", "table.concat over a sub-range")
end

-- sort, with and without a comparator
do
	local t = { 3, 1, 4, 1, 5, 9, 2, 6 }
	table.sort(t)
	assert(t[1] == 1 and t[2] == 1 and t[#t] == 9, "table.sort with no comparator should sort ascending")

	table.sort(t, function(a, b)
		return a > b
	end)
	assert(t[1] == 9 and t[#t] == 1, "table.sort with a custom comparator should sort descending")
end

-- find locates the first matching value, or nil
do
	local t = { "x", "y", "z" }
	assert(table.find(t, "y") == 2, "table.find should return the index of the first matching value")
	assert(table.find(t, "missing") == nil, "table.find should return nil when the value isn't present")
end

-- clone makes a shallow, independent copy
do
	local Inner = { 1 }
	local t = { a = 1, inner = Inner }
	local Copy = table.clone(t)

	Copy.a = 2
	assert(t.a == 1, "writing a top-level key on the clone should not affect the original") -- top-level write doesn't affect the original

	table.insert(Copy.inner, 2)
	assert(#Inner == 2, "table.clone is shallow, so a nested table should still be shared between the original and the clone") -- shallow: nested tables are shared, not deep-copied
end

-- freeze prevents further mutation and is detectable via isfrozen
do
	local t = { 1, 2, 3 }
	assert(table.isfrozen(t) == false, "a fresh table should not be frozen")

	table.freeze(t)
	assert(table.isfrozen(t) == true, "table.isfrozen should report true once table.freeze has been called")

	local Ok = pcall(function()
		t[1] = 99
	end)
	assert(Ok == false, "writing to a frozen table should be a catchable error")
end

-- pack/unpack round-trip varargs through a table
do
	local Packed = table.pack(1, 2, 3)
	assert(Packed.n == 3 and Packed[1] == 1 and Packed[3] == 3, "table.pack should store the count alongside the packed values")
	assert(table.unpack(Packed, 1, Packed.n) == 1, "table.unpack should return the first value when used in a single-value context")

	local a, b, c = table.unpack({ 10, 20, 30 })
	assert(a == 10 and b == 20 and c == 30, "table.unpack should expand a plain array table back into separate values")
end

-- create makes a pre-sized array, optionally filled with a value
do
	local t = table.create(5, 0)
	assert(#t == 5, "table.create should produce an array of exactly the requested size")
	for _, v in t do
		assert(v == 0, "every entry in a table.create(n, fill) array should be the fill value")
	end
end

-- move shifts/copies a range of entries, supporting overlap and a separate destination
do
	local t = { 1, 2, 3, 4, 5 }
	table.move(t, 2, 4, 1)
	assert(t[1] == 2 and t[2] == 3 and t[3] == 4, "table.move within the same table should correctly handle an overlapping range")

	local Dest = {}
	table.move({ "a", "b", "c" }, 1, 3, 1, Dest)
	assert(Dest[1] == "a" and Dest[3] == "c", "table.move with an explicit destination table should copy into it")
end

return "OK"
