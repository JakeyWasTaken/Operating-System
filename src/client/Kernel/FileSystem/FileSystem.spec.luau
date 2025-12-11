local FileSystem = require("@kernel/FileSystem")
local NodeFactory = require("@kernel/FileSystem/NodeFactory")

return function()
	local Fs, Context

	beforeEach(function()
		-- Clear NodeFactory registry for clean slate
		for Handle in NodeFactory.Registry do
			NodeFactory.Registry[Handle] = nil
		end

		FileSystem.Initialized = false
		Fs = FileSystem:GetInstance()

		Context = { WorkingDirectory = "/" }
	end)

	describe("FileSystem", function()
		it("CreatesAndResolvesANode", function()
			local result = FileSystem:Create("/testFolder", "Folder")
			expect(result.Success).to.equal(true)

			local resolveResult = FileSystem:Resolve("/testFolder")
			expect(resolveResult.Success).to.equal(true)
			expect(resolveResult.Value:GetName()).to.equal("testFolder")
		end)

		it("CreatesFoldersAndFiles", function()
			local createFolderResult = Fs:Create("Folder1", "Folder", Context)
			expect(createFolderResult.Success).to.equal(true)

			local createFileResult = Fs:Create("Folder1/File1.txt", "File", Context)
			expect(createFileResult.Success).to.equal(true)

			local resolveResult = Fs:Resolve("Folder1/File1.txt", Context)
			expect(resolveResult.Success).to.equal(true)
			expect(resolveResult.Value).to.be.ok()
			expect(resolveResult.Value:GetName()).to.equal("File1.txt")
		end)

		it("PreventsDuplicateCreationAtSamePath", function()
			Fs:Create("Folder1", "Folder", Context)
			local duplicate = Fs:Create("Folder1", "Folder", Context)
			expect(duplicate.Success).to.equal(false)
		end)

		it("ResolvesAbsoluteAndRelativePathsCorrectly", function()
			Fs:Create("Folder1", "Folder", Context)
			Fs:Create("Folder1/File.txt", "File", Context)

			local absoluteResolve = Fs:Resolve("/Folder1/File.txt", Context)
			expect(absoluteResolve.Success).to.equal(true)
			expect(absoluteResolve.Value:GetName()).to.equal("File.txt")

			local relativeContext = { WorkingDirectory = "/Folder1" }
			local relativeResolve = Fs:Resolve("File.txt", relativeContext)
			expect(relativeResolve.Success).to.equal(true)
			expect(relativeResolve.Value:GetName()).to.equal("File.txt")
		end)

		it("DeletesNodesAndTheirChildren", function()
			Fs:Create("Folder1", "Folder", Context)
			Fs:Create("Folder1/File1.txt", "File", Context)
			Fs:Create("Folder1/Subfolder", "Folder", Context)
			Fs:Create("Folder1/Subfolder/File2.txt", "File", Context)

			local deleteResult = Fs:Delete("Folder1", Context)
			expect(deleteResult.Success).to.equal(true)

			local resolveDeleted = Fs:Resolve("Folder1", Context)
			expect(resolveDeleted.Success).to.equal(false)

			local resolveDeletedChild = Fs:Resolve("Folder1/Subfolder/File2.txt", Context)
			expect(resolveDeletedChild.Success).to.equal(false)
		end)

		it("DoesNotAllowDeletingRootNode", function()
			local deleteRoot = Fs:Delete("/", Context)
			expect(deleteRoot.Success).to.equal(false)
		end)

		-- it("FiresNodeCreatedAndNodeDeletedEvents", function()
		-- 	local createdFired = false
		-- 	local deletedFired = false

		-- 	local createdConnection = Event.GetEventSignal("NodeCreated"):Connect(function(data)
		-- 		createdFired = true
		-- 		expect(data.Handle).to.be.a("string")
		-- 	end)

		-- 	local deletedConnection = Event.GetEventSignal("NodeDeleted"):Connect(function(data)
		-- 		deletedFired = true
		-- 		expect(data.Handle).to.be.a("string")
		-- 	end)

		-- 	Fs:Create("Folder1", "Folder", Context)
		-- 	Fs:Delete("Folder1", Context)

		-- 	createdConnection:Disconnect()
		-- 	deletedConnection:Disconnect()

		-- 	expect(createdFired).to.equal(true)
		-- 	expect(deletedFired).to.equal(true)
		-- end)

		it("ReturnsErrorWhenResolvingNonExistentNode", function()
			local result = Fs:Resolve("Nonexistent/Path", Context)
			expect(result.Success).to.equal(false)
		end)

		it("ReturnsErrorWhenEscapingRootDirectory", function()
			local result = Fs:Create("../../Outside", "Folder", Context)
			expect(result.Success).to.equal(false)
		end)
	end)
end
