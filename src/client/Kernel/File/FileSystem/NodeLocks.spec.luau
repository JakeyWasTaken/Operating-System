local NodeLocks = require("@kernel/File/FileSystem/NodeLocks")

return function()
	-- -------------------------------------------------------------------------
	-- LockNode / IsLocked
	-- -------------------------------------------------------------------------
	describe("LockNode", function()
		it("marks a handle as locked for the given PID", function()
			NodeLocks.LockNode("handle-1", 1)

			expect(NodeLocks.IsLocked("handle-1")).to.equal(true)

			NodeLocks.ReleaseProgramLocks(1)
		end)

		it("does not duplicate a lock for the same handle and PID", function()
			NodeLocks.LockNode("handle-2", 2)
			NodeLocks.LockNode("handle-2", 2)

			NodeLocks.UnlockNode("handle-2", 2)
			expect(NodeLocks.IsLocked("handle-2")).to.equal(false)

			NodeLocks.ReleaseProgramLocks(2)
		end)

		it("allows the same handle to be locked by multiple PIDs", function()
			NodeLocks.LockNode("handle-3", 3)
			NodeLocks.LockNode("handle-3", 4)

			expect(NodeLocks.IsLocked("handle-3")).to.equal(true)

			NodeLocks.UnlockNode("handle-3", 3)
			expect(NodeLocks.IsLocked("handle-3")).to.equal(true)

			NodeLocks.UnlockNode("handle-3", 4)
			expect(NodeLocks.IsLocked("handle-3")).to.equal(false)
		end)
	end)

	-- -------------------------------------------------------------------------
	-- IsLocked
	-- -------------------------------------------------------------------------
	describe("IsLocked", function()
		it("returns false for a handle that was never locked", function()
			expect(NodeLocks.IsLocked("handle-never-locked")).to.equal(false)
		end)
	end)

	-- -------------------------------------------------------------------------
	-- UnlockNode
	-- -------------------------------------------------------------------------
	describe("UnlockNode", function()
		it("removes the lock so the handle is no longer locked", function()
			NodeLocks.LockNode("handle-5", 5)
			NodeLocks.UnlockNode("handle-5", 5)

			expect(NodeLocks.IsLocked("handle-5")).to.equal(false)
		end)

		it("is a no-op when the PID has no locks at all", function()
			expect(function()
				NodeLocks.UnlockNode("handle-6", 999999)
			end).never.to.throw()
		end)

		it("is a no-op when the PID has locks but not this handle", function()
			NodeLocks.LockNode("handle-locked", 6)

			NodeLocks.UnlockNode("handle-other", 6)

			expect(NodeLocks.IsLocked("handle-locked")).to.equal(true)

			NodeLocks.ReleaseProgramLocks(6)
		end)

		it("only removes the lock for the specified PID", function()
			NodeLocks.LockNode("handle-7", 7)
			NodeLocks.LockNode("handle-7", 8)

			NodeLocks.UnlockNode("handle-7", 7)

			expect(NodeLocks.IsLocked("handle-7")).to.equal(true)

			NodeLocks.ReleaseProgramLocks(8)
		end)
	end)

	-- -------------------------------------------------------------------------
	-- ReleaseProgramLocks
	-- -------------------------------------------------------------------------
	describe("ReleaseProgramLocks", function()
		it("clears every lock held by the given PID", function()
			NodeLocks.LockNode("handle-a", 9)
			NodeLocks.LockNode("handle-b", 9)

			NodeLocks.ReleaseProgramLocks(9)

			expect(NodeLocks.IsLocked("handle-a")).to.equal(false)
			expect(NodeLocks.IsLocked("handle-b")).to.equal(false)
		end)

		it("does not affect locks held by other PIDs", function()
			NodeLocks.LockNode("handle-10", 10)
			NodeLocks.LockNode("handle-10", 11)

			NodeLocks.ReleaseProgramLocks(10)

			expect(NodeLocks.IsLocked("handle-10")).to.equal(true)

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
			NodeLocks.LockNode("handle-12", 12)
			NodeLocks.LockNode("handle-12", 13)

			NodeLocks.ReleaseNodeLocks("handle-12")

			expect(NodeLocks.IsLocked("handle-12")).to.equal(false)
		end)

		it("leaves a PID's other locked handles untouched", function()
			NodeLocks.LockNode("handle-target", 14)
			NodeLocks.LockNode("handle-other-14", 14)

			NodeLocks.ReleaseNodeLocks("handle-target")

			expect(NodeLocks.IsLocked("handle-target")).to.equal(false)
			expect(NodeLocks.IsLocked("handle-other-14")).to.equal(true)

			NodeLocks.ReleaseProgramLocks(14)
		end)

		it("is a no-op for a handle that was never locked", function()
			expect(function()
				NodeLocks.ReleaseNodeLocks("handle-never-locked-2")
			end).never.to.throw()
		end)
	end)
end
