-- arithmetic, including integer division and modulo
assert(1 + 2 == 3, "addition")
assert(10 - 3 == 7, "subtraction")
assert(4 * 5 == 20, "multiplication")
assert(10 / 4 == 2.5, "division")
assert(10 // 4 == 2, "floor division")
assert(10 % 3 == 1, "modulo")
assert(2 ^ 10 == 1024, "exponentiation")
assert(-5 // 2 == -3, "floor division should round toward negative infinity, not truncate toward zero")

-- comparisons and boolean logic
assert(1 < 2 and 2 <= 2 and 3 > 2 and 3 >= 3, "ordering comparisons")
assert(1 ~= 2 and 1 == 1, "equality and inequality")
assert((1 == 1) == true, "comparison expressions should evaluate to a real boolean")
assert(not false == true, "logical not")
assert((false and error("short-circuit failed")) == false, "and should short-circuit on a falsy left side")
assert((true or error("short-circuit failed")) == true, "or should short-circuit on a truthy left side")

-- string concatenation and coercion
assert("a" .. "b" == "ab", "string concatenation")
assert(1 .. 2 == "12", "numbers should coerce to strings when concatenated")
assert(#"hello" == 5, "string length operator")

-- multiple assignment / multiple returns
local function two()
	return 1, 2
end

local a, b = two()
assert(a == 1 and b == 2, "a multi-return call in tail position should expand to both values")

local c, d, e = two(), 5
assert(c == 1 and d == 5 and e == nil, "a multi-return call NOT in tail position should only contribute its first value") -- only the last call expands

-- varargs
local function sum(...)
	local total = 0
	for _, v in { ... } do
		total += v
	end
	return total, select("#", ...)
end

local total, count = sum(1, 2, 3, 4)
assert(total == 10 and count == 4, "varargs should forward every argument, and select('#', ...) should count them all")

-- control flow: if/elseif/else, while, repeat, numeric for (incl. negative step), continue
local function classify(n: number): string
	if n < 0 then
		return "negative"
	elseif n == 0 then
		return "zero"
	else
		return "positive"
	end
end

assert(classify(-1) == "negative", "if/elseif/else: negative branch")
assert(classify(0) == "zero", "if/elseif/else: zero branch")
assert(classify(1) == "positive", "if/elseif/else: positive (else) branch")

do
	local i, acc = 0, 0
	while i < 5 do
		i += 1
		acc += i
	end
	assert(acc == 15, "while loop should sum 1 through 5")
end

do
	local i, acc = 0, 0
	repeat
		i += 1
		acc += i
	until i >= 5
	assert(acc == 15, "repeat/until loop should sum 1 through 5")
end

do
	local acc = 0
	for i = 1, 10 do
		if i % 2 == 0 then
			continue
		end
		acc += i
	end
	assert(acc == 25, "continue should skip even numbers, leaving only the odd ones summed") -- 1+3+5+7+9
end

do
	local seen = {}
	for i = 10, 1, -2 do
		table.insert(seen, i)
	end
	assert(#seen == 5 and seen[1] == 10 and seen[5] == 2, "numeric for with a negative step should count down correctly")
end

-- if-then-else expressions
local x = 5
assert((if x > 0 then "pos" else "non-pos") == "pos", "if-then-else expression")

-- string interpolation
local name = "world"
assert(`hello {name}!` == "hello world!", "string interpolation should substitute a variable")
assert(`{1 + 1}` == "2", "string interpolation should evaluate an embedded expression")

-- table constructors mixing array and keyed entries
local t = { 1, 2, 3, key = "value", [10] = "ten" }
assert(t[1] == 1 and t[2] == 2 and t[3] == 3, "table constructor array entries")
assert(t.key == "value", "table constructor keyed entry")
assert(t[10] == "ten", "table constructor explicit-index entry")
assert(#t == 3, "the # operator should only count the contiguous array part, not the keyed/explicit-index entries")

return "OK"
