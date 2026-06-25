local CNode = require("@kernel/File/FileSystem/Nodes/Node")
local CDirectory = require("@kernel/File/FileSystem/Nodes/Directory")
local NodeLocks = require("@kernel/File/FileSystem/NodeLocks")

return function()
	-- -------------------------------------------------------------------------
	-- new
	-- -------------------------------------------------------------------------
	describe("new", function()
		it("generates a unique, non-empty handle", function()
			local A, B = CNode.new(), CNode.new()

			expect(#A:GetHandle() > 0).to.equal(true)
			expect(A:GetHandle()).never.to.equal(B:GetHandle())
		end)

		it("defaults Name to an empty string", function()
			expect(CNode.new():GetName()).to.equal("")
		end)

		it("defaults Parent to nil", function()
			expect(CNode.new():GetParent()).to.equal(nil)
		end)

		it("defaults IsDirectory, IsFile, and IsRoot to false", function()
			local Node = CNode.new()

			expect(Node:IsDirectory()).to.equal(false)
			expect(Node:IsFile()).to.equal(false)
			expect(Node:IsRoot()).to.equal(false)
		end)

		it("defaults IsLocked to false", function()
			expect(CNode.new():IsLocked()).to.equal(false)
		end)

		it("records a CreatedAt timestamp in its metadata", function()
			local Before = os.clock()
			local Node = CNode.new()

			expect(Node:GetMetadata().CreatedAt >= Before).to.equal(true)
			expect(Node:GetMetadata().CreatedAt <= os.clock()).to.equal(true)
		end)

		it("does not report an UpdatedAt in its metadata", function()
			expect(CNode.new():GetMetadata().UpdatedAt).to.equal(nil)
		end)
	end)

	-- -------------------------------------------------------------------------
	-- SetName / GetName
	-- -------------------------------------------------------------------------
	describe("SetName", function()
		it("updates the name returned by GetName", function()
			local Node = CNode.new()
			Node:SetName("readme.txt")

			expect(Node:GetName()).to.equal("readme.txt")
		end)
	end)

	-- -------------------------------------------------------------------------
	-- GetPath
	-- -------------------------------------------------------------------------
	describe("GetPath", function()
		it("returns the filesystem root when there is no parent", function()
			expect(CNode.new():GetPath():GetString()).to.equal("/")
		end)

		it("builds an absolute path by walking up the parent chain", function()
			local Dir = CDirectory.new()
			Dir:SetName("docs")

			local Node = CNode.new()
			Node:SetName("readme.txt")
			Node:SetParent(Dir)

			expect(Node:GetPath():GetString()).to.equal("/docs/readme.txt")
		end)
	end)

	-- -------------------------------------------------------------------------
	-- SetParent / GetParent
	-- -------------------------------------------------------------------------
	describe("SetParent", function()
		it("makes GetParent return the new parent", function()
			local Dir = CDirectory.new()
			local Node = CNode.new()

			Node:SetParent(Dir)

			expect(Node:GetParent()).to.equal(Dir)
		end)

		it("adds the node to the new parent's children", function()
			local Dir = CDirectory.new()
			local Node = CNode.new()

			Node:SetParent(Dir)

			expect(table.find(Dir:GetChildren(), Node)).never.to.equal(nil)
		end)

		it("removes the node from its previous parent's children", function()
			local OldDir, NewDir = CDirectory.new(), CDirectory.new()
			local Node = CNode.new()

			Node:SetParent(OldDir)
			Node:SetParent(NewDir)

			expect(table.find(OldDir:GetChildren(), Node)).to.equal(nil)
			expect(table.find(NewDir:GetChildren(), Node)).never.to.equal(nil)
		end)

		it("detaches the node when set to nil", function()
			local Dir = CDirectory.new()
			local Node = CNode.new()

			Node:SetParent(Dir)
			Node:SetParent(nil)

			expect(Node:GetParent()).to.equal(nil)
			expect(table.find(Dir:GetChildren(), Node)).to.equal(nil)
		end)

		it("is a no-op on the root node", function()
			local Root = CDirectory.new()
			;(Root :: any).m_IsRoot = true

			local Dir = CDirectory.new()
			Root:SetParent(Dir)

			expect(Root:GetParent()).to.equal(nil)
			expect(table.find(Dir:GetChildren(), Root)).to.equal(nil)
		end)
	end)

	-- -------------------------------------------------------------------------
	-- IsLocked
	-- -------------------------------------------------------------------------
	describe("IsLocked", function()
		it("reflects locks taken out on the node's handle", function()
			local Node = CNode.new()

			NodeLocks.LockNode(Node:GetHandle(), 101)
			expect(Node:IsLocked()).to.equal(true)

			NodeLocks.ReleaseProgramLocks(101)
			expect(Node:IsLocked()).to.equal(false)
		end)
	end)

	-- -------------------------------------------------------------------------
	-- Delete
	-- -------------------------------------------------------------------------
	describe("Delete", function()
		it("detaches an unlocked, non-root node and returns true", function()
			local Dir = CDirectory.new()
			local Node = CNode.new()
			Node:SetParent(Dir)

			expect(Node:Delete()).to.equal(true)
			expect(Node:GetParent()).to.equal(nil)
			expect(table.find(Dir:GetChildren(), Node)).to.equal(nil)
		end)

		it("is idempotent when called again on an already-detached node", function()
			local Node = CNode.new()

			expect(Node:Delete()).to.equal(true)
			expect(Node:Delete()).to.equal(true)
		end)

		it("fails and does nothing while the node is locked", function()
			local Dir = CDirectory.new()
			local Node = CNode.new()
			Node:SetParent(Dir)

			NodeLocks.LockNode(Node:GetHandle(), 104)

			expect(Node:Delete()).to.equal(false)
			expect(Node:GetParent()).to.equal(Dir)

			NodeLocks.ReleaseProgramLocks(104)
		end)

		it("fails on the root node", function()
			local Root = CNode.new()
			;(Root :: any).m_IsRoot = true

			expect(Root:Delete()).to.equal(false)
		end)
	end)
end
