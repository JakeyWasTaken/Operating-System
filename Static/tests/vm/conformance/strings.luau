-- basic indexing, length, case conversion
assert(string.len("hello") == 5, "string.len")
assert(("hello"):upper() == "HELLO", "string.upper via method sugar")
assert(("HELLO"):lower() == "hello", "string.lower via method sugar")
assert(string.sub("hello world", 1, 5) == "hello", "string.sub with a positive range")
assert(string.sub("hello world", -5) == "world", "string.sub with a negative start index")
assert(string.byte("A") == 65, "string.byte")
assert(string.char(65, 66, 67) == "ABC", "string.char")
assert(string.rep("ab", 3) == "ababab", "string.rep")
assert(string.reverse("hello") == "olleh", "string.reverse")

-- find / match with plain patterns and character classes
do
	local s, e = string.find("hello world", "world")
	assert(s == 7 and e == 11, "string.find should return the start and end indices of the match")

	assert(string.find("hello", "xyz") == nil, "string.find should return nil when there's no match")

	local digits = string.match("room 237", "%d+")
	assert(digits == "237", "string.match should return the matched substring")

	local word, num = string.match("item42", "(%a+)(%d+)")
	assert(word == "item" and num == "42", "string.match should return each capture separately")
end

-- gmatch iterates every match
do
	local words = {}
	for w in string.gmatch("the quick brown fox", "%a+") do
		table.insert(words, w)
	end
	assert(#words == 4 and words[1] == "the" and words[4] == "fox", "string.gmatch should yield every match in order")
end

-- gsub substitutes, with and without a replacement count limit, and
-- supports captures via %1 etc, and function replacements
do
	local result, count = string.gsub("hello world", "o", "0")
	assert(result == "hell0 w0rld" and count == 2, "string.gsub with no limit should replace every match")

	local limited, limitedCount = string.gsub("aaaa", "a", "b", 2)
	assert(limited == "bbaa" and limitedCount == 2, "string.gsub with a limit should stop after that many replacements")

	local swapped = string.gsub("John Smith", "(%a+) (%a+)", "%2 %1")
	assert(swapped == "Smith John", "string.gsub replacement string should be able to reorder captures via %1/%2")

	local upped = string.gsub("hello", "%a", function(c)
		return c:upper()
	end)
	assert(upped == "HELLO", "string.gsub should accept a function replacement")
end

-- string.format covers the common specifiers
assert(string.format("%d", 42) == "42", "string.format %d")
assert(string.format("%5d", 42) == "   42", "string.format %d with a minimum field width")
assert(string.format("%-5d|", 42) == "42   |", "string.format %d with left-justification")
assert(string.format("%.2f", 3.14159) == "3.14", "string.format %f with a precision")
assert(string.format("%s and %s", "a", "b") == "a and b", "string.format %s")
assert(string.format("%x", 255) == "ff", "string.format %x")
assert(string.format("%%") == "%", "string.format %% should produce a literal percent sign")

-- string.split divides on a separator, including the empty-separator case
do
	local parts = string.split("a,b,c", ",")
	assert(#parts == 3 and parts[1] == "a" and parts[2] == "b" and parts[3] == "c", "string.split should divide on the given separator")

	local chars = string.split("abc", "")
	assert(#chars == 3 and chars[1] == "a" and chars[3] == "c", "string.split with an empty separator should split into individual characters")
end

-- pattern special characters need escaping with %
do
	local escaped = string.find("3.14", "%.")
	assert(escaped == 2, "%. should match a literal dot, not 'any character'")
end

-- methods work via the string metatable (`("x"):method()` sugar)
assert(("hello world"):find("world") == 7, "method-call sugar should work on string literals")
assert(("  trim me  "):gsub("^%s+", ""):gsub("%s+$", "") == "trim me", "chained gsub calls should be able to trim both leading and trailing whitespace")

return "OK"
