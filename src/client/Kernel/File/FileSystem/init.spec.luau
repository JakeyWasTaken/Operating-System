local CFileSystem = require("@kernel/File/FileSystem")
local FileContext = require("@kernel/File/FileContext")
local FilePath = require("@kernel/File/FilePath")

return function()
	local Context = FileContext()

	-- -------------------------------------------------------------------------
	-- new
	-- -------------------------------------------------------------------------
	describe("new", function()
		it("creates a root directory that is resolvable by handle", function()
			local FS = CFileSystem.new()

			expect(FS:ResolveHandle(FS.m_Root:GetHandle())).to.equal(FS.m_Root)
		end)

		it("creates a root that reports IsRoot", function()
			local FS = CFileSystem.new()

			expect(FS.m_Root:IsRoot()).to.equal(true)
		end)

		it("resolves the bare root path to the root directory", function()
			local FS = CFileSystem.new()

			expect(FS:ResolvePath(FilePath.new("/"), Context)).to.equal(FS.m_Root)
		end)
	end)

	-- -------------------------------------------------------------------------
	-- CreateFile
	-- -------------------------------------------------------------------------
	describe("CreateFile", function()
		it("fails for an invalid path", function()
			local FS = CFileSystem.new()
			local Result = FS:CreateFile(FilePath.new(""), Context)

			expect(Result.Success).to.equal(false)
		end)

		it("creates a file at the root and returns it", function()
			local FS = CFileSystem.new()
			local Result = FS:CreateFile(FilePath.new("/leaf.txt"), Context)

			expect(Result.Success).to.equal(true)
			expect(Result.Value:IsFile()).to.equal(true)
			expect(Result.Value:GetName()).to.equal("leaf.txt")
		end)

		it("registers the new file so it can be resolved by handle", function()
			local FS = CFileSystem.new()
			local Result = FS:CreateFile(FilePath.new("/leaf.txt"), Context)

			expect(FS:ResolveHandle(Result.Value:GetHandle())).to.equal(Result.Value)
		end)

		it("fails when the parent directory does not exist", function()
			local FS = CFileSystem.new()
			local Result = FS:CreateFile(FilePath.new("/missing/leaf.txt"), Context)

			expect(Result.Success).to.equal(false)
		end)

		it("fails when a path component above the leaf is a file", function()
			local FS = CFileSystem.new()
			FS:CreateFile(FilePath.new("/note.txt"), Context)

			local Result = FS:CreateFile(FilePath.new("/note.txt/inner.txt"), Context)

			expect(Result.Success).to.equal(false)
		end)

		it("fails when the file already exists", function()
			local FS = CFileSystem.new()
			FS:CreateFile(FilePath.new("/leaf.txt"), Context)

			local Second = FS:CreateFile(FilePath.new("/leaf.txt"), Context)

			expect(Second.Success).to.equal(false)
		end)

		it("creates a file inside a previously created directory", function()
			local FS = CFileSystem.new()
			FS:CreateDirectory(FilePath.new("/docs"), Context)

			local Result = FS:CreateFile(FilePath.new("/docs/readme.md"), Context)

			expect(Result.Success).to.equal(true)
		end)

		it("fires OnNodeCreated with the new file's handle", function()
			local FS = CFileSystem.new()
			local Fired, FiredHandle = false, nil

			local Connection = FS.OnNodeCreated:Connect(function(Handle)
				Fired = true
				FiredHandle = Handle
			end)

			local Result = FS:CreateFile(FilePath.new("/leaf.txt"), Context)
			Connection:Disconnect()

			expect(Fired).to.equal(true)
			expect(FiredHandle).to.equal(Result.Value:GetHandle())
		end)
	end)

	-- -------------------------------------------------------------------------
	-- CreateDirectory
	-- -------------------------------------------------------------------------
	describe("CreateDirectory", function()
		it("fails for an invalid path", function()
			local FS = CFileSystem.new()
			local Result = FS:CreateDirectory(FilePath.new(""), Context)

			expect(Result.Success).to.equal(false)
		end)

		it("creates a directory at the root", function()
			local FS = CFileSystem.new()
			local Result = FS:CreateDirectory(FilePath.new("/docs"), Context)

			expect(Result.Success).to.equal(true)
			expect(Result.Value:IsDirectory()).to.equal(true)
		end)

		it("creates missing intermediate directories", function()
			local FS = CFileSystem.new()
			local Result = FS:CreateDirectory(FilePath.new("/a/b/c"), Context)

			expect(Result.Success).to.equal(true)
			expect(FS:ResolvePath(FilePath.new("/a"), Context)).never.to.equal(nil)
			expect(FS:ResolvePath(FilePath.new("/a/b"), Context)).never.to.equal(nil)
			expect(FS:ResolvePath(FilePath.new("/a/b/c"), Context)).to.equal(Result.Value)
		end)

		it("fails when a path component above the leaf is a file", function()
			local FS = CFileSystem.new()
			FS:CreateFile(FilePath.new("/a"), Context)

			local Result = FS:CreateDirectory(FilePath.new("/a/b"), Context)

			expect(Result.Success).to.equal(false)
		end)

		it("is idempotent for a directory that already exists", function()
			local FS = CFileSystem.new()
			local First = FS:CreateDirectory(FilePath.new("/docs"), Context)
			local Second = FS:CreateDirectory(FilePath.new("/docs"), Context)

			expect(Second.Success).to.equal(true)
			expect(Second.Value).to.equal(First.Value)
		end)

		it("only fires OnNodeCreated for directories that are newly created", function()
			local FS = CFileSystem.new()
			local Count = 0

			local Connection = FS.OnNodeCreated:Connect(function()
				Count += 1
			end)

			FS:CreateDirectory(FilePath.new("/a/b"), Context)
			expect(Count).to.equal(2)

			FS:CreateDirectory(FilePath.new("/a/b/c"), Context)
			Connection:Disconnect()

			expect(Count).to.equal(3)
		end)
	end)

	-- -------------------------------------------------------------------------
	-- ResolvePath
	-- -------------------------------------------------------------------------
	describe("ResolvePath", function()
		it("returns nil for an invalid path", function()
			local FS = CFileSystem.new()

			expect(FS:ResolvePath(FilePath.new(""), Context)).to.equal(nil)
		end)

		it("returns nil when a segment of the path does not exist", function()
			local FS = CFileSystem.new()

			expect(FS:ResolvePath(FilePath.new("/missing"), Context)).to.equal(nil)
		end)

		it("resolves a Home-prefixed path using the given context", function()
			local FS = CFileSystem.new()
			FS:CreateDirectory(FilePath.new(Context.HomeDirectory), Context)
			local Created = FS:CreateFile(FilePath.new(`{Context.HomeDirectory}/diary.txt`), Context)

			local Resolved = FS:ResolvePath(FilePath.new("~/diary.txt"), Context)

			expect(Resolved).to.equal(Created.Value)
		end)

		it("resolves a Relative path using the working directory", function()
			local FS = CFileSystem.new()
			FS:CreateDirectory(FilePath.new("/work"), Context)

			local WorkContext = { WorkingDirectory = "/work", HomeDirectory = Context.HomeDirectory }
			local Created = FS:CreateFile(FilePath.new("./note.txt"), WorkContext)

			local Resolved = FS:ResolvePath(FilePath.new("/work/note.txt"), Context)

			expect(Resolved).to.equal(Created.Value)
		end)

		it("walks back up the tree on an Escape part", function()
			local FS = CFileSystem.new()
			FS:CreateDirectory(FilePath.new("/foo"), Context)

			expect(FS:ResolvePath(FilePath.new("/foo/.."), Context)).to.equal(FS.m_Root)
		end)
	end)

	-- -------------------------------------------------------------------------
	-- ResolveHandle
	-- -------------------------------------------------------------------------
	describe("ResolveHandle", function()
		it("returns nil for an unknown handle", function()
			local FS = CFileSystem.new()

			expect(FS:ResolveHandle("not-a-real-handle")).to.equal(nil)
		end)
	end)

	-- -------------------------------------------------------------------------
	-- DeleteNode
	-- -------------------------------------------------------------------------
	describe("DeleteNode", function()
		it("fails for a handle that does not exist", function()
			local FS = CFileSystem.new()

			expect(FS:DeleteNode("not-a-real-handle")).to.equal(false)
		end)

		it("fails for the root handle", function()
			local FS = CFileSystem.new()

			expect(FS:DeleteNode(FS.m_Root:GetHandle())).to.equal(false)
		end)

		it("deletes a file so it no longer resolves", function()
			local FS = CFileSystem.new()
			local File = FS:CreateFile(FilePath.new("/leaf.txt"), Context).Value

			expect(FS:DeleteNode(File:GetHandle())).to.equal(true)
			expect(FS:ResolveHandle(File:GetHandle())).to.equal(nil)
			expect(FS:ResolvePath(FilePath.new("/leaf.txt"), Context)).to.equal(nil)
		end)

		it("deletes a directory along with all of its descendants", function()
			local FS = CFileSystem.new()
			local Dir = FS:CreateDirectory(FilePath.new("/docs"), Context).Value
			local A = FS:CreateFile(FilePath.new("/docs/a.txt"), Context).Value
			local B = FS:CreateFile(FilePath.new("/docs/b.txt"), Context).Value

			expect(FS:DeleteNode(Dir:GetHandle())).to.equal(true)

			expect(FS:ResolveHandle(Dir:GetHandle())).to.equal(nil)
			expect(FS:ResolveHandle(A:GetHandle())).to.equal(nil)
			expect(FS:ResolveHandle(B:GetHandle())).to.equal(nil)
		end)

		it("fails when the node itself is locked", function()
			local FS = CFileSystem.new()
			local File = FS:CreateFile(FilePath.new("/leaf.txt"), Context).Value

			FS:LockNode(File:GetHandle(), 401)
			local Result = FS:DeleteNode(File:GetHandle())
			FS:ReleaseProgramLocks(401)

			expect(Result).to.equal(false)
			expect(FS:ResolveHandle(File:GetHandle())).to.equal(File)
		end)

		it("fails when a descendant is locked", function()
			local FS = CFileSystem.new()
			local Dir = FS:CreateDirectory(FilePath.new("/docs"), Context).Value
			local Child = FS:CreateFile(FilePath.new("/docs/a.txt"), Context).Value

			FS:LockNode(Child:GetHandle(), 402)
			local Result = FS:DeleteNode(Dir:GetHandle())
			FS:ReleaseProgramLocks(402)

			expect(Result).to.equal(false)
			expect(FS:ResolveHandle(Dir:GetHandle())).to.equal(Dir)
		end)

		it("fires OnNodeDeleted for every removed handle", function()
			local FS = CFileSystem.new()
			local Dir = FS:CreateDirectory(FilePath.new("/docs"), Context).Value
			local Child = FS:CreateFile(FilePath.new("/docs/a.txt"), Context).Value

			local FiredHandles = {}
			local Connection = FS.OnNodeDeleted:Connect(function(Handle)
				table.insert(FiredHandles, Handle)
			end)

			FS:DeleteNode(Dir:GetHandle())
			Connection:Disconnect()

			expect(table.find(FiredHandles, Dir:GetHandle())).never.to.equal(nil)
			expect(table.find(FiredHandles, Child:GetHandle())).never.to.equal(nil)
		end)
	end)

	-- -------------------------------------------------------------------------
	-- LockNode / UnlockNode / ReleaseProgramLocks
	-- -------------------------------------------------------------------------
	describe("Locking", function()
		it("blocks writes to a locked file", function()
			local FS = CFileSystem.new()
			local File = FS:CreateFile(FilePath.new("/leaf.txt"), Context).Value

			FS:LockNode(File:GetHandle(), 501)
			File:Write("hello")
			FS:UnlockNode(File:GetHandle(), 501)

			expect(File:Read()).to.equal("")
		end)

		it("allows writes again after UnlockNode", function()
			local FS = CFileSystem.new()
			local File = FS:CreateFile(FilePath.new("/leaf.txt"), Context).Value

			FS:LockNode(File:GetHandle(), 502)
			FS:UnlockNode(File:GetHandle(), 502)
			File:Write("hello")

			expect(File:Read()).to.equal("hello")
		end)

		it("ReleaseProgramLocks frees every lock held by that PID", function()
			local FS = CFileSystem.new()
			local A = FS:CreateFile(FilePath.new("/a.txt"), Context).Value
			local B = FS:CreateFile(FilePath.new("/b.txt"), Context).Value

			FS:LockNode(A:GetHandle(), 503)
			FS:LockNode(B:GetHandle(), 503)

			FS:ReleaseProgramLocks(503)

			expect(A:IsLocked()).to.equal(false)
			expect(B:IsLocked()).to.equal(false)
		end)
	end)
end
