-- __index as a table (fallback lookup) and as a function (computed fallback)
do
	local Base = { greeting = "hi" }
	local Derived = setmetatable({}, { __index = Base })
	assert(Derived.greeting == "hi", "__index table fallback should read through to the base table")

	Derived.greeting = "yo" -- shadows the base, doesn't write through it
	assert(Derived.greeting == "yo", "writing to the derived table should shadow the base, not write through it")
	assert(Base.greeting == "hi", "writing to the derived table should not mutate the base table")

	local Computed = setmetatable({}, {
		__index = function(_, key)
			return `missing:{key}`
		end,
	})
	assert(Computed.anything == "missing:anything", "__index function fallback should compute a value for missing keys")
end

-- __newindex as a function intercepts writes to absent keys entirely
do
	local Log = {}
	local Proxy = setmetatable({}, {
		__newindex = function(_, key, value)
			table.insert(Log, `{key}={value}`)
		end,
	})

	Proxy.a = 1
	Proxy.b = 2
	assert(rawequal(rawget(Proxy, "a"), nil), "__newindex function should intercept the write, not actually store it") -- never actually stored
	assert(#Log == 2 and Log[1] == "a=1" and Log[2] == "b=2", "__newindex should have logged both intercepted writes in order")
end

-- __call lets a table be invoked like a function
do
	local Adder = setmetatable({ base = 10 }, {
		__call = function(self, n)
			return self.base + n
		end,
	})
	assert(Adder(5) == 15, "__call should let the table be invoked like a function")
end

-- __tostring controls tostring() and string coercion
do
	local Point = setmetatable({ x = 1, y = 2 }, {
		__tostring = function(self)
			return `({self.x}, {self.y})`
		end,
	})
	assert(tostring(Point) == "(1, 2)", "tostring() should use __tostring")
	assert(`{Point}` == "(1, 2)", "string interpolation should use __tostring for coercion")
end

-- arithmetic and comparison metamethods, including mixed-type __add
do
	-- Unlike Lua 5.1 (which checks each operand's metatable independently),
	-- Luau only invokes __eq if both operands share the EXACT SAME
	-- metatable. So this has to be built once and reused by every vec(...)
	-- instance - a fresh `{ __eq = ... }` table literal per call would give
	-- every vector its own distinct metatable, and == would never even
	-- consider __eq for two separately-constructed vectors.
	local VecMeta = {}

	local function vec(x: number, y: number)
		return setmetatable({ x = x, y = y }, VecMeta)
	end

	VecMeta.__add = function(a, b)
		return vec(a.x + b.x, a.y + b.y)
	end
	VecMeta.__unm = function(a)
		return vec(-a.x, -a.y)
	end
	VecMeta.__eq = function(a, b)
		return a.x == b.x and a.y == b.y
	end
	VecMeta.__lt = function(a, b)
		return (a.x * a.x + a.y * a.y) < (b.x * b.x + b.y * b.y)
	end
	VecMeta.__concat = function(a, b)
		local sa = type(a) == "table" and `({a.x},{a.y})` or tostring(a)
		local sb = type(b) == "table" and `({b.x},{b.y})` or tostring(b)
		return sa .. sb
	end

	local p1, p2 = vec(1, 2), vec(3, 4)
	local sum = p1 + p2
	assert(sum.x == 4 and sum.y == 6, "__add should combine both vectors componentwise")

	local neg = -p1
	assert(neg.x == -1 and neg.y == -2, "__unm should negate both components")

	assert(vec(1, 2) == vec(1, 2), "__eq should treat structurally-equal vectors as equal")
	assert(not (vec(1, 2) == vec(1, 3)), "__eq should treat structurally-different vectors as unequal")
	assert(vec(1, 1) < vec(5, 5), "__lt should compare vectors by squared magnitude")
	assert(p1 .. "!" == "(1,2)!", "__concat should format the vector when concatenated with a string")
end

-- __len overrides the # operator
do
	local Bag = setmetatable({}, {
		__len = function()
			return 42
		end,
	})
	assert(#Bag == 42, "__len should override the # operator")
end

-- rawget/rawset/rawequal bypass metamethods entirely
do
	local Hidden = setmetatable({}, {
		__index = function()
			return "always this"
		end,
		__newindex = function()
			error("should never run")
		end,
	})

	assert(Hidden.anything == "always this", "__index should apply for a normal indexed read")
	assert(rawget(Hidden, "anything") == nil, "rawget should bypass __index and see nothing actually stored")

	rawset(Hidden, "real", 1)
	assert(rawget(Hidden, "real") == 1, "rawset should store the value without going through __newindex")
	assert(Hidden.real == 1, "once a key is actually present, __index should never be consulted for it") -- present now, so __index fallback never triggers
end

-- getmetatable / setmetatable round-trip, and __metatable locks it
do
	local Meta = { tag = "locked" }
	local Locked = setmetatable({}, Meta)
	assert(getmetatable(Locked) == Meta, "getmetatable should return the exact table passed to setmetatable")

	Meta.__metatable = "nope"
	local Ok = pcall(setmetatable, Locked, {})
	assert(not Ok, "setmetatable should fail once __metatable is set, locking the metatable")
end

return "OK"
