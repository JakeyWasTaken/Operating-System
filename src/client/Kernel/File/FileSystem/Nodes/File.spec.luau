local CFile = require("@kernel/File/FileSystem/Nodes/File")
local CDirectory = require("@kernel/File/FileSystem/Nodes/Directory")
local NodeLocks = require("@kernel/File/FileSystem/NodeLocks")

return function()
	-- -------------------------------------------------------------------------
	-- new
	-- -------------------------------------------------------------------------
	describe("new", function()
		it("reports as a file, not a directory", function()
			local File = CFile.new()

			expect(File:IsFile()).to.equal(true)
			expect(File:IsDirectory()).to.equal(false)
		end)

		it("starts with empty contents", function()
			local File = CFile.new()

			expect(File:Read()).to.equal("")
			expect(File:GetSize()).to.equal(0)
		end)

		it("starts with UpdatedAt equal to CreatedAt", function()
			local File = CFile.new()
			local Metadata = File:GetMetadata()

			expect(Metadata.UpdatedAt).to.equal(Metadata.CreatedAt)
		end)
	end)

	-- -------------------------------------------------------------------------
	-- Write / Read / GetSize
	-- -------------------------------------------------------------------------
	describe("Write", function()
		it("overwrites the entire contents when no offset is given", function()
			local File = CFile.new()

			File:Write("hello")
			expect(File:Read()).to.equal("hello")

			File:Write("world")
			expect(File:Read()).to.equal("world")
		end)

		it("overwrites a region starting at the given offset", function()
			local File = CFile.new()
			File:Write("hello world")

			File:Write("XYZ", 6)

			expect(File:Read()).to.equal("hello XYZld")
		end)

		it("updates GetSize to match the new contents", function()
			local File = CFile.new()
			File:Write("hello world")

			expect(File:GetSize()).to.equal(11)
		end)

		it("is a no-op while the file is locked", function()
			local File = CFile.new()
			File:Write("hello")

			NodeLocks.LockNode(File:GetHandle(), 201)
			File:Write("changed")
			NodeLocks.ReleaseProgramLocks(201)

			expect(File:Read()).to.equal("hello")
		end)

		it("bumps UpdatedAt on a successful write", function()
			local File = CFile.new()
			local Before = File:GetMetadata().UpdatedAt

			File:Write("hello")

			expect(File:GetMetadata().UpdatedAt >= Before).to.equal(true)
		end)

		it("does not bump UpdatedAt while locked", function()
			local File = CFile.new()
			local Before = File:GetMetadata().UpdatedAt

			NodeLocks.LockNode(File:GetHandle(), 204)
			File:Write("changed")
			NodeLocks.ReleaseProgramLocks(204)

			expect(File:GetMetadata().UpdatedAt).to.equal(Before)
		end)

		it("succeeds again once unlocked", function()
			local File = CFile.new()

			NodeLocks.LockNode(File:GetHandle(), 202)
			File:Write("blocked")
			NodeLocks.UnlockNode(File:GetHandle(), 202)

			File:Write("allowed")

			expect(File:Read()).to.equal("allowed")
		end)
	end)

	-- -------------------------------------------------------------------------
	-- Delete (inherited from CNode, exercised through a file)
	-- -------------------------------------------------------------------------
	describe("Delete", function()
		it("fails while the file is locked", function()
			local Dir = CDirectory.new()
			local File = CFile.new()
			File:SetParent(Dir)

			NodeLocks.LockNode(File:GetHandle(), 203)

			expect(File:Delete()).to.equal(false)
			expect(File:GetParent()).to.equal(Dir)

			NodeLocks.ReleaseProgramLocks(203)
		end)

		it("detaches the file once unlocked", function()
			local Dir = CDirectory.new()
			local File = CFile.new()
			File:SetParent(Dir)

			expect(File:Delete()).to.equal(true)
			expect(File:GetParent()).to.equal(nil)
			expect(table.find(Dir:GetChildren(), File)).to.equal(nil)
		end)
	end)
end
