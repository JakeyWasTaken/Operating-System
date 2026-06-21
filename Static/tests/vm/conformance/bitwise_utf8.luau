-- bit32: basic ops
assert(bit32.band(0xff, 0x0f) == 0x0f, "bit32.band")
assert(bit32.bor(0xf0, 0x0f) == 0xff, "bit32.bor")
assert(bit32.bxor(0xff, 0x0f) == 0xf0, "bit32.bxor")
assert(bit32.bnot(0) == 0xffffffff, "bit32.bnot")
assert(bit32.lshift(1, 4) == 16, "bit32.lshift")
assert(bit32.rshift(256, 4) == 16, "bit32.rshift")
assert(bit32.arshift(-8, 1) == 0xfffffffc, "bit32.arshift should sign-extend instead of zero-filling") -- arithmetic shift sign-extends

-- bit32: field extraction/replacement
assert(bit32.extract(0b1011, 0, 4) == 0b1011, "bit32.extract should pull out the requested bit field")
assert(bit32.extract(0b1011, 1, 2) == 0b01, "bit32.extract with a field offset and width")
assert(bit32.replace(0b0000, 0b11, 0, 2) == 0b0011, "bit32.replace should write the given bits into the field")

-- bit32: rotation wraps bits around instead of dropping them
assert(bit32.lrotate(0x1, 4) == 0x10, "bit32.lrotate should wrap bits around instead of dropping them")
assert(bit32.rrotate(0x10, 4) == 0x1, "bit32.rrotate should wrap bits around instead of dropping them")

-- bit32: countlz/countrz
assert(bit32.countlz(0x1) == 31, "bit32.countlz should count leading zero bits")
assert(bit32.countrz(0x80000000) == 31, "bit32.countrz should count trailing zero bits")
assert(bit32.countrz(0) == 32, "bit32.countrz of zero should be defined as the full bit width")

-- utf8: length counts codepoints, not bytes
assert(utf8.len("hello") == 5, "utf8.len on plain ASCII should equal the byte length")
assert(utf8.len("h\xC3\xA9llo") == 5, "utf8.len should count a multibyte codepoint as one character") -- "héllo" - 1 multibyte codepoint, still counts as 1
assert(#"h\xC3\xA9llo" == 6, "the raw byte length should be longer than the codepoint count for multibyte text") -- but the byte length is longer

-- utf8: char builds a string from one or more codepoints
assert(utf8.char(104, 101, 108, 108, 111) == "hello", "utf8.char should build a string from a list of codepoints")

-- utf8: codepoint decodes back to numeric codepoint(s)
do
	local cp = utf8.codepoint("A")
	assert(cp == 65, "utf8.codepoint on a single character")

	local a, b, c = utf8.codepoint("ABC", 1, 3)
	assert(a == 65 and b == 66 and c == 67, "utf8.codepoint over a byte range should return every codepoint in it")
end

-- utf8: codes iterates (bytePosition, codepoint) pairs
do
	local total, count = 0, 0
	for pos, cp in utf8.codes("ABC") do
		count += 1
		total += cp
	end
	assert(count == 3 and total == 65 + 66 + 67, "utf8.codes should iterate every codepoint exactly once")
end

-- utf8: offset finds the byte position of the nth codepoint
assert(utf8.offset("hello", 3) == 3, "utf8.offset on ASCII text should match the plain character index")

return "OK"
