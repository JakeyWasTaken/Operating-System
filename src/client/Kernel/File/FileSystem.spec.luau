local FileSystem = require("@kernel/File/FileSystem")
local CPath = require("@kernel/File/Path")
local Context = require("@kernel/File/Context")
local NodeLocks = require("@kernel/File/NodeLocks")
local Handle = require("@core/Handle")

return function()
	FileSystem:Initialize()

	local TestContext = Context.new()
	TestContext.HomeDirectory = "\\home\\spec"
	TestContext.WorkingDirectory = "\\"

	-- Each test gets its own unique scratch folder so the shared FileSystem
	-- singleton's state doesn't leak between specs.
	local function ScratchBase(): string
		return `\\__spec_fs__\\{Handle()}`
	end

	-- -------------------------------------------------------------------------
	-- Initialize
	-- -------------------------------------------------------------------------
	describe("Initialize", function()
		it("returns the FileSystem singleton", function()
			expect(FileSystem:Initialize()).to.equal(FileSystem)
		end)

		it("is idempotent when called multiple times", function()
			FileSystem:Initialize()
			FileSystem:Initialize()
			expect(FileSystem.m_Initialized).to.equal(true)
		end)
	end)

	-- -------------------------------------------------------------------------
	-- Create
	-- -------------------------------------------------------------------------
	describe("Create", function()
		it("fails for an invalid path", function()
			local Result = FileSystem:Create(CPath.new(""), "File", TestContext)
			expect(Result.Success).to.equal(false)
		end)

		it("creates a file and returns its handle", function()
			local Path = CPath.new(`{ScratchBase()}\\leaf.txt`)
			local Result = FileSystem:Create(Path, "File", TestContext)

			expect(Result.Success).to.equal(true)
			expect(Result.Value).never.to.equal(nil)
		end)

		it("creates intermediate folders as 'Folder' nodes", function()
			local Base = ScratchBase()
			local Result = FileSystem:Create(CPath.new(`{Base}\\sub\\leaf.txt`), "File", TestContext)
			expect(Result.Success).to.equal(true)

			local FolderResult = FileSystem:Resolve(CPath.new(`{Base}\\sub`), TestContext)
			expect(FolderResult.Success).to.equal(true)
			expect(FileSystem:GetType(FolderResult.Value).Value).to.equal("Folder")
		end)

		it("creates the final node with the requested type", function()
			local Path = CPath.new(`{ScratchBase()}\\leaf.txt`)
			local Result = FileSystem:Create(Path, "File", TestContext)

			expect(FileSystem:GetType(Result.Value).Value).to.equal("File")
		end)

		it("returns the same handle when called again with the same path", function()
			local Path = CPath.new(`{ScratchBase()}\\leaf.txt`)
			local First = FileSystem:Create(Path, "File", TestContext)
			local Second = FileSystem:Create(Path, "File", TestContext)

			expect(First.Value).to.equal(Second.Value)
		end)

		it("fires OnNodeCreated with the new handle", function()
			local Fired, FiredHandle = false, nil
			local Connection = FileSystem.OnNodeCreated:Connect(function(NodeHandle)
				Fired = true
				FiredHandle = NodeHandle
			end)

			local Result = FileSystem:Create(CPath.new(`{ScratchBase()}\\leaf.txt`), "File", TestContext)
			Connection:Disconnect()

			expect(Fired).to.equal(true)
			expect(FiredHandle).to.equal(Result.Value)
		end)
	end)

	-- -------------------------------------------------------------------------
	-- Resolve
	-- -------------------------------------------------------------------------
	describe("Resolve", function()
		it("fails for an invalid path", function()
			local Result = FileSystem:Resolve(CPath.new(""), TestContext)
			expect(Result.Success).to.equal(false)
		end)

		it("fails when a segment of the path does not exist", function()
			local Result = FileSystem:Resolve(CPath.new(ScratchBase()), TestContext)
			expect(Result.Success).to.equal(false)
		end)

		it("resolves a previously created path to its handle", function()
			local Path = CPath.new(`{ScratchBase()}\\leaf.txt`)
			local CreateResult = FileSystem:Create(Path, "File", TestContext)

			local ResolveResult = FileSystem:Resolve(Path, TestContext)

			expect(ResolveResult.Success).to.equal(true)
			expect(ResolveResult.Value).to.equal(CreateResult.Value)
		end)
	end)

	-- -------------------------------------------------------------------------
	-- Move
	-- -------------------------------------------------------------------------
	describe("Move", function()
		it("relocates a node so it resolves under its new parent", function()
			local BaseA = ScratchBase()
			local BaseB = ScratchBase()

			local FileResult = FileSystem:Create(CPath.new(`{BaseA}\\leaf.txt`), "File", TestContext)
			local FolderResult = FileSystem:Create(CPath.new(BaseB), "Folder", TestContext)

			FileSystem:Move(FileResult.Value, FolderResult.Value)

			local OldLocation = FileSystem:Resolve(CPath.new(`{BaseA}\\leaf.txt`), TestContext)
			local NewLocation = FileSystem:Resolve(CPath.new(`{BaseB}\\leaf.txt`), TestContext)

			expect(OldLocation.Success).to.equal(false)
			expect(NewLocation.Success).to.equal(true)
			expect(NewLocation.Value).to.equal(FileResult.Value)
		end)
	end)

	-- -------------------------------------------------------------------------
	-- Delete
	-- -------------------------------------------------------------------------
	describe("Delete", function()
		it("fails for a handle that does not exist", function()
			local Result = FileSystem:Delete("not-a-real-handle")
			expect(Result.Success).to.equal(false)
		end)

		it("deletes an unlocked node so it no longer resolves", function()
			local Path = CPath.new(`{ScratchBase()}\\leaf.txt`)
			local CreateResult = FileSystem:Create(Path, "File", TestContext)

			local DeleteResult = FileSystem:Delete(CreateResult.Value)
			expect(DeleteResult.Success).to.equal(true)

			expect(FileSystem:Resolve(Path, TestContext).Success).to.equal(false)
		end)

		it("fails when the node itself is locked", function()
			local Path = CPath.new(`{ScratchBase()}\\leaf.txt`)
			local CreateResult = FileSystem:Create(Path, "File", TestContext)

			NodeLocks.LockFile(CreateResult.Value, 101)
			local DeleteResult = FileSystem:Delete(CreateResult.Value)
			NodeLocks.ReleaseProgramLocks(101)

			expect(DeleteResult.Success).to.equal(false)
		end)

		it("fails when a descendant of the node is locked", function()
			local Base = ScratchBase()
			local FolderResult = FileSystem:Create(CPath.new(Base), "Folder", TestContext)
			local ChildResult = FileSystem:Create(CPath.new(`{Base}\\leaf.txt`), "File", TestContext)

			NodeLocks.LockFile(ChildResult.Value, 102)
			local DeleteResult = FileSystem:Delete(FolderResult.Value)
			NodeLocks.ReleaseProgramLocks(102)

			expect(DeleteResult.Success).to.equal(false)
		end)

		it("fires OnNodeDeleted prior to removal", function()
			local Path = CPath.new(`{ScratchBase()}\\leaf.txt`)
			local CreateResult = FileSystem:Create(Path, "File", TestContext)

			local Fired, FiredHandle = false, nil
			local Connection = FileSystem.OnNodeDeleted:Connect(function(NodeHandle)
				Fired = true
				FiredHandle = NodeHandle
			end)

			FileSystem:Delete(CreateResult.Value)
			Connection:Disconnect()

			expect(Fired).to.equal(true)
			expect(FiredHandle).to.equal(CreateResult.Value)
		end)
	end)

	-- -------------------------------------------------------------------------
	-- Write / Read
	-- -------------------------------------------------------------------------
	describe("Write", function()
		it("fails for a handle that does not exist", function()
			expect(FileSystem:Write("not-a-real-handle", "hello").Success).to.equal(false)
		end)

		it("fails when writing to a Folder", function()
			local FolderResult = FileSystem:Create(CPath.new(ScratchBase()), "Folder", TestContext)
			expect(FileSystem:Write(FolderResult.Value, "hello").Success).to.equal(false)
		end)

		it("fails when the node is locked", function()
			local CreateResult = FileSystem:Create(CPath.new(`{ScratchBase()}\\leaf.txt`), "File", TestContext)

			NodeLocks.LockFile(CreateResult.Value, 103)
			local WriteResult = FileSystem:Write(CreateResult.Value, "hello")
			NodeLocks.ReleaseProgramLocks(103)

			expect(WriteResult.Success).to.equal(false)
		end)

		it("stores contents that can be read back", function()
			local CreateResult = FileSystem:Create(CPath.new(`{ScratchBase()}\\leaf.txt`), "File", TestContext)

			expect(FileSystem:Write(CreateResult.Value, "hello world").Success).to.equal(true)
			expect(FileSystem:Read(CreateResult.Value).Value).to.equal("hello world")
		end)
	end)

	describe("Read", function()
		it("fails for a handle that does not exist", function()
			expect(FileSystem:Read("not-a-real-handle").Success).to.equal(false)
		end)

		it("fails when reading from a Folder", function()
			local FolderResult = FileSystem:Create(CPath.new(ScratchBase()), "Folder", TestContext)
			expect(FileSystem:Read(FolderResult.Value).Success).to.equal(false)
		end)
	end)

	-- -------------------------------------------------------------------------
	-- GetType / GetName
	-- -------------------------------------------------------------------------
	describe("GetType", function()
		it("fails for a handle that does not exist", function()
			expect(FileSystem:GetType("not-a-real-handle").Success).to.equal(false)
		end)

		it("returns the node's type", function()
			local FolderResult = FileSystem:Create(CPath.new(ScratchBase()), "Folder", TestContext)
			expect(FileSystem:GetType(FolderResult.Value).Value).to.equal("Folder")
		end)
	end)

	describe("GetName", function()
		it("fails for a handle that does not exist", function()
			expect(FileSystem:GetName("not-a-real-handle").Success).to.equal(false)
		end)

		it("returns the node's name", function()
			local CreateResult = FileSystem:Create(CPath.new(`{ScratchBase()}\\leaf.txt`), "File", TestContext)
			expect(FileSystem:GetName(CreateResult.Value).Value).to.equal("leaf.txt")
		end)
	end)
end
