--!optimize 2
local Log = require("@core/Log")
local Maid = require("@core/Maid")
type Metatable = typeof(setmetatable({}, {}))
type Class = Metatable

export type Base = {
	Maid: Maid.Maid,
	_Destroy: () -> (),
	_GetTLC: () -> Base,
}

export type GenericClass = {
	Destroy: (self: GenericClass) -> (),
} & Base

local CREATION_LOG = false
local CONSTRUCTOR_LOG = false

local _Class = setmetatable({}, {
	__call = function(_, Name: string, Extends: Class?): any
		if Extends then
			local Metatable = getmetatable(Extends)
			assert(Metatable, "Expected a RAFE class for extends")
			assert(Metatable.__type == "RAFECLASS", "Expected a RAFE class for extends")

			if CREATION_LOG then
				Log.fwdebug(`Creating class {Name} extending from {tostring(Extends)}`)
			end
		elseif CREATION_LOG then
			Log.fwdebug(`Creating class {Name}`)
		end

		local Meta = setmetatable({}, {
			__tostring = function()
				return Name
			end,
			__type = "RAFECLASS",
			__call = function(_, self, ...)
				self.Maid = Maid.new()
				self.__Destroy = function()
					if CONSTRUCTOR_LOG then
						Log.fwdebug(`Class {Name} being destroyed`)
					end

					self.Maid:DoCleaning()

					if rawget(self, "__inherited") and (rawget(self, "__inherited") :: any)["__Destroy"] then
						(rawget(self, "__inherited") :: any).__Destroy()
					end

					setmetatable(self, nil)
				end

				self._Destroy = function()
					-- Walk up inheritance chain and call first _Destroy function
					local TopSelf = self
					while rawget(TopSelf, "__inheritedby") do
						TopSelf = rawget(TopSelf, "__inheritedby")
					end

					TopSelf.__Destroy()
				end

				self._GetTLC = function()
					local TopSelf = self
					while rawget(TopSelf, "__inheritedby") do
						TopSelf = rawget(TopSelf, "__inheritedby")
					end

					return TopSelf
				end

				if Extends and (Extends["new"] or Extends[tostring(Extends)]) then
					if CONSTRUCTOR_LOG then
						Log.fwdebug(`Constructing inherited class, origin: [{Name}], extends: [{tostring(Extends)}]`)
					end

					local Constructor = (Extends["new"] or Extends[tostring(Extends)])
					local Result = Constructor(...)

					rawset(self, "__inherited", Result)
					rawset(Result, "__inheritedby", self)
				elseif Extends ~= nil then
					Log.error(`Failed to construct inherited class, origin: [{Name}], extends: [{tostring(Extends)}]`)
				end
			end,
			__index = function(self, Index)
				if rawget(self :: any, Index) ~= nil then
					return rawget(self, Index)
				elseif Extends and Extends[Index] ~= nil then
					return Extends[Index]
				else
					return nil
				end
			end,
		})
		-- If we are checking if two class instances are equal, we need to get to the tlc,
		-- as we may be pointing at the same class, but at different parts of it!
		Meta.__eq = function(_self, _Class)
			-- Walk all the way up to the top of inheritance chain
			local self = _self
			while rawget(self, "__inheritedby") do
				self = rawget(self, "__inheritedby")
			end

			-- Walk all the way up to the top of inheritance chain
			local Class = _Class
			while rawget(Class, "__inheritedby") do
				Class = rawget(Class, "__inheritedby")
			end

			return rawequal(self, Class)
		end
		Meta.__extends = Extends
		Meta.__index = function(_self, Index)
			-- Walk all the way up to the top of inheritance chain
			local self = _self
			while rawget(self, "__inheritedby") do
				self = rawget(self, "__inheritedby")
			end

			-- Walk all the way down the inheritance chain
			local Current = self
			while true do
				if rawget(Current, Index) ~= nil then
					return rawget(Current, Index)
				end

				if getmetatable(Current)[Index] ~= nil then
					return getmetatable(Current)[Index]
				end

				if rawget(Current, "__inherited") == nil then
					return
				end

				Current = rawget(Current, "__inherited")
			end
		end
		Meta.__newindex = function(_self, Index, Value)
			-- Walk all the way up to the top of inheritance chain
			local self = _self
			while rawget(self, "__inheritedby") do
				self = rawget(self, "__inheritedby")
			end

			-- Walk all the way down the inheritance chain
			local Current = self
			while true do
				if rawget(Current, Index) ~= nil then
					rawset(Current, Index, Value)
					return
				end

				if getmetatable(Current)[Index] ~= nil then
					getmetatable(Current)[Index] = Value
					return
				end

				if rawget(Current, "__inherited") == nil then
					rawset(_self, Index, Value)
					return
				end

				Current = rawget(Current, "__inherited")
			end

			-- if rawget(self, "__inherited") and rawget(self, "__inherited")[Index] ~= nil then
			-- 	rawget(self, "__inherited")[Index] = Value
			-- else
			-- 	rawset(self, Index, Value)
			-- end
		end

		return Meta
	end,
})

--[=[
	@class Class
	Class to create classes which can be inherited.
	Call `Class(Name: string, Extends: Class?)` to create a class.
	The classes constructor must be called either "new" or the classes name;
	If the class inherits from another class you must call ([Class] :: any)(self, [ConstructorParameters]) after you do local self = ...

	Example:
	```
	local TestClass = Class("TestClass", OtherClass)

	function TestClass.TestClass()
		local self = setmetatable({}, TestClass);
		(TestClass :: any)(self) -- This is what inherits the values from the inherited class

		return self
	end

	function TestClass:Destroy()
		OtherClass.Destroy(self) -- This calls the destroy function on the super class with our context
		self:_Destroy() -- This cleans up the maid and sets the metatable to nil
	end

	return TestClass
	```
]=]
local Class: typeof(_Class) = _Class

--- @within Class
--- Checks if ClassA extends from ClassB
function Class.ExtendsFrom(_ClassA: Class, ClassB: Class): boolean
	-- Walk all the way up to the top of inheritance chain
	local ClassA = _ClassA
	while rawget(ClassA, "__inheritedby") do
		ClassA = rawget(ClassA, "__inheritedby")
	end

	local MetatableA = getmetatable(ClassA)
	local IsSimpleExtend = MetatableA.__extends == ClassB or MetatableA == ClassB

	if IsSimpleExtend then
		return true
	end

	local CurrentClass = MetatableA.__extends
	repeat
		if CurrentClass.__extends == nil then
			return false
		elseif CurrentClass.__extends == ClassB then
			return true
		end

		CurrentClass = CurrentClass.__extends
	until false
end

--- Returns the instance of the top level class,
--- if you want the class name use getmetatable on the resultant
function Class.GetTopLevelClass(Class: Class): Class
	-- Walk all the way up to the top of inheritance chain
	local TopLevelClass = Class
	while rawget(TopLevelClass, "__inheritedby") do
		TopLevelClass = rawget(TopLevelClass, "__inheritedby")
	end

	return TopLevelClass
end

function Class.IsDestroyed(Class: Class): boolean
	return getmetatable(Class) == nil
end

return Class
