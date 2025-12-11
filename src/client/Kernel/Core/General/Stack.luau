--!optimize 2
export type Stack<T> = typeof(setmetatable({}, {})) & {
	Push: (self: Stack<T>, ...T) -> (),
	Pop: (self: Stack<T>) -> T,
	Peek: (self: Stack<T>) -> T,
	Clear: (self: Stack<T>) -> (),
	IsEmpty: (self: Stack<T>) -> boolean,
	Size: (self: Stack<T>) -> number,
	Iterator: (self: Stack<T>) -> () -> T,
	ToString: (self: Stack<T>) -> string,
	data: { [number]: T },
	count: number,
}

--- @class Stack
local Stack = {}
Stack.__index = Stack

--- @within Stack
function Stack.new<T>(): Stack<T>
	return setmetatable({ data = {}, count = 0 }, Stack) :: any
end

--- @within Stack
function Stack:Push<T>(...: T)
	local numArgs = select("#", ...)
	if numArgs == 0 then
		error("Expected at least one argument", 2)
	end

	for i = 1, numArgs do
		local value = select(i, ...)
		self.count = self.count + 1
		self.data[self.count] = value
	end
end

--- @within Stack
function Stack:Pop<T>(): T | nil
	-- If the stack is empty, return nil
	if self.count == 0 then
		return nil
	end

	-- Otherwise, remove the top item from the stack and return it
	local item = self.data[self.count]
	self.data[self.count] = nil
	self.count = self.count - 1
	return item
end

--- @within Stack
function Stack:Peek<T>(): T | nil
	-- If the stack is empty, return nil
	if self.count == 0 then
		return nil
	end

	-- Otherwise, return the top item on the stack without removing it
	return self.data[self.count]
end

--- @within Stack
function Stack:Clear()
	self.data = {}
	self.count = 0
end

--- @within Stack
function Stack:IsEmpty(): boolean
	return self.count == 0
end

--- @within Stack
function Stack:Size(): number
	return self.count
end

--- @within Stack
function Stack:Iterator(): () -> number | nil
	local index = self.count
	if index == 0 then
		return function() end
	end
	return function()
		if index > 0 then
			local value = self.data[index]
			index = index - 1
			return value
		end

		return nil
	end
end

function Stack:ToString(): string
	local items = {}
	for i = 1, self.count do
		table.insert(items, tostring(self.data[i]))
	end
	return table.concat(items, ", ")
end

function Stack:__tostring()
	return "Stack [" .. self:ToString() .. "]"
end

return Stack
