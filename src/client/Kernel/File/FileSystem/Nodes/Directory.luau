const CNode = require("@kernel/File/FileSystem/Nodes/Node")
const FileSystemInterface = require("@kernel/File/FileSystemInterface")
const NodeLocks = require("@kernel/File/FileSystem/NodeLocks")

type INode = FileSystemInterface.INode

local function IsLockedRecursive(Node: INode): boolean
    if Node:IsLocked() then
        return true
    end

    if not Node:IsDirectory() then
        return false
    end

    for _, Child in (Node :: FileSystemInterface.IDirectory):GetChildren() do
        if IsLockedRecursive(Child) then
            return true
        end
    end

    return false
end

export type CDirectory = {
    new: () -> CDirectory,

    -- --------------------------------- Members -------------------------------- --
    m_Children: { INode },
} & FileSystemInterface.IDirectory

-- We don't use the class library here for the sake of being lightweight
local CDirectory: CDirectory = setmetatable({}, { __index = CNode }) :: any
CDirectory.__index = CDirectory

function CDirectory.new()
    local self = setmetatable(CNode.new(), CDirectory)

    self.m_Children = {}

    return self
end

function CDirectory:IsDirectory()
    return true
end

function CDirectory:GetChildren()
    return self.m_Children
end

function CDirectory:Delete(): boolean
    if self.m_IsRoot or IsLockedRecursive(self) then
        return false
    end

    self:SetParent(nil)
    NodeLocks.ReleaseNodeLocks(self:GetHandle())

    return true
end

return CDirectory
