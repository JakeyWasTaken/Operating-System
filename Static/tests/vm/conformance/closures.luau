-- a closure captures its upvalue by reference, not by value
local function makeCounter()
	local count = 0
	return function()
		count += 1
		return count
	end
end

local counter1 = makeCounter()
local counter2 = makeCounter()
assert(counter1() == 1, "counter1 first call")
assert(counter1() == 2, "counter1 second call should see its own incremented upvalue")
assert(counter1() == 3, "counter1 third call should keep incrementing the same upvalue")
assert(counter2() == 1, "counter2 should have its own independent upvalue, not share counter1's") -- independent upvalue, not shared with counter1

-- two closures sharing the SAME upvalue see each other's writes
local function makePair()
	local shared = 0
	local function get()
		return shared
	end
	local function set(v: number)
		shared = v
	end
	return get, set
end

local get, set = makePair()
assert(get() == 0, "get() should see the initial value of the shared upvalue")
set(42)
assert(get() == 42, "get() should see set()'s write, since both closures share the same upvalue")

-- the classic loop-variable-capture footgun: Luau's numeric/generic for
-- creates a FRESH local per iteration, so each closure should capture its
-- own value, not all end up pointing at the same final one.
local fns = {}
for i = 1, 3 do
	fns[i] = function()
		return i
	end
end
assert(fns[1]() == 1, "closure from iteration 1 should capture its own loop variable, not the final value")
assert(fns[2]() == 2, "closure from iteration 2 should capture its own loop variable, not the final value")
assert(fns[3]() == 3, "closure from iteration 3 should capture its own loop variable, not the final value")

-- recursive local function (the `local function` sugar pre-declares the
-- name so the function can call itself)
local function fib(n: number): number
	if n < 2 then
		return n
	end
	return fib(n - 1) + fib(n - 2)
end
assert(fib(10) == 55, "local function should be able to call itself recursively")

-- mutual recursion via forward-declared locals
local isEven, isOdd

function isEven(n: number): boolean
	if n == 0 then
		return true
	end
	return isOdd(n - 1)
end

function isOdd(n: number): boolean
	if n == 0 then
		return false
	end
	return isEven(n - 1)
end

assert(isEven(10) == true, "mutual recursion: isEven(10)")
assert(isOdd(10) == false, "mutual recursion: isOdd(10)")
assert(isOdd(7) == true, "mutual recursion: isOdd(7)")

-- a closure that outlives the scope it was created in still keeps its upvalues alive
local function makeAccumulator()
	local items = {}
	return function(v: number)
		table.insert(items, v)
		return #items
	end
end

local accumulate = makeAccumulator()
assert(accumulate(1) == 1, "accumulator first insert")
assert(accumulate(2) == 2, "accumulator second insert should see the first one still in its upvalue table")
assert(accumulate(3) == 3, "accumulator third insert should see both previous ones still in its upvalue table")

return "OK"
