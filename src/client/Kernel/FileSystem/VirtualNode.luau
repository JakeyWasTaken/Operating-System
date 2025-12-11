--[[

Wraps a node for end user usage, as we don't want to expose the raw node class

]]

local General = require("@kernel/Core/General/General")
local NodeFactory = require("@kernel/FileSystem/NodeFactory")

type Node = NodeFactory.Node
type NodeType = NodeFactory.NodeType

export type VirtualNode = {
	GetParent: (self: VirtualNode) -> VirtualNode,

	GetHandle: (self: VirtualNode) -> string,
	GetName: (self: VirtualNode) -> string,
	GetType: (self: VirtualNode) -> NodeType,

	--- Returns the node name without an extension
	GetStrippedName: (self: VirtualNode) -> string,
	GetExtension: (self: VirtualNode) -> string,

	GetCreatedAt: (self: VirtualNode) -> number,
	GetUpdatedAt: (self: VirtualNode) -> number,

	Read: (self: VirtualNode) -> string,
	Write: (self: VirtualNode, Contents: string) -> (),
	ListChildren: (self: VirtualNode) -> { string },
}

local Cache: { [string]: VirtualNode } = setmetatable({}, { __mode = "v" }) :: any

local VirtualNode = {
	Cache = Cache,
}

function VirtualNode.Wrap(Node: Node)
	if Cache[Node.Handle] then
		return Cache[Node.Handle]
	end

	local Wrapper = {} :: VirtualNode

	function Wrapper:GetParent()
		assert(Node.Type ~= "Root", `Cannot get the parent of the root node`)

		return VirtualNode.Wrap(Node.Parent :: Node)
	end

	function Wrapper:GetHandle()
		return Node.Handle
	end

	function Wrapper:GetName()
		return Node.Name
	end

	function Wrapper:GetStrippedName()
		local Extension = Wrapper:GetExtension()
		if #Extension == 0 then
			return Node.Name
		end

		return Node.Name:sub(1, #Node.Name - (#Extension + 1))
	end

	function Wrapper:GetExtension()
		if Node.Type ~= "File" then
			return ""
		end

		local Split = Node.Name:split(".")
		if #Split == 1 then
			return ""
		end

		return Split[#Split]
	end

	function Wrapper:GetType()
		return Node.Type
	end

	function Wrapper:GetCreatedAt()
		return Node.CreatedAt
	end

	function Wrapper:GetUpdatedAt()
		return Node.UpdatedAt
	end

	function Wrapper:Read()
		assert(Node.Type == "File", `Node must be a file to be read from`)

		return Node.Contents
	end

	function Wrapper:Write(Contents: string)
		assert(Node.Type == "File", `Node must be a file to be written too`)

		Node.UpdatedAt = os.clock()
		Node.Contents = Contents
	end

	function Wrapper:ListChildren()
		assert(Node.Type ~= "File", `Node must be a folder to list it's children`)

		return General.Map(Node.Children, function(ChildNode)
			return ChildNode.Name
		end)
	end

	Wrapper = table.freeze(Wrapper)
	Cache[Node.Handle] = Wrapper

	return Wrapper
end

return VirtualNode
