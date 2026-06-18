local HttpService = game:GetService("HttpService")

-- Describes a file / folder
export type NodeType = "File" | "Folder" | "Root"
export type Node = {
	Handle: string,
	Name: string,
	Type: NodeType,

	Contents: string,

	CreatedAt: number,
	UpdatedAt: number,

	Parent: Node?,
	Children: { Node },
}

-- Set mode so if we mess up some destruction stuff we wont memory leak
local Registry: { [string]: Node? } = setmetatable({}, { __mode = "v" }) :: any

local NodeFactory = {
	Registry = Registry,
}

function NodeFactory.new(): Node
	local Node = {
		Handle = HttpService:GenerateGUID(false):gsub("-", ""),
		Name = "",
		Type = "Root",

		Contents = "",

		CreatedAt = os.clock(),
		UpdatedAt = os.clock(),

		Parent = nil,
		Children = {},
	}

	Registry[Node.Handle] = Node

	return Node
end

return NodeFactory
