--[=[

    Hashes the provided string into a number, collisions are possible but unlikely

    Not cryptographically safe.

]=]
return function(String: string): number
	local HashValue = 2166136261

	for i = 1, #String do
		HashValue = bit32.bxor(HashValue, string.byte(String, i))
		HashValue = (HashValue * 16777619) % 2 ^ 32
	end

	return HashValue
end
