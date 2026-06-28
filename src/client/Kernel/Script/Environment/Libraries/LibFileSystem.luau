--[[

	LibFileSystem / fs

	Testing only library, disabled out of studio

]]

const CFilePath = require("@kernel/File/FilePath")
const FileSystemManager = require("@kernel/File/FileSystemManager")
const FileSystemInterface = require("@kernel/File/FileSystemInterface")

type CFilePath = CFilePath.CFilePath
type INode = FileSystemInterface.INode
type IDirectory = FileSystemInterface.IDirectory

-- True if Candidate is PossibleAncestor itself, or sits somewhere under it.
local function IsUnderneath(Candidate: IDirectory, PossibleAncestor: INode): boolean
    local Current: IDirectory? = Candidate
    while Current do
        if Current == PossibleAncestor then
            return true
        end

        Current = Current:GetParent()
    end

    return false
end

local function HasSiblingNamed(Parent: IDirectory, Name: string, Excluding: INode): boolean
    for _, Child in Parent:GetChildren() do
        if Child ~= Excluding and Child:GetName() == Name then
            return true
        end
    end

    return false
end

return {
	Name = "fs",
	Enabled = true,
	MakeLibrary = function(LibraryPID: number, ScriptPath: CFilePath)
        -- For relative files we expand using script path here,
        -- we don't use file context just for clarity reasons
        local function ResolveScriptPath(PathString: string): CFilePath
            local RequestedPath = CFilePath.new(PathString)
            if not RequestedPath:IsValid() then
                return RequestedPath
            end

            local FirstPart = RequestedPath:GetParts()[1]
            if not FirstPart or (FirstPart.Type ~= "Root" and FirstPart.Type ~= "Home") then
                return ScriptPath:Append(PathString)
            end

            return RequestedPath
        end

		return {
            -- ----------------------------- Tree Operations ----------------------------- --

            CreateFile = function(Path: string): (boolean?, string)
                if typeof(Path) ~= "string" then
                    return nil, "Expected Path to be of type string"
                end

                if not shared.ProcessFactory then
                    return nil, "ProcessFactory was not ready"
                end

                local Process = shared.ProcessFactory.GetProcess(LibraryPID)

                local FileSystem = FileSystemManager.GetActiveFileSystem()
                if not FileSystem then
                    return nil, "no active file system"
                end

                local Result = FileSystem:CreateFile(ResolveScriptPath(Path), Process.FileContext)
                if not Result.Success then
                    return nil, Result.Reason
                end

                return true, ""
            end,

            CreateDirectory = function(Path: string): (boolean?, string)
                if typeof(Path) ~= "string" then
                    return nil, "Expected Path to be of type string"
                end

                if not shared.ProcessFactory then
                    return nil, "ProcessFactory was not ready"
                end

                local Process = shared.ProcessFactory.GetProcess(LibraryPID)

                local FileSystem = FileSystemManager.GetActiveFileSystem()
                if not FileSystem then
                    return nil, "no active file system"
                end

                local Result = FileSystem:CreateDirectory(ResolveScriptPath(Path), Process.FileContext)
                if not Result.Success then
                    return nil, Result.Reason
                end

                return true, ""
            end,

            --- Deletes the node at Path, along with any descendants.
            ---
            --- Fails if the node (or any descendant) is currently locked - close any
            --- open handles on it first.
            Delete = function(Path: string): (boolean?, string)
                if typeof(Path) ~= "string" then
                    return nil, "Expected Path to be of type string"
                end

                if not shared.ProcessFactory then
                    return nil, "ProcessFactory was not ready"
                end

                local Process = shared.ProcessFactory.GetProcess(LibraryPID)

                local FileSystem = FileSystemManager.GetActiveFileSystem()
                if not FileSystem then
                    return nil, "no active file system"
                end

                local Node = FileSystem:ResolvePath(ResolveScriptPath(Path), Process.FileContext)
                if not Node then
                    return nil, `"{Path}" does not exist`
                end

                if not FileSystem:DeleteNode(Node:GetHandle()) then
                    return nil, `"{Path}" could not be deleted, it (or a descendant) may be locked`
                end

                return true, ""
            end,

            --- Lists the immediate children of the directory at Path.
            List = function(Path: string): ({ { Name: string, IsDirectory: boolean } }?, string)
                if typeof(Path) ~= "string" then
                    return nil, "Expected Path to be of type string"
                end

                if not shared.ProcessFactory then
                    return nil, "ProcessFactory was not ready"
                end

                local Process = shared.ProcessFactory.GetProcess(LibraryPID)

                local FileSystem = FileSystemManager.GetActiveFileSystem()
                if not FileSystem then
                    return nil, "no active file system"
                end

                local Node = FileSystem:ResolvePath(ResolveScriptPath(Path), Process.FileContext)
                if not Node then
                    return nil, `"{Path}" does not exist`
                end

                if not Node:IsDirectory() then
                    return nil, `"{Path}" is not a directory`
                end

                local Entries = {}
                for _, Child in (Node :: IDirectory):GetChildren() do
                    table.insert(Entries, {
                        Name = Child:GetName(),
                        IsDirectory = Child:IsDirectory(),
                    })
                end

                return Entries, ""
            end,

            -- ------------------------------ Open / Close ------------------------------- --

            Open = function(Path: string, Exclusive: boolean?): (string?, string)
                if typeof(Path) ~= "string" then
                    return nil, "Expected Path to be of type string"
                end

                if not shared.ProcessFactory then
                    return nil, "ProcessFactory was not ready"
                end

                local Process = shared.ProcessFactory.GetProcess(LibraryPID)

                local FileSystem = FileSystemManager.GetActiveFileSystem()
                if not FileSystem then
                    return nil, "no active file system"
                end

                local RequestedPath = ResolveScriptPath(Path)
                if not RequestedPath:IsValid() then
                    return nil, `"{Path}" is not a valid path`
                end

                local Node = FileSystem:ResolvePath(RequestedPath, Process.FileContext)
                if not Node then
                    return nil, `"{Path}" does not exist`
                end

                if not Node:IsFile() then
                    return nil, `"{Path}" is not a file`
                end

                if Node:IsLocked() then
                    return nil, `"{Path}" is locked`
                end

                local NodeHandle = Node:GetHandle()
                if Exclusive then
                    FileSystem:LockNode(NodeHandle, LibraryPID)
                end

                local ScopedHandle = Process:GetScopedHandle(NodeHandle) or Process:CreateScopedHandle(NodeHandle)
                return ScopedHandle, ""
            end,

            -- ----------------------------- Node Operations ---------------------------- --

            Close = function(ScopedHandle: string): (boolean?, string)
                if typeof(ScopedHandle) ~= "string" then
                    return nil, "Expected ScopedHandle to be of type string"
                end

                if not shared.ProcessFactory then
                    return nil, "ProcessFactory was not ready"
                end

                local Process = shared.ProcessFactory.GetProcess(LibraryPID)

                local FileSystem = FileSystemManager.GetActiveFileSystem()
                if not FileSystem then
                    return nil, "no active file system"
                end

                local GlobalHandle = Process:GetGlobalHandle(ScopedHandle)
                if not GlobalHandle then
                    return nil, "ScopedHandle does not refer to an open node"
                end

                FileSystem:UnlockNode(GlobalHandle, LibraryPID)
                Process:RemoveScopedHandle(ScopedHandle)

                return true, ""
            end,

            Read = function(ScopedHandle: string): (string?, string)
                if typeof(ScopedHandle) ~= "string" then
                    return nil, "Expected ScopedHandle to be of type string"
                end

                if not shared.ProcessFactory then
                    return nil, "ProcessFactory was not ready"
                end

                local Process = shared.ProcessFactory.GetProcess(LibraryPID)

                local FileSystem = FileSystemManager.GetActiveFileSystem()
                if not FileSystem then
                    return nil, "no active file system"
                end

                local GlobalHandle = Process:GetGlobalHandle(ScopedHandle)
                if not GlobalHandle then
                    return nil, "ScopedHandle does not refer to an open node"
                end

                local Node = FileSystem:ResolveHandle(GlobalHandle)
                if not Node then
                    return nil, "ScopedHandle's node no longer exists"
                end

                return Node:Read(), ""
            end,

            Write = function(ScopedHandle: string, Data: string, Offset: number): (boolean?, string)
                if typeof(ScopedHandle) ~= "string" then
                    return nil, "Expected ScopedHandle to be of type string"
                end

                if typeof(Data) ~= "string" then
                    return nil, "Expected data to be of type string"
                end

                if typeof(Offset) ~= "number" then
                    return nil, "Expected offset to be of type number"
                end

                if not shared.ProcessFactory then
                    return nil, "ProcessFactory was not ready"
                end

                local Process = shared.ProcessFactory.GetProcess(LibraryPID)

                local FileSystem = FileSystemManager.GetActiveFileSystem()
                if not FileSystem then
                    return nil, "no active file system"
                end

                local GlobalHandle = Process:GetGlobalHandle(ScopedHandle)
                if not GlobalHandle then
                    return nil, "ScopedHandle does not refer to an open node"
                end

                local Node = FileSystem:ResolveHandle(GlobalHandle)
                if not Node then
                    return nil, "ScopedHandle's node no longer exists"
                end

                Node:Write(Data, Offset)

                return true, ""
            end,

            GetMetadata = function(ScopedHandle: string): (FileSystemInterface.NodeMetadata?, string)
                if typeof(ScopedHandle) ~= "string" then
                    return nil, "Expected ScopedHandle to be of type string"
                end

                if not shared.ProcessFactory then
                    return nil, "ProcessFactory was not ready"
                end

                local Process = shared.ProcessFactory.GetProcess(LibraryPID)

                local FileSystem = FileSystemManager.GetActiveFileSystem()
                if not FileSystem then
                    return nil, "no active file system"
                end

                local GlobalHandle = Process:GetGlobalHandle(ScopedHandle)
                if not GlobalHandle then
                    return nil, "ScopedHandle does not refer to an open node"
                end

                local Node = FileSystem:ResolveHandle(GlobalHandle)
                if not Node then
                    return nil, "ScopedHandle's node no longer exists"
                end

                return Node:GetMetadata(), ""
            end,

            GetName = function(ScopedHandle: string): (string?, string)
                if typeof(ScopedHandle) ~= "string" then
                    return nil, "Expected ScopedHandle to be of type string"
                end

                if not shared.ProcessFactory then
                    return nil, "ProcessFactory was not ready"
                end

                local Process = shared.ProcessFactory.GetProcess(LibraryPID)

                local FileSystem = FileSystemManager.GetActiveFileSystem()
                if not FileSystem then
                    return nil, "no active file system"
                end

                local GlobalHandle = Process:GetGlobalHandle(ScopedHandle)
                if not GlobalHandle then
                    return nil, "ScopedHandle does not refer to an open node"
                end

                local Node = FileSystem:ResolveHandle(GlobalHandle)
                if not Node then
                    return nil, "ScopedHandle's node no longer exists"
                end

                return Node:GetName(), ""
            end,

            --- Renames the node in place. Fails if a sibling already has that name.
            Rename = function(ScopedHandle: string, NewName: string): (boolean?, string)
                if typeof(ScopedHandle) ~= "string" then
                    return nil, "Expected ScopedHandle to be of type string"
                end

                if typeof(NewName) ~= "string" then
                    return nil, "Expected NewName to be of type string"
                end

                if not shared.ProcessFactory then
                    return nil, "ProcessFactory was not ready"
                end

                local Process = shared.ProcessFactory.GetProcess(LibraryPID)

                local FileSystem = FileSystemManager.GetActiveFileSystem()
                if not FileSystem then
                    return nil, "no active file system"
                end

                local GlobalHandle = Process:GetGlobalHandle(ScopedHandle)
                if not GlobalHandle then
                    return nil, "ScopedHandle does not refer to an open node"
                end

                local Node = FileSystem:ResolveHandle(GlobalHandle)
                if not Node then
                    return nil, "ScopedHandle's node no longer exists"
                end

                local Parent = Node:GetParent()
                if Parent and HasSiblingNamed(Parent, NewName, Node) then
                    return nil, `a sibling named "{NewName}" already exists`
                end

                Node:SetName(NewName)

                return true, ""
            end,

            --- Moves the node to sit under the directory at DestinationPath.
            ---
            --- Fails if the destination doesn't exist or isn't a directory, if a
            --- sibling there already has this node's name, or if the destination is
            --- the node itself or one of its own descendants.
            Move = function(ScopedHandle: string, DestinationPath: string): (boolean?, string)
                if typeof(ScopedHandle) ~= "string" then
                    return nil, "Expected ScopedHandle to be of type string"
                end

                if typeof(DestinationPath) ~= "string" then
                    return nil, "Expected DestinationPath to be of type string"
                end

                if not shared.ProcessFactory then
                    return nil, "ProcessFactory was not ready"
                end

                local Process = shared.ProcessFactory.GetProcess(LibraryPID)

                local FileSystem = FileSystemManager.GetActiveFileSystem()
                if not FileSystem then
                    return nil, "no active file system"
                end

                local GlobalHandle = Process:GetGlobalHandle(ScopedHandle)
                if not GlobalHandle then
                    return nil, "ScopedHandle does not refer to an open node"
                end

                local Node = FileSystem:ResolveHandle(GlobalHandle)
                if not Node then
                    return nil, "ScopedHandle's node no longer exists"
                end

                if Node:IsRoot() then
                    return nil, "cannot move the root"
                end

                local RequestedPath = ResolveScriptPath(DestinationPath)
                if not RequestedPath:IsValid() then
                    return nil, `"{DestinationPath}" is not a valid path`
                end

                local Destination = FileSystem:ResolvePath(RequestedPath, Process.FileContext)
                if not Destination then
                    return nil, `"{DestinationPath}" does not exist`
                end

                if not Destination:IsDirectory() then
                    return nil, `"{DestinationPath}" is not a directory`
                end

                if Node:IsDirectory() and IsUnderneath(Destination :: IDirectory, Node) then
                    return nil, "cannot move a directory into itself or one of its own descendants"
                end

                local NodeName = Node:GetName()
                if HasSiblingNamed(Destination :: IDirectory, NodeName, Node) then
                    return nil, `a sibling named "{NodeName}" already exists at the destination`
                end

                Node:SetParent(Destination :: IDirectory)

                return true, ""
            end,
		}
    end,
}
