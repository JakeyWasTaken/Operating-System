-- character classes
assert(string.match("abc123", "%a+") == "abc", "%%a should match letters")
assert(string.match("abc123", "%d+") == "123", "%%d should match digits")
assert(string.match("  hi", "%s+") == "  ", "%%s should match whitespace")
assert(string.match("abc123", "%w+") == "abc123", "%%w should match alphanumeric characters") -- alphanumeric
assert(string.match("hello, world!", "%p") == ",", "%%p should match punctuation") -- punctuation
assert(string.match("HELLOlower", "%u+") == "HELLO", "%%u should match uppercase letters")
assert(string.match("HELLOlower", "%l+") == "lower", "%%l should match lowercase letters")
assert(string.match("0xFF", "%x+") == "0", "%%x should match hex digits and stop at the non-hex 'x'") -- hex digits, stops at 'x'

-- negated classes
assert(string.match("abc123", "%D+") == "abc", "%%D should match non-digits") -- non-digit
assert(string.match("abc 123", "%S+") == "abc", "%%S should match non-whitespace") -- non-space

-- anchors: ^ and $
assert(string.match("hello world", "^hello") == "hello", "^ should anchor the match to the start of the string")
assert(string.match("hello world", "world$") == "world", "$ should anchor the match to the end of the string")
assert(string.match("hello world", "^world") == nil, "^ anchor should fail if the match isn't actually at the start")
assert(string.find("hello", "^hello$") == 1, "^...$ should match when the pattern covers the whole string")
assert(string.find("hello!", "^hello$") == nil, "^...$ should fail when there are trailing characters after the pattern")

-- quantifiers: * + - ?
assert(string.match("aaa", "a*") == "aaa", "* should greedily match as many repetitions as possible")
assert(string.match("", "a*") == "", "* should match zero occurrences on an empty string") -- * matches zero or more
assert(string.match("aaa", "a+") == "aaa", "+ should match one or more repetitions")
assert(string.match("color", "colou?r") == "color", "? should allow zero occurrences of the preceding character")
assert(string.match("colour", "colou?r") == "colour", "? should allow one occurrence of the preceding character")

-- - is the lazy/shortest-match quantifier, unlike the greedy *
do
	local greedy = string.match("<a><b>", "<.*>")
	assert(greedy == "<a><b>", "* should greedily match across both bracketed groups")

	local lazy = string.match("<a><b>", "<.->")
	assert(lazy == "<a>", "- should lazily match only up to the first closing bracket")
end

-- character sets, including ranges and negation
assert(string.match("hello123", "[a-z]+") == "hello", "a character range [a-z] should match lowercase letters")
assert(string.match("hello123", "[0-9]+") == "123", "a character range [0-9] should match digits")
assert(string.match("a1b2c3", "[^0-9]+") == "a", "a negated set [^0-9] should match non-digits")
assert(string.match("hello-world", "[%a%-]+") == "hello-world", "a set can mix a character class and an escaped literal character")

-- captures, including multiple and nested
do
	local key, value = string.match("name=value", "(%a+)=(%a+)")
	assert(key == "name" and value == "value", "two captures should be returned as two separate values")

	local whole, inner = string.match("(nested)", "((%a+))")
	assert(whole == "nested" and inner == "nested", "nested capture groups should both be returned, covering the same matched text")
end

-- position captures (empty parens capture the byte index instead of text)
do
	local pos = string.match("hello world", "()world")
	assert(pos == 7, "an empty capture () should yield the byte position instead of matched text")
end

-- backreferences within a pattern via %1 etc
assert(string.match("abcabc", "(abc)%1") == "abc", "%%1 should require the same text to repeat immediately")
assert(string.find("hello", "(l)%1") ~= nil, "%%1 should match a repeated single character, like the 'll' in hello") -- "ll" - same letter twice in a row

-- balanced match %b for matching delimiter pairs, including nesting
do
	assert(string.match("(foo(bar)baz)", "%b()") == "(foo(bar)baz)", "%%b() should match a balanced pair, correctly handling nested parens")
	assert(string.match("[a[b]c]", "%b[]") == "[a[b]c]", "%%b[] should match a balanced pair, correctly handling nested brackets")
end

-- frontier pattern %f matches a transition between character classes
do
	local count = 0
	for _ in string.gmatch("THE (quick) fox", "%f[%a]%u+%f[%A]") do
		count += 1
	end
	assert(count == 1, "%%f should only match a fully-uppercase word at a word boundary, not 'quick' or 'fox'") -- only "THE" is an all-caps word at a word boundary
end

-- %0 in gsub refers to the whole match, not just a capture
do
	local result = string.gsub("hello", "l+", "[%0]")
	assert(result == "he[ll]o", "%%0 in a gsub replacement should refer to the whole match, not a numbered capture")
end

-- escaping magic characters with %
do
	assert(string.find("3.14", "%.") == 2, "%%. should match a literal dot")
	assert(string.find("a(b)c", "%(b%)") == 2, "%%( and %%) should match literal parentheses")
	assert(string.match("50%", "%d+%%") == "50%", "%%%% should match a literal percent sign")
end

-- gmatch with captures yields each capture group per iteration
do
	local pairs_found = {}
	for k, v in string.gmatch("a=1,b=2,c=3", "(%a)=(%d)") do
		pairs_found[k] = tonumber(v)
	end
	assert(pairs_found.a == 1 and pairs_found.b == 2 and pairs_found.c == 3, "gmatch should yield both captures for every match in the string")
end

return "OK"
