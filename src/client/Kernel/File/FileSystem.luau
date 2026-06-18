-- TODO: add method to open files, locking them
-- and add rename method


const Handle = require("@kernel/Core/Handle")
const CPath = require("@kernel/File/Path")
const Context = require("@kernel/File/Context")
const Result = require("@kernel/Core/Result")
const Log = require("@kernel/Core/Log")
const NodeFactory = require("@kernel/File/NodeFactory")

-- stylua: ignore
local FileSystemFolder = game:GetService("StarterPlayer")
							:FindFirstChild("Client")
							:FindFirstChild("Static")
							:FindFirstChild("FileSystem")

type Result<T> = Result.Result<T>
type CPath = CPath.CPath
type Context = Context.Context
type Handle = Handle.Handle

local FileSystem = {
    m_Initialized = false,
    m_RootNode = NodeFactory.Create()
}

function FileSystem.GetInstance(self: typeof(FileSystem))
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
					local FileName = File.FileName
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

function FileSystem.Create(self: typeof(FileSystem), Path: CPath, Type: "Folder" | "File", Context: Context): Result<Handle>
    if not self.m_Initialized then
        return Result.new(false, "File System was not initialized")
    end

    if not Path:IsValid() then
        return Result.new(false, "Provided path was invalid")
    end

    local PathAbsoluteStr = Path:ToStringAbsolute(Context)
    local AbsolutePath: CPath? = PathAbsoluteStr ~= "" and CPath.new(PathAbsoluteStr)
    if not AbsolutePath or not AbsolutePath:IsValid() then
        return Result.new(false, "Unable to convert path to absolute")
    end

    local PathNodes = AbsolutePath:GetNodes()
    local CurrentNode: NodeFactory.Node = self.m_RootNode

    for i, PathNode in PathNodes do
        if PathNode.Type == "Escape" then
            if CurrentNode.Parent == nil then
                return Result.new(false, "Cannot escape orphaned node")
            else
                CurrentNode = NodeFactory.Get(CurrentNode.Parent)
                if not CurrentNode then
                    return Result.new(false, "Parent handle pointed to non-existent node")
                end
            end
        end

        for _, ChildHandle in CurrentNode.Children do
            local ChildNode = NodeFactory.Get(ChildHandle)
            if not ChildNode then
                return Result.new(false, "Child handle pointed to non-existent node")
            end

            if ChildNode.Name == PathNode.Name then
                CurrentNode = ChildNode
                break
            end
        end

        -- No child node exists, create one
        local IsLastNode = i == #PathNodes

        local Node = NodeFactory.Create()
        Node.Type = IsLastNode and Type or "Folder"
        Node.Name = PathNode.Name

        NodeFactory.Move(Node.Handle, CurrentNode.Handle)

        CurrentNode = Node
    end

    return Result.new(true, "", CurrentNode.Handle)
end

function FileSystem.Resolve(self: typeof(FileSystem), Path: CPath, Context: Context): Result<Handle>
    if not self.m_Initialized then
        return Result.new(false, "File System was not initialized")
    end

    if not Path:IsValid() then
        return Result.new(false, "Provided path was invalid")
    end

    local PathAbsoluteStr = Path:ToStringAbsolute(Context)
    local AbsolutePath: CPath? = PathAbsoluteStr ~= "" and CPath.new(PathAbsoluteStr)
    if not AbsolutePath or not AbsolutePath:IsValid() then
        return Result.new(false, "Unable to convert path to absolute")
    end

    local PathNodes = AbsolutePath:GetNodes()
    local CurrentNode: NodeFactory.Node = self.m_RootNode

    for i, PathNode in PathNodes do
        if PathNode.Type == "Escape" then
            if CurrentNode.Parent == nil then
                return Result.new(false, "Cannot escape orphaned node")
            else
                CurrentNode = NodeFactory.Get(CurrentNode.Parent)
                if not CurrentNode then
                    return Result.new(false, "Parent handle pointed to non-existent node")
                end
            end
        end

        for _, ChildHandle in CurrentNode.Children do
            local ChildNode = NodeFactory.Get(ChildHandle)
            if not ChildNode then
                return Result.new(false, "Child handle pointed to non-existent node")
            end

            if ChildNode.Name == PathNode.Name then
                CurrentNode = ChildNode
                break
            end
        end

        -- No child node exists throw
        return Result.new(false, `Missing "{PathNode.Name}" in "{PathAbsoluteStr}"`)
    end

    return Result.new(true, "", CurrentNode.Handle)
end

function FileSystem.Move(self: typeof(FileSystem), ChildHandle: Handle, ParentHandle: Handle)
    NodeFactory.Move(ChildHandle, ParentHandle)
end

function FileSystem.Delete(self: typeof(FileSystem), NodeHandle: Handle)
    -- TODO: need to built an array of everything that will be deleted
    -- then check if its locked or not

    NodeFactory.Delete(NodeHandle)
end

function FileSystem.Write(self: typeof(FileSystem), NodeHandle: Handle, Contents: string): Result<nil>
    local Node = NodeFactory.Get(NodeHandle)
    if not Node then
        return Result.new(false, `Handle pointed to non-existent node`)
    end

    if Node.Type ~= "File" then
        return Result.new(false, "Cannot write to non-file")
    end

    Node.Contents = Contents
    Node.UpdatedAt = os.clock()

    return Result.new(true, "")
end

function FileSystem.Read(self: typeof(FileSystem), NodeHandle: Handle): Result<string>
    local Node = NodeFactory.Get(NodeHandle)
    if not Node then
        return Result.new(false, `Handle pointed to non-existent node`)
    end

    if Node.Type ~= "File" then
        return Result.new(false, "Cannot read from non-file")
    end

    return Result.new(true, "", Node.Contents)
end

return FileSystem
