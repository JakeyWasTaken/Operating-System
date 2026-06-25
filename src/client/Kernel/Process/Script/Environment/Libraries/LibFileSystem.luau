--[[

	LibFileSystem / fs

	Testing only library, disabled out of studio

]]

const FilePath = require("@kernel/File/FileSystem/FilePath")
const FileSystemManager = require("@kernel/File/FileSystemManager")

type CFilePath = FilePath.CFilePath

return {
	Name = "fs",
	Enabled = true,
	MakeLibrary = function(LibraryPID: number, ScriptPath: CFilePath)
        -- For relative files we expand using script path here,
        -- we don't use file context just for clarity reasons
        local function ResolveScriptPath(PathString: string): CFilePath
            local RequestedPath = FilePath.new(PathString)
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

                CreateFile = function(Path: string): boolean
                    assert(typeof(Path) == "string", "Expected Path to be of type string")

                    assert(shared.ProcessFactory, `ProcessFactory was not ready`)
                    local Process = shared.ProcessFactory.GetProcess(LibraryPID)

                    local FileSystem = FileSystemManager.GetActiveFileSystem()
                    if not FileSystem then
                        return
                    end

                    local RequestedPath = ResolveScriptPath(Path)
                    if not RequestedPath:IsValid() then
                        return false
                    end

                    local Result = FileSystem:CreateFile(RequestedPath, Process.FileContext)
                    return Result.Success
                end,

                CreateDirectory = function(Path: string): boolean
                    assert(typeof(Path) == "string", "Expected Path to be of type string")

                    assert(shared.ProcessFactory, `ProcessFactory was not ready`)
                    local Process = shared.ProcessFactory.GetProcess(LibraryPID)

                    local FileSystem = FileSystemManager.GetActiveFileSystem()
                    if not FileSystem then
                        return false
                    end

                    local RequestedPath = ResolveScriptPath(Path)
                    if not RequestedPath:IsValid() then
                        return false
                    end

                    local Result = FileSystem:CreateDirectory(RequestedPath, Process.FileContext)
                    return Result.Success
                end,

                --- Deletes the node at Path, along with any descendants.
                ---
                --- Fails if the node (or any descendant) is currently locked - close any
                --- open handles on it first.
                Delete = function(Path: string): boolean
                    assert(typeof(Path) == "string", "Expected Path to be of type string")

                    assert(shared.ProcessFactory, `ProcessFactory was not ready`)
                    local Process = shared.ProcessFactory.GetProcess(LibraryPID)

                    local FileSystem = FileSystemManager.GetActiveFileSystem()
                    if not FileSystem then
                        return false
                    end

                    local RequestedPath = ResolveScriptPath(Path)
                    if not RequestedPath:IsValid() then
                        return false
                    end

                    local Node = FileSystem:ResolvePath(RequestedPath, Process.FileContext)
                    if not Node then
                        return false
                    end

                    return FileSystem:DeleteNode(Node:GetHandle())
                end,

                -- ------------------------------ Open / Close ------------------------------- --

                Open = function(Path: string, Exclusive: boolean?): string?
                    assert(typeof(Path) == "string", "Expected Path to be of type string")

                    assert(shared.ProcessFactory, `ProcessFactory was not ready`)
                    local Process = shared.ProcessFactory.GetProcess(LibraryPID)

                    local FileSystem = FileSystemManager.GetActiveFileSystem()
                    if not FileSystem then
                        return
                    end

                    local RequestedPath = ResolveScriptPath(Path)
                    if not RequestedPath:IsValid() then
                        return
                    end

                    local Node = FileSystem:ResolvePath(RequestedPath, Process.FileContext)
                    if not Node or not Node:IsFile() or Node:IsLocked() then
                        return
                    end

                    local NodeHandle = Node:GetHandle()
                    if Exclusive then
                        FileSystem:LockNode(NodeHandle, LibraryPID)
                    end

                    local ScopedHandle = Process:GetScopedHandle(NodeHandle) or Process:CreateScopedHandle(NodeHandle)
                    return ScopedHandle
                end,

                -- ----------------------------- Node Operations ---------------------------- --

                Close = function(ScopedHandle: string)
                    assert(shared.ProcessFactory, `ProcessFactory was not ready`)
                    local Process = shared.ProcessFactory.GetProcess(LibraryPID)

                    local FileSystem = FileSystemManager.GetActiveFileSystem()
                    if not FileSystem then
                        return
                    end

                    local GlobalHandle = Process:GetGlobalHandle(ScopedHandle)
                    if GlobalHandle then
                        FileSystem:UnlockNode(GlobalHandle, LibraryPID)
                    end

                    Process:RemoveScopedHandle(ScopedHandle)
                end,

                Read = function(ScopedHandle: string)
                    assert(shared.ProcessFactory, `ProcessFactory was not ready`)
                    local Process = shared.ProcessFactory.GetProcess(LibraryPID)

                    local FileSystem = FileSystemManager.GetActiveFileSystem()
                    if not FileSystem then
                        return
                    end

                    local GlobalHandle = Process:GetGlobalHandle(ScopedHandle)
                    if not GlobalHandle then
                        return
                    end

                    local Node = FileSystem:ResolveHandle(GlobalHandle)
                    if not Node then
                        return
                    end

                    return Node:Read()
                end,

                Write = function(ScopedHandle: string, Data: string, Offset: number)
                    assert(typeof(ScopedHandle) == "string", "Expected ScopedHandle to be of type string")
                    assert(typeof(Data) == "string", "Expected data to be of type string")
                    assert(Offset and typeof(Offset) == "number", "Expected offset to be of type number")
                    assert(shared.ProcessFactory, `ProcessFactory was not ready`)
                    local Process = shared.ProcessFactory.GetProcess(LibraryPID)

                    local FileSystem = FileSystemManager.GetActiveFileSystem()
                    if not FileSystem then
                        return
                    end

                    local GlobalHandle = Process:GetGlobalHandle(ScopedHandle)
                    if not GlobalHandle then
                        return
                    end

                    local Node = FileSystem:ResolveHandle(GlobalHandle)
                    if not Node then
                        return
                    end

                    Node:Write(Data, Offset)
                end,

                GetMetadata = function(ScopedHandle: string)
                    assert(typeof(ScopedHandle) == "string", "Expected ScopedHandle to be of type string")
                    assert(shared.ProcessFactory, `ProcessFactory was not ready`)
                    local Process = shared.ProcessFactory.GetProcess(LibraryPID)

                    local FileSystem = FileSystemManager.GetActiveFileSystem()
                    if not FileSystem then
                        return
                    end

                    local GlobalHandle = Process:GetGlobalHandle(ScopedHandle)
                    if not GlobalHandle then
                        return
                    end

                    local Node = FileSystem:ResolveHandle(GlobalHandle)
                    if not Node then
                        return
                    end

                    return Node:GetMetadata()
                end,
		}
    end,
}
