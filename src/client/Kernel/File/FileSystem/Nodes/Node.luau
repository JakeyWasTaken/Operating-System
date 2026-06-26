const FileSystemInterface = require("@kernel/File/FileSystemInterface")
const FilePath = require("@kernel/File/FilePath")
const NodeLocks = require("@kernel/File/FileSystem/NodeLocks")
const Handle = require("@core/Handle")

type IDirectory = FileSystemInterface.IDirectory
type CFilePath = FilePath.CFilePath
type NodeMetadata = FileSystemInterface.NodeMetadata

const NODE_HANDLE_SIZE = 16

export type CNode = {
    new: () -> CNode,

    -- --------------------------------- Members -------------------------------- --
    m_Handle: string,
    m_Name: string,
    m_Parent: IDirectory?,
    m_IsRoot: boolean,
    m_CreatedAt: number,

} & FileSystemInterface.INode

-- We don't use the class library here for the sake of being lightweight
local CNode: CNode = {} :: any
CNode.__index = CNode

function CNode.new()
    local self = setmetatable({}, CNode)

    self.m_Handle = Handle(NODE_HANDLE_SIZE)
    self.m_Name = ""
    self.m_Parent = nil
    self.m_IsRoot = false
    self.m_CreatedAt = os.clock()

    return self
end

function CNode:GetHandle()
    return self.m_Handle
end

function CNode:GetMetadata(): NodeMetadata
    return { CreatedAt = self.m_CreatedAt }
end

function CNode:GetName()
    return self.m_Name
end

function CNode:GetPath(): CFilePath
    if self.m_Parent == nil then
        if self.m_Name == "" then
            return FilePath.new("/")
        end

        return FilePath.new("/"):Append(self.m_Name)
    end

    return self.m_Parent:GetPath():Append(self.m_Name)
end

function CNode:GetParent()
    return self.m_Parent
end

function CNode:SetParent(Parent: IDirectory?)
    if self.m_IsRoot then
        return
    end

    if self.m_Parent then
        local Siblings = self.m_Parent:GetChildren()
        local Index = table.find(Siblings, self)
        if Index then
            table.remove(Siblings, Index)
        end
    end

    self.m_Parent = Parent

    if Parent then
        table.insert(Parent:GetChildren(), self)
    end
end

function CNode:SetName(Name: string)
    self.m_Name = Name
end

function CNode:IsDirectory()
    return false
end

function CNode:IsFile()
    return false
end

function CNode:IsRoot()
    return self.m_IsRoot
end

function CNode:IsLocked()
    return NodeLocks.IsLocked(self.m_Handle)
end

function CNode:Delete(): boolean
    if self.m_IsRoot or self:IsLocked() then
        return false
    end

    self:SetParent(nil)
    NodeLocks.ReleaseNodeLocks(self.m_Handle)

    return true
end

return CNode
