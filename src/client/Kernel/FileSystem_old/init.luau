local Context = require("@kernel/FileSystem/Context")
local General = require("@kernel/Core/General/General")
local Log = require("@kernel/Core/Log")
local NodeFactory = require("@kernel/FileSystem/NodeFactory")
local NodeLocks = require("@kernel/FileSystem/NodeLocks")
local Parser = require("@kernel/FileSystem/Parser")
local Result = require("@kernel/Core/Result")
local VirtualNode = require("@kernel/FileSystem/VirtualNode")

-- stylua: ignore
local FileSystemFolder = game:GetService("StarterPlayer")
							:FindFirstChild("Client")
							:FindFirstChild("Static")
							:FindFirstChild("FileSystem")

type Result<T> = Result.Result<T>

export type Node = NodeFactory.Node
export type VirtualNode = VirtualNode.VirtualNode
export type Context = Context.Context

export type InterfaceResult = { Success: boolean, Reason: string }
export type FileSystem = {
	-- --------------------------------- Methods -------------------------------- --
	GetInstance: (self: FileSystem) -> FileSystem,

	--- Not used to get the full file path, for the full file path use ::GetNodePath
	GetFullPath: (self: FileSystem, Path: string, Context: Context?) -> string,
	GetNodePath: (self: FileSystem, Handle: string) -> string,
	GetNodeFromHandle: (self: FileSystem, Handle: string) -> Result<VirtualNode>,

	DoesNodeHaveChild: (self: FileSystem, Node: Node, Name: string) -> boolean,

	m_GetNodeFromHandle: (self: FileSystem, Handle: string) -> Result<Node>,
	m_Resolve: (self: FileSystem, Path: string, Context: Context?) -> Result<Node>,

	-- Interfaces
	Resolve: (self: FileSystem, Path: string, Context: Context?) -> Result<VirtualNode>,
	Create: (self: FileSystem, Path: string, Type: "File" | "Folder", Context: Context?) -> Result<VirtualNode>,
	Delete: (self: FileSystem, Path: string, Context: Context?) -> Result<nil>,

	-- --------------------------------- Members -------------------------------- --
	Initialized: boolean,

	m_RootNode: Node,
}

local FileSystem: FileSystem = {} :: any

function FileSystem:GetInstance()
	if self.Initialized then
		return self
	end

	self.m_RootNode = NodeFactory.new()

	-- Load in our pre-defined file system (src/client/FileSystem/...)
	Log.debug("Loading static file system")
	local function LoadFolder(Folder: Folder, Path: string)
		for _, Child in Folder:GetChildren() do
			if Child:IsA("Folder") then
				LoadFolder(Child, `{Path}/{Child.Name}`)
			elseif Child:IsA("ModuleScript") then
				xpcall(function()
					local File = require(Child)
					local FileName = File.FileName
					local Contents = File.Contents

					local Result = self:Create(`{Path}/{FileName}`, "File")
					assert(Result.Success, Result.Reason)

					Result.Value:Write(Contents)
				end, warn)
			end
		end
	end

	LoadFolder(FileSystemFolder, "/")

	self.Initialized = true

	return self
end

function FileSystem:GetFullPath(Path: string, Context: Context?): string
	if not Context then
		return Path
	end

	local Type = Parser.GetPathType(Path)

	if Type == "Absolute" then
		return Path
	end

	return Context.WorkingDirectory .. "/" .. Path
end

function FileSystem:GetNodePath(Handle: string): string
	local Node = NodeFactory.Registry[Handle]
	assert(Node, `No node of handle "{Handle}" exists`)

	local BackwardsPath = {}

	local CurrentNode = Node
	while CurrentNode.Type ~= "Root" do
		table.insert(BackwardsPath, CurrentNode.Name)

		CurrentNode = CurrentNode.Parent
	end

	return "/" .. table.concat(General.ReverseArray(BackwardsPath), "/")
end

function FileSystem:GetNodeFromHandle(Handle: string): Result<VirtualNode>
	local NodeResult = self:m_GetNodeFromHandle(Handle)
	if not NodeResult.Success then
		return NodeResult
	end

	return Result.new(true, "", VirtualNode.Wrap(NodeResult.Value))
end

function FileSystem:DoesNodeHaveChild(Node: Node, Name: string): boolean
	return General.SearchTable(Node.Children, function(ChildNode)
		return ChildNode.Name == Name
	end) ~= nil
end

function FileSystem:m_GetNodeFromHandle(Handle: string): Result<Node>
	local Node = NodeFactory.Registry[Handle]
	if not Node then
		return Result.new(false, `No node of handle "{Handle}" exists.`)
	end

	return Result.new(true, "", Node)
end

function FileSystem:m_Resolve(Path: string, Context: Context?): Result<Node>
	local RealPath = FileSystem:GetFullPath(Path, Context)
	local TraversalSteps = Parser.Parse(RealPath).Traversal

	local CurrentNode = self.m_RootNode

	for _, Step in TraversalSteps do
		if Step.Type == "Escape" then
			if CurrentNode.Parent == nil then -- If we try and escape the root node
				return Result.new(false, "Cannot escape file system")
			end

			CurrentNode = CurrentNode.Parent
			continue
		end

		-- Search current node for any children with the name
		local NodeIndex = General.SearchTable(CurrentNode.Children, function(Node)
			return Node.Name == Step.Name
		end)

		if not NodeIndex then -- No node exists under the current node with the name
			return Result.new(false, `No node exists at "{self:GetNodePath(CurrentNode.Handle)}/{Step.Name}"`)
		end

		CurrentNode = CurrentNode.Children[NodeIndex]
	end

	return Result.new(true, "", CurrentNode)
end

function FileSystem:Resolve(Path: string, Context: Context?): Result<VirtualNode>
	local NodeResult = self:m_Resolve(Path, Context)
	if not NodeResult.Success then
		return NodeResult
	end

	return Result.new(true, "", VirtualNode.Wrap(NodeResult.Value))
end

function FileSystem:Create(Path: string, Type: "File" | "Folder", Context: Context?): Result<VirtualNode>
	local RealPath = FileSystem:GetFullPath(Path, Context)
	local TraversalSteps = Parser.Parse(RealPath).Traversal

	local CurrentNode = self.m_RootNode

	for i, Step in TraversalSteps do
		if Step.Type == "Escape" then
			if CurrentNode.Parent == nil then -- If we try and escape the root node
				return Result.new(false, "Cannot escape file system")
			end

			CurrentNode = CurrentNode.Parent
			continue
		end

		-- Search current node for any children with the name
		local NodeIndex = General.SearchTable(CurrentNode.Children, function(Node)
			return Node.Name == Step.Name
		end)

		if not NodeIndex then
			-- We need to create the node here
			local NewNode = NodeFactory.new()
			NewNode.Parent = CurrentNode
			NewNode.Name = Step.Name
			NewNode.Type = i == #TraversalSteps and Type or "Folder"

			table.insert(CurrentNode.Children, NewNode)

			CurrentNode = NewNode
		else
			-- If we are at the final step (creating the node)
			-- and it already exists, throw an error
			if i == #TraversalSteps then
				return Result.new(false, `This specific {string.lower(Type)} already exists at this location`)
			end

			CurrentNode = CurrentNode.Children[NodeIndex]
		end
	end

	return Result.new(true, "", VirtualNode.Wrap(CurrentNode))
end

function FileSystem:Delete(Path: string, Context: Context?): Result<nil>
	local NodeResult = self:m_Resolve(Path, Context)
	if not NodeResult.Success then
		return NodeResult
	end

	local Node = NodeResult.Value
	if Node.Type == "Root" then
		return Result.new(false, "Cannot delete root node")
	end

	if NodeLocks.IsLocked(Node.Handle) then
		return Result.new(false, "Node is locked")
	end

	-- Recursively remove node's children from registries
	local function RecursiveClear(Node)
		for _, Child in Node.Children do
			RecursiveClear(Child)
		end

		NodeFactory.Registry[Node.Handle] = nil
		VirtualNode.Cache[Node.Handle] = nil
	end

	RecursiveClear(Node)

	-- Remove the node from its parent
	local NodeIndex = General.SearchTable(Node.Parent.Children, function(ChildNode)
		return ChildNode.Handle == Node.Handle
	end)

	if not NodeIndex then
		return Result.new(false, "Parent ref didn't hold node as a child")
	end

	table.remove(Node.Parent.Children, NodeIndex)
	return Result.new(true, "")
end

return FileSystem:GetInstance()
