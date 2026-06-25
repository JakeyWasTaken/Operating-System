local CDirectory = require("@kernel/File/FileSystem/Nodes/Directory")
local CFile = require("@kernel/File/FileSystem/Nodes/File")
local NodeLocks = require("@kernel/File/FileSystem/NodeLocks")

return function()
	-- -------------------------------------------------------------------------
	-- new
	-- -------------------------------------------------------------------------
	describe("new", function()
		it("reports as a directory, not a file", function()
			local Dir = CDirectory.new()

			expect(Dir:IsDirectory()).to.equal(true)
			expect(Dir:IsFile()).to.equal(false)
		end)

		it("starts with no children", function()
			expect(#CDirectory.new():GetChildren()).to.equal(0)
		end)
	end)

	-- -------------------------------------------------------------------------
	-- GetChildren
	-- -------------------------------------------------------------------------
	describe("GetChildren", function()
		it("reflects nodes attached via SetParent", function()
			local Dir = CDirectory.new()
			local File = CFile.new()

			File:SetParent(Dir)

			expect(table.find(Dir:GetChildren(), File)).never.to.equal(nil)
		end)

		it("no longer includes a node once it is reparented elsewhere", function()
			local DirA, DirB = CDirectory.new(), CDirectory.new()
			local File = CFile.new()

			File:SetParent(DirA)
			File:SetParent(DirB)

			expect(table.find(DirA:GetChildren(), File)).to.equal(nil)
		end)
	end)

	-- -------------------------------------------------------------------------
	-- Delete
	-- -------------------------------------------------------------------------
	describe("Delete", function()
		it("detaches an empty, unlocked directory", function()
			local Parent = CDirectory.new()
			local Child = CDirectory.new()
			Child:SetParent(Parent)

			expect(Child:Delete()).to.equal(true)
			expect(Child:GetParent()).to.equal(nil)
			expect(table.find(Parent:GetChildren(), Child)).to.equal(nil)
		end)

		it("fails when the directory itself is locked", function()
			local Parent = CDirectory.new()
			local Child = CDirectory.new()
			Child:SetParent(Parent)

			NodeLocks.LockNode(Child:GetHandle(), 301)

			expect(Child:Delete()).to.equal(false)
			expect(Child:GetParent()).to.equal(Parent)

			NodeLocks.ReleaseProgramLocks(301)
		end)

		it("fails when a direct child is locked", function()
			local Dir = CDirectory.new()
			local File = CFile.new()
			File:SetParent(Dir)

			NodeLocks.LockNode(File:GetHandle(), 302)

			expect(Dir:Delete()).to.equal(false)

			NodeLocks.ReleaseProgramLocks(302)
		end)

		it("fails when a nested descendant is locked", function()
			local Root = CDirectory.new()
			local Sub = CDirectory.new()
			local File = CFile.new()

			Sub:SetParent(Root)
			File:SetParent(Sub)

			NodeLocks.LockNode(File:GetHandle(), 303)

			expect(Root:Delete()).to.equal(false)

			NodeLocks.ReleaseProgramLocks(303)
		end)

		it("detaches the whole subtree once nothing in it is locked", function()
			local Parent = CDirectory.new()
			local Dir = CDirectory.new()
			local File = CFile.new()

			Dir:SetParent(Parent)
			File:SetParent(Dir)

			expect(Dir:Delete()).to.equal(true)
			expect(table.find(Parent:GetChildren(), Dir)).to.equal(nil)
			expect(File:GetParent()).to.equal(Dir) -- subtree stays internally intact, just detached as a whole
		end)

		it("fails on the root directory", function()
			local Root = CDirectory.new()
			;(Root :: any).m_IsRoot = true

			expect(Root:Delete()).to.equal(false)
		end)
	end)
end
