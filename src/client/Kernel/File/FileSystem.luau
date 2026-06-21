-- TODO: add method to open files, locking them
-- and add rename method


const Handle = require("@core/Handle")
const CPath = require("@kernel/File/Path")
const Context = require("@kernel/File/Context")
const Result = require("@core/Result")
const Log = require("@core/Log")
const NodeRegistry = require("@kernel/File/NodeRegistry")
const NodeLocks = require("@kernel/File/NodeLocks")
const Signal = require("@core/Signal")

-- stylua: ignore
local FileSystemFolder = game:GetService("StarterPlayer")
							:FindFirstChild("Client")
							:FindFirstChild("Static")

type Signal<T...> = Signal.Signal<T...>
type Result<T> = Result.Result<T>
type CPath = CPath.CPath
type Context = Context.Context
type NodeType = NodeRegistry.NodeType
type Handle = Handle.Handle

local FileSystem = {
    OnNodeCreated = Signal.new() :: Signal<Handle>,
    --- Fired just prior to the node being deleted
    OnNodeDeleted = Signal.new() :: Signal<Handle>,

    m_Initialized = false,
    m_RootNode = NodeRegistry.Create()
}

function FileSystem:Initialize()
    self = self :: typeof(FileSystem)

    if self.m_Initialized then
        return self
    end

    self.m_Initialized = true

    -- Load in our pre-defined file system (src/client/FileSystem/...)
	Log.debug("Loading static file system")
	local function LoadFolder(Folder: Folder, PathString: string)
		for _, Child in Folder:GetChildren() do
			if Child:IsA("Folder") then
				LoadFolder(Child, `{PathString}/{Child.Name}`)
			elseif Child:IsA("ModuleScript") then
				xpcall(function()
					local File = require(Child)
					local FileName = File.Name
					local Contents = File.Contents

                    local Path = CPath.new(`{PathString}/{FileName}`)
					local Result = self:Create(Path, "File", Context.new())
					assert(Result.Success, Result.Reason)

                    self:Write(Result.Value, Contents)

                    Log.debug(`Made static file "{Path:ToString()}"`)
				end, warn)
			end
		end
	end

	LoadFolder(FileSystemFolder, "/")

    return self
end

function FileSystem:Create(Path: CPath, Type: "Folder" | "File", Context: Context): Result<Handle>
    self = self :: typeof(FileSystem)

    if not self.m_Initialized then
        return Result.new(false, "File System was not initialized")
    end

    if not Path:IsValid() then
        return Result.new(false, "Provided path was invalid")
    end

    local PathAbsoluteStr = Path:ToStringAbsolute(Context)
    local AbsolutePath = PathAbsoluteStr ~= "" and CPath.new(PathAbsoluteStr) or nil
    if not AbsolutePath or not AbsolutePath:IsValid() then
        return Result.new(false, "Unable to convert path to absolute")
    end

    local PathNodes = AbsolutePath:GetNodes()
    local CurrentNode = self.m_RootNode

    for i, PathNode in PathNodes do
        if PathNode.Type == "Escape" then
            if CurrentNode.Parent == nil then
                return Result.new(false, "Cannot escape orphaned node")
            else
                CurrentNode = NodeRegistry.Get(CurrentNode.Parent)
                if not CurrentNode then
                    return Result.new(false, "Parent handle pointed to non-existent node")
                end
            end

            continue
        end

        local Exists = false
        for _, ChildHandle in CurrentNode.Children do
            local ChildNode = NodeRegistry.Get(ChildHandle)
            if not ChildNode then
                return Result.new(false, "Child handle pointed to non-existent node")
            end

            if ChildNode.Name == PathNode.Name then
                CurrentNode = ChildNode
                Exists = true
                break
            end
        end

        if Exists then
            continue
        end

        -- No child node exists, create one
        local IsLastNode = i == #PathNodes

        local Node = NodeRegistry.Create()
        Node.Type = IsLastNode and Type or "Folder"
        Node.Name = PathNode.Name

        NodeRegistry.Move(Node.Handle, CurrentNode.Handle)

        CurrentNode = Node
    end

    self.OnNodeCreated:Fire(CurrentNode.Handle)

    return Result.new(true, "", CurrentNode.Handle)
end

function FileSystem:Resolve(Path: CPath, Context: Context): Result<Handle>
    self = self :: typeof(FileSystem)

    if not self.m_Initialized then
        return Result.new(false, "File System was not initialized")
    end

    if not Path:IsValid() then
        return Result.new(false, "Provided path was invalid")
    end

    local PathAbsoluteStr = Path:ToStringAbsolute(Context)
    local AbsolutePath: CPath? = PathAbsoluteStr ~= "" and CPath.new(PathAbsoluteStr) or nil
    if not AbsolutePath or not AbsolutePath:IsValid() then
        return Result.new(false, "Unable to convert path to absolute")
    end

    local PathNodes = AbsolutePath:GetNodes()
    local CurrentNode = self.m_RootNode

    for i, PathNode in PathNodes do
        if PathNode.Type == "Escape" then
            if CurrentNode.Parent == nil then
                return Result.new(false, "Cannot escape orphaned node")
            else
                CurrentNode = NodeRegistry.Get(CurrentNode.Parent)
                if not CurrentNode then
                    return Result.new(false, "Parent handle pointed to non-existent node")
                end
            end

            continue
        end

        local Exists = false
        for _, ChildHandle in CurrentNode.Children do
            local ChildNode = NodeRegistry.Get(ChildHandle)
            if not ChildNode then
                return Result.new(false, "Child handle pointed to non-existent node")
            end

            if ChildNode.Name == PathNode.Name then
                CurrentNode = ChildNode
                Exists = true
                break
            end
        end

        if Exists then
            continue
        end

        -- No child node exists throw
        return Result.new(false, `Missing "{PathNode.Name}" in "{PathAbsoluteStr}"`)
    end

    return Result.new(true, "", CurrentNode.Handle)
end

function FileSystem:Move(ChildHandle: Handle, ParentHandle: Handle)
    NodeRegistry.Move(ChildHandle, ParentHandle)
end

function FileSystem:Delete(NodeHandle: Handle): Result<nil>
    self = self :: typeof(FileSystem)

    local Node = NodeRegistry.Get(NodeHandle)
    if not Node then
        return Result.new(false, "Handle pointed to non-existent node")
    end

    local Handles = { NodeHandle }

    local function GetChildren(Node)
        for _, ChildHandle in Node.Children do
            local ChildNode = NodeRegistry.Get(ChildHandle)
            if not ChildNode then
                continue
            end

            table.insert(Handles, ChildHandle)
            GetChildren(ChildNode)
        end
    end

    GetChildren(Node)

    for _, Handle in Handles do
        if NodeLocks.IsLocked(Handle) then
            return Result.new(false, "Node locked")
        end
    end

    -- Now call our signals
    for _, Handle in Handles do
        self.OnNodeDeleted:Fire(Handle)
    end

    NodeRegistry.Delete(NodeHandle)
    return Result.new(true, "")
end

function FileSystem:Write(NodeHandle: Handle, Contents: string): Result<nil>
    local Node = NodeRegistry.Get(NodeHandle)
    if not Node then
        return Result.new(false, `Handle pointed to non-existent node`)
    end

    if Node.Type ~= "File" then
        return Result.new(false, "Cannot write to non-file")
    end

    if NodeLocks.IsLocked(NodeHandle) then
        return Result.new(false, "Node locked")
    end

    Node.Contents = Contents
    Node.UpdatedAt = os.clock()

    return Result.new(true, "")
end

function FileSystem:Read(NodeHandle: Handle): Result<string>
    local Node = NodeRegistry.Get(NodeHandle)
    if not Node then
        return Result.new(false, `Handle pointed to non-existent node`)
    end

    if Node.Type ~= "File" then
        return Result.new(false, "Cannot read from non-file")
    end

    return Result.new(true, "", Node.Contents)
end

function FileSystem:GetType(NodeHandle: Handle): Result<NodeType>
    local Node = NodeRegistry.Get(NodeHandle)
    if not Node then
        return Result.new(false, `Handle pointed to non-existent node`)
    end

    return Result.new(true, "", Node.Type)
end

function FileSystem:GetName(NodeHandle: Handle): Result<string>
    local Node = NodeRegistry.Get(NodeHandle)
    if not Node then
        return Result.new(false, `Handle pointed to non-existent node`)
    end

    return Result.new(true, "", Node.Name)
end

return FileSystem
