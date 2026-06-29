const CNode = require("@kernel/File/FileSystem/Nodes/Node")
const FileSystemInterface = require("@kernel/File/FileSystemInterface")
const NodeLocks = require("@kernel/File/FileSystem/NodeLocks")

type NodeMetadata = FileSystemInterface.NodeMetadata

export type CFile = {
    new: () -> CFile,

    -- --------------------------------- Members -------------------------------- --
    m_Contents: string,
    m_UpdatedAt: number,
} & FileSystemInterface.IFile

-- We don't use the class library here for the sake of being lightweight
local CFile: CFile = setmetatable({}, { __index = CNode }) :: any
CFile.__index = CFile

function CFile.new()
    local self = setmetatable(CNode.new(), CFile)

    self.m_Contents = ""
    self.m_UpdatedAt = self.m_CreatedAt

    return self
end

function CFile:IsFile()
    return true
end

function CFile:Read()
    return self.m_Contents
end

function CFile:Write(Data: string, Offset: number?)
    if NodeLocks.IsLocked(self.m_Handle) then
        return
    end

    if Offset == nil then
        self.m_Contents = Data
    else
        self.m_Contents = self.m_Contents:sub(1, Offset) .. Data .. self.m_Contents:sub(Offset + #Data + 1)
    end

    self.m_UpdatedAt = tick()
end

function CFile:GetSize()
    return #self.m_Contents
end

function CFile:GetMetadata(): NodeMetadata
    return { CreatedAt = self.m_CreatedAt, UpdatedAt = self.m_UpdatedAt }
end

return CFile
