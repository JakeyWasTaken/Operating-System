local import = {}

function import.test(n: number)
	warn("import!")
	warn(n)
end

require("/bin/somewhere/far.luau")

return import
