--- Excludes U from union T
---
--- Returns new union
export type function Exclude(T, U)
	-- If T isn't a union, just check if T itself should be excluded
	if not T:is("union") then
		if T:is(U.tag) then
			return types.never
		end
		return T
	end

	local kept = {}

	for _, component in T:components() do
		-- Keep components that are NOT assignable to U
		-- For singleton types, compare the value directly
		local exclude = false

		if U:is("singleton") and component:is("singleton") then
			exclude = component:value() == U:value()
		elseif U:is(component.tag) then
			exclude = true
		end

		if not exclude then
			table.insert(kept, component)
		end
	end

	if #kept == 0 then
		return types.never
	elseif #kept == 1 then
		return kept[1]
	else
		return types.unionof(table.unpack(kept))
	end
end

return true
