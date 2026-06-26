const FileSystemInterface = require("@kernel/File/FileSystemInterface")
const FileContext = require("@kernel/File/FileContext")
const FilePath = require("@kernel/File/FilePath")
const Result = require("@core/Result")
const Class = require("@core/Class")
const Signal = require("@core/Signal")
const NodeLocks = require("@kernel/File/FileSystem/NodeLocks")
const CDirectory = require("@kernel/File/FileSystem/Nodes/Directory")
const CFile = require("@kernel/File/FileSystem/Nodes/File")

type Result<T> = Result.Result<T>
type Signal<T...> = Signal.Signal<T...>
type FileContext = FileContext.FileContext
type CFilePath = FilePath.CFilePath
type INode = FileSystemInterface.INode
type IFile = FileSystemInterface.IFile
type IDirectory = FileSystemInterface.IDirectory

export type CFileSystem = {
    new: () -> CFileSystem,

    Destroy: (self: CFileSystem) -> (),

    -- --------------------------------- Members -------------------------------- --
    m_Root: IDirectory,
    m_Handles: { [string]: INode },
} & Class.Base & FileSystemInterface.IFileSystem

local CFileSystem: CFileSystem = Class("CFileSystem")

local function CollectHandles(Node: INode, Handles: { string }): { string }
    table.insert(Handles, Node:GetHandle())

    if Node:IsDirectory() then
        for _, Child in (Node :: IDirectory):GetChildren() do
            CollectHandles(Child, Handles)
        end
    end

    return Handles
end

function CFileSystem.new()
    local self: CFileSystem = setmetatable({}, CFileSystem) :: any
    (CFileSystem :: any)(self)

    self.OnNodeCreated = Signal.new() :: Signal<string>
    self.OnNodeDeleted = Signal.new() :: Signal<string>

    self.m_Root = CDirectory.new();
    (self.m_Root :: any).m_IsRoot = true

    self.m_Handles = { [self.m_Root:GetHandle()] = self.m_Root }

    return self
end

function CFileSystem:Destroy()
    self._Destroy()
end

function CFileSystem:ResolvePath(Path: CFilePath, Context: FileContext): INode?
    local Absolute = Path:Resolve(Context)
    if not Absolute:IsValid() then
        return nil
    end

    local Current: INode = self.m_Root

    for _, Part in Absolute:GetParts() do
        if Part.Type == "Root" or Part.Type == "Home" then
            continue
        end

        if Part.Type == "Escape" then
            Current = Current:GetParent() or Current
            continue
        end

        if not Current:IsDirectory() then
            return nil
        end

        local Found: INode? = nil
        for _, Child in (Current :: IDirectory):GetChildren() do
            if Child:GetName() == (Part :: any).Name then
                Found = Child
                break
            end
        end

        if not Found then
            return nil
        end

        Current = Found
    end

    return Current
end

function CFileSystem:ResolveHandle(Handle: string): INode?
    return self.m_Handles[Handle]
end

function CFileSystem:CreateFile(Path: CFilePath, Context: FileContext): Result<IFile>
    local Absolute = Path:Resolve(Context)
    if not Absolute:IsValid() then
        return Result.new(false, "Provided path was invalid")
    end

    local Name = Absolute:GetName()
    local ParentNode = self:ResolvePath(Absolute:GetParent(), Context)
    if not ParentNode then
        return Result.new(false, "Parent directory does not exist")
    end

    if not ParentNode:IsDirectory() then
        return Result.new(false, "Parent path points to a file")
    end

    local Parent = ParentNode :: IDirectory

    for _, Child in Parent:GetChildren() do
        if Child:GetName() == Name then
            return Result.new(false, "File already exists")
        end
    end

    local File = CFile.new()
    File:SetName(Name)
    File:SetParent(Parent)

    self.m_Handles[File:GetHandle()] = File
    self.OnNodeCreated:Fire(File:GetHandle())

    return Result.new(true, "", File)
end

function CFileSystem:CreateDirectory(Path: CFilePath, Context: FileContext): Result<IDirectory>
    local Absolute = Path:Resolve(Context)
    if not Absolute:IsValid() then
        return Result.new(false, "Provided path was invalid")
    end

    local Current: INode = self.m_Root

    for _, Part in Absolute:GetParts() do
        if Part.Type == "Root" or Part.Type == "Home" then
            continue
        end

        if not Current:IsDirectory() then
            return Result.new(false, "Provided path points to a file")
        end

        local CurrentDirectory = Current :: IDirectory

        if Part.Type == "Escape" then
            Current = CurrentDirectory:GetParent() or CurrentDirectory
            continue
        end

        local Found: INode? = nil
        for _, Child in CurrentDirectory:GetChildren() do
            if Child:GetName() == (Part :: any).Name then
                Found = Child
                break
            end
        end

        if not Found then
            Found = CDirectory.new()
            Found:SetName((Part :: any).Name)
            Found:SetParent(CurrentDirectory)

            self.m_Handles[Found:GetHandle()] = Found
            self.OnNodeCreated:Fire(Found:GetHandle())
        end

        Current = Found
    end

    if not Current:IsDirectory() then
        return Result.new(false, "Provided path points to a file")
    end

    return Result.new(true, "", Current :: IDirectory)
end

function CFileSystem:DeleteNode(NodeHandle: string): boolean
    local Node = self.m_Handles[NodeHandle]
    if not Node then
        return false
    end

    local Handles = CollectHandles(Node, {})

    if not Node:Delete() then
        return false
    end

    for _, Handle in Handles do
        self.m_Handles[Handle] = nil
        self.OnNodeDeleted:Fire(Handle)
    end

    return true
end

function CFileSystem:LockNode(NodeHandle: string, PID: number)
    NodeLocks.LockNode(NodeHandle, PID)
end

function CFileSystem:UnlockNode(NodeHandle: string, PID: number)
    NodeLocks.UnlockNode(NodeHandle, PID)
end

function CFileSystem:ReleaseProgramLocks(PID: number)
    NodeLocks.ReleaseProgramLocks(PID)
end

return CFileSystem
