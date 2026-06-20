local NodeLocks = require("@kernel/File/NodeLocks")
local Handle = require("@core/Handle")

return function()
	-- -------------------------------------------------------------------------
	-- LockFile / IsLocked
	-- -------------------------------------------------------------------------
	describe("LockFile", function()
		it("marks a node as locked for the given PID", function()
			local NodeHandle = Handle()
			NodeLocks.LockFile(NodeHandle, 1)

			expect(NodeLocks.IsLocked(NodeHandle)).to.equal(true)

			NodeLocks.ReleaseProgramLocks(1)
		end)

		it("does not duplicate a lock for the same handle and PID", function()
			local NodeHandle = Handle()
			NodeLocks.LockFile(NodeHandle, 2)
			NodeLocks.LockFile(NodeHandle, 2)

			NodeLocks.UnlockFile(NodeHandle, 2)
			-- A single Unlock should be enough to fully clear it if no duplicate was added
			expect(NodeLocks.IsLocked(NodeHandle)).to.equal(false)

			NodeLocks.ReleaseProgramLocks(2)
		end)

		it("allows the same node to be locked by multiple PIDs", function()
			local NodeHandle = Handle()
			NodeLocks.LockFile(NodeHandle, 3)
			NodeLocks.LockFile(NodeHandle, 4)

			expect(NodeLocks.IsLocked(NodeHandle)).to.equal(true)

			NodeLocks.UnlockFile(NodeHandle, 3)
			expect(NodeLocks.IsLocked(NodeHandle)).to.equal(true)

			NodeLocks.UnlockFile(NodeHandle, 4)
			expect(NodeLocks.IsLocked(NodeHandle)).to.equal(false)
		end)
	end)

	-- -------------------------------------------------------------------------
	-- IsLocked
	-- -------------------------------------------------------------------------
	describe("IsLocked", function()
		it("returns false for a handle that was never locked", function()
			expect(NodeLocks.IsLocked(Handle())).to.equal(false)
		end)
	end)

	-- -------------------------------------------------------------------------
	-- UnlockFile
	-- -------------------------------------------------------------------------
	describe("UnlockFile", function()
		it("removes the lock so the handle is no longer locked", function()
			local NodeHandle = Handle()
			NodeLocks.LockFile(NodeHandle, 5)
			NodeLocks.UnlockFile(NodeHandle, 5)

			expect(NodeLocks.IsLocked(NodeHandle)).to.equal(false)
		end)

		it("is a no-op when the PID has no locks at all", function()
			local NodeHandle = Handle()
			expect(function()
				NodeLocks.UnlockFile(NodeHandle, 999999)
			end).never.to.throw()
		end)

		it("is a no-op when the PID has locks but not this handle", function()
			local LockedHandle = Handle()
			local OtherHandle = Handle()
			NodeLocks.LockFile(LockedHandle, 6)

			NodeLocks.UnlockFile(OtherHandle, 6)

			expect(NodeLocks.IsLocked(LockedHandle)).to.equal(true)

			NodeLocks.ReleaseProgramLocks(6)
		end)

		it("only removes the lock for the specified PID", function()
			local NodeHandle = Handle()
			NodeLocks.LockFile(NodeHandle, 7)
			NodeLocks.LockFile(NodeHandle, 8)

			NodeLocks.UnlockFile(NodeHandle, 7)

			expect(NodeLocks.IsLocked(NodeHandle)).to.equal(true)

			NodeLocks.ReleaseProgramLocks(8)
		end)
	end)

	-- -------------------------------------------------------------------------
	-- ReleaseProgramLocks
	-- -------------------------------------------------------------------------
	describe("ReleaseProgramLocks", function()
		it("clears every lock held by the given PID", function()
			local HandleA, HandleB = Handle(), Handle()
			NodeLocks.LockFile(HandleA, 9)
			NodeLocks.LockFile(HandleB, 9)

			NodeLocks.ReleaseProgramLocks(9)

			expect(NodeLocks.IsLocked(HandleA)).to.equal(false)
			expect(NodeLocks.IsLocked(HandleB)).to.equal(false)
		end)

		it("does not affect locks held by other PIDs", function()
			local NodeHandle = Handle()
			NodeLocks.LockFile(NodeHandle, 10)
			NodeLocks.LockFile(NodeHandle, 11)

			NodeLocks.ReleaseProgramLocks(10)

			expect(NodeLocks.IsLocked(NodeHandle)).to.equal(true)

			NodeLocks.ReleaseProgramLocks(11)
		end)

		it("is a no-op for a PID with no locks", function()
			expect(function()
				NodeLocks.ReleaseProgramLocks(999998)
			end).never.to.throw()
		end)
	end)

	-- -------------------------------------------------------------------------
	-- ReleaseNodeLocks
	-- -------------------------------------------------------------------------
	describe("ReleaseNodeLocks", function()
		it("removes the given handle's lock across all PIDs", function()
			local NodeHandle = Handle()
			NodeLocks.LockFile(NodeHandle, 12)
			NodeLocks.LockFile(NodeHandle, 13)

			NodeLocks.ReleaseNodeLocks(NodeHandle)

			expect(NodeLocks.IsLocked(NodeHandle)).to.equal(false)
		end)

		it("leaves a PID's other locked handles untouched", function()
			local TargetHandle, OtherHandle = Handle(), Handle()
			NodeLocks.LockFile(TargetHandle, 14)
			NodeLocks.LockFile(OtherHandle, 14)

			NodeLocks.ReleaseNodeLocks(TargetHandle)

			expect(NodeLocks.IsLocked(TargetHandle)).to.equal(false)
			expect(NodeLocks.IsLocked(OtherHandle)).to.equal(true)

			NodeLocks.ReleaseProgramLocks(14)
		end)

		it("is a no-op for a handle that was never locked", function()
			expect(function()
				NodeLocks.ReleaseNodeLocks(Handle())
			end).never.to.throw()
		end)
	end)
end
