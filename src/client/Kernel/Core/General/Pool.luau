local Log = require("@framework/Core/Log")

local Class = {}
Class.Pool = {}

function Class.Release(object: BasePart)
	local ClassName = object.ClassName

	if not Class.Pool[ClassName] then
		Class.Pool[ClassName] = {}
	end

	(object :: any):Remove()
	table.insert(Class.Pool[ClassName], object)
end

function Class.Request(ClassName: string)
	if not Class.Pool[ClassName] then
		Log.debug(`Creating new obj of classname {ClassName}`)
		return Instance.new(ClassName)
	end

	local Object = table.remove(Class.Pool[ClassName])

	if not Object then
		Log.debug(`Creating new obj of classname {ClassName}`)
		return Instance.new(ClassName)
	end

	return Object
end

return Class
