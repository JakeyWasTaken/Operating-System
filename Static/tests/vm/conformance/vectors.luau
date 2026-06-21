-- literal construction (this exact form used to crash before vectorCtor
-- was wired up, since it can get constant-folded)
do
	local v = vector.create(1, 2, 3)
	assert(v.x == 1 and v.y == 2 and v.z == 3, "literal vector.create should construct correctly now that vectorCtor is wired up")
end

-- component access
do
	local v = vector.create(1, 2, 3)
	assert(v.x == 1 and v.y == 2 and v.z == 3, "vector components should be readable via .x/.y/.z")
end

-- arithmetic operators work natively on the vector type, no metatables involved
do
	local a, b = vector.create(1, 2, 3), vector.create(4, 5, 6)

	local sum = a + b
	assert(sum.x == 5 and sum.y == 7 and sum.z == 9, "+ should add vectors componentwise")

	local diff = b - a
	assert(diff.x == 3 and diff.y == 3 and diff.z == 3, "- should subtract vectors componentwise")

	local scaled = a * 2
	assert(scaled.x == 2 and scaled.y == 4 and scaled.z == 6, "* by a scalar should scale every component")

	local negated = -a
	assert(negated.x == -1 and negated.y == -2 and negated.z == -3, "unary - should negate every component")

	assert(vector.create(1, 2, 3) == vector.create(1, 2, 3), "vectors with identical components should compare equal")
	assert(vector.create(1, 2, 3) ~= vector.create(1, 2, 4), "vectors with a different component should compare unequal")
end

-- library functions
do
	local v = vector.create(3, 4, 0)
	assert(vector.magnitude(v) == 5, "vector.magnitude of a 3-4-0 vector should be 5") -- classic 3-4-5 triangle

	local n = vector.normalize(v)
	assert(math.abs(vector.magnitude(n) - 1) < 1e-6, "vector.normalize should produce a unit-length vector")

	assert(vector.dot(vector.create(1, 0, 0), vector.create(0, 1, 0)) == 0, "vector.dot of two perpendicular unit vectors should be 0")
	assert(vector.dot(vector.create(1, 0, 0), vector.create(1, 0, 0)) == 1, "vector.dot of a unit vector with itself should be 1")

	local cross = vector.cross(vector.create(1, 0, 0), vector.create(0, 1, 0))
	assert(cross.x == 0 and cross.y == 0 and cross.z == 1, "vector.cross of the x and y axes should give the z axis")
end

-- componentwise min/max/abs/sign
do
	local a, b = vector.create(1, 5, -3), vector.create(4, 2, -3)

	local lo = vector.min(a, b)
	assert(lo.x == 1 and lo.y == 2 and lo.z == -3, "vector.min should take the smaller of each component")

	local hi = vector.max(a, b)
	assert(hi.x == 4 and hi.y == 5 and hi.z == -3, "vector.max should take the larger of each component")

	local absVal = vector.abs(vector.create(-1, 2, -3))
	assert(absVal.x == 1 and absVal.y == 2 and absVal.z == 3, "vector.abs should take the absolute value of each component")

	local signVal = vector.sign(vector.create(-5, 0, 5))
	assert(signVal.x == -1 and signVal.y == 0 and signVal.z == 1, "vector.sign should return -1/0/1 per component")
end

-- the zero/one constants
assert(vector.zero.x == 0 and vector.zero.y == 0 and vector.zero.z == 0, "vector.zero should be (0, 0, 0)")
assert(vector.one.x == 1 and vector.one.y == 1 and vector.one.z == 1, "vector.one should be (1, 1, 1)")

return "OK"
