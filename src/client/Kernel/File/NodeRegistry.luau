const Handle = require("@kernel/Core/Handle")

type Handle = Handle.Handle
export type NodeType = "File" | "Folder" | "Root"

export type Node = {
	Handle: Handle,
	Type: NodeType,

	CreatedAt: number,
	UpdatedAt: number,

	Name: string,
	Contents: string,

	Parent: Handle?,
	Children: { Handle },
}

-- Set mode so if we mess up some destruction stuff we wont memory leak
local Registry: { [Handle]: Node? } = setmetatable({}, { __mode = "v" }) :: any

local NodeRegistry = {}

function NodeRegistry.Create(): Node
	local Node = {
		Handle = Handle(),
		Type = "Root",

		CreatedAt = os.clock(),
		UpdatedAt = os.clock(),

		Contents = "",
		Name = "",

		Parent = nil,
		Children = {},
	}

	Registry[Node.Handle] = Node

	return Node
end

function NodeRegistry.Get(Handle: Handle.Handle)
    return Registry[Handle]
end

function NodeRegistry.Move(ChildHandle: Handle.Handle, ParentHandle: Handle.Handle)
    local ChildNode, ParentNode = Registry[ChildHandle], Registry[ParentHandle]
    if not ChildNode or not ParentNode then
        return false
    end

    if ParentNode.Type == "File" then
        return false
    end

    if ChildNode.Parent == ParentHandle or ParentNode.Parent == ChildHandle then
        return false
    end

    local OldParent = ChildNode.Parent
    if OldParent then
        local Index = table.find(OldParent.Children, ChildHandle)
        if Index then
            table.remove(OldParent.Children, Index)
        end
    end

    ChildNode.Parent = ParentHandle
    table.insert(ParentNode.Children, ChildHandle)

    return true
end

function NodeRegistry.Delete(Handle: Handle.Handle)
    local Node = Registry[Handle]
    if not Node then
        return false
    end

    local ParentNode = Node.Parent and Registry[Node.Parent]
    if ParentNode then
        local Index = table.find(ParentNode.Children, Handle)
        if Index then
            table.remove(ParentNode.Children, Index)
        end
    end

    for i = #Node.Children, 1, -1 do
        local Child = Node.Children[i]
        NodeRegistry.Delete(Child.Handle)
    end

    Registry[Handle] = nil
    return true
end

return NodeRegistry
