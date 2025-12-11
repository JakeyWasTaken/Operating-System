local Class = require("@kernel/Core/Class")
local Handle = require("@kernel/Core/Handle")

type Handle = Handle.Handle

export type NodeType = "FOLDER" | "FILE" | "ROOT"
export type CNode = {
	AllNodes: { [Handle]: CNode? },
	new: (Type: NodeType, Parent: CNode?) -> CNode,

	-- --------------------------------- Methods -------------------------------- --

	AddChild: (self: CNode, Node: CNode) -> (),
	RemoveChild: (self: CNode, Node: CNode) -> (),

	FindChild: (self: CNode, Name: string) -> CNode?,

	GetSiblings: (self: CNode) -> { CNode },

	Destroy: (self: CNode) -> (),

	-- --------------------------------- Members -------------------------------- --

	Name: string,
	Type: NodeType,
	Handle: Handle,

	Children: { CNode },
	Parent: CNode?,

	Metadata: {
		CreatedAt: number,
		ReadAt: number,
		WrittenAt: number,
	},
} & Class.BaseClass

local CNode = Class("CNode")
CNode.AllNodes = {}

function CNode.new(Type: NodeType, Parent: CNode)
	local self: CNode = setmetatable({}, CNode) :: any
	(CNode :: any)(self)

	local Now = os.clock()

	self.Name = ""
	self.Type = Type
	self.Handle = Handle()

	self.Children = {}
	self.Parent = Parent

	self.Metadata = {
		CreatedAt = Now,
		ReadAt = Now,
		WrittenAt = Now,
	}

	CNode.AllNodes[self.Handle] = self
	self.Maid:GiveTask(function()
		CNode.AllNodes[self.Handle] = nil
	end)

	return self
end

function CNode:AddChild(Node: CNode)
	if table.find(self.Children, Node) then
		return
	end

	table.insert(self.Children, Node)
end

function CNode:RemoveChild(Node: CNode)
	local Index = table.find(self.Children, Node)
	if not Index then
		return
	end

	table.remove(self.Children, Node)
end

function CNode:FindChild(Name: string)
	for _, Child in self.Children do
		if Child.Name ~= Name then
			continue
		end

		return Child
	end
end

function CNode:GetSiblings()
	if not self.Parent then
		return {}
	end

	local Siblings = {}

	for _, Child in self.Parent.Children do
		if Child == self then
			continue
		end

		table.insert(Siblings, Child)
	end

	return Siblings
end

function CNode:Destroy()
	-- Destroy all children
	for _, Child in self.Children do
		Child:Destroy()
	end

	self:_Destroy()
end

return CNode
