-- ipairs stops at the first nil, regardless of what comes after
do
	local t = { 1, 2, 3 }
	t[5] = 5

	local seen = {}
	for i, v in ipairs(t) do
		seen[i] = v
	end
	assert(#seen == 3 and seen[1] == 1 and seen[2] == 2 and seen[3] == 3, "ipairs should stop at the first nil and ignore the entry at index 5")
end

-- pairs visits every key, array or not, in some order
do
	local t = { a = 1, b = 2, c = 3 }
	local count, sum = 0, 0
	for k, v in pairs(t) do
		count += 1
		sum += v
		assert(t[k] == v, "each key/value pair yielded by pairs should match the table's own contents")
	end
	assert(count == 3 and sum == 6, "pairs should visit every key exactly once")
end

-- generic `for` directly over a table (Luau's generalized iteration) should
-- behave like pairs() for plain tables
do
	local t = { 10, 20, 30 }
	local sum = 0
	for _, v in t do
		sum += v
	end
	assert(sum == 60, "generalized iteration over a plain table should behave like pairs()")
end

-- next() manually walks a table the same way pairs() does internally
do
	local t = { x = 1 }
	local k, v = next(t)
	assert(k == "x" and v == 1, "next() with no key should return the first key/value pair")
	assert(next(t, k) == nil, "next() with the last key should return nil")
	assert(next({}) == nil, "next() on an empty table should return nil")
end

-- a table with __iter is iterated via that metamethod, not raw next()
do
	local function range(n: number)
		return setmetatable({}, {
			__iter = function()
				local i = 0
				return function()
					i += 1
					if i <= n then
						return i, i * i
					end
					return nil
				end
			end,
		})
	end

	local squares = {}
	for i, sq in range(4) do
		squares[i] = sq
	end
	assert(squares[1] == 1 and squares[2] == 4 and squares[3] == 9 and squares[4] == 16, "generalized iteration should use __iter instead of raw next() when present")
end

-- stateless iterator protocol: `for ... in f, s, var` calls f(s, var) each step
do
	local function iter(arr: { number }, i: number)
		i += 1
		if arr[i] then
			return i, arr[i]
		end
		return nil
	end

	local arr = { "a", "b", "c" }
	local got = {}
	for i, v in iter, arr, 0 do
		got[i] = v
	end
	assert(got[1] == "a" and got[2] == "b" and got[3] == "c", "the stateless iterator protocol should call iter(arr, i) each step")
end

return "OK"
