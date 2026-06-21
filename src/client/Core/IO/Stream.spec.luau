local CIOStream = require("@core/IO/Stream")

-- A TestEZ spec runs as a plain script, not inside a ProcessScheduler
-- kernel thread, so ProcessScheduler.GetCurrentThreadId() is always nil
-- here. CIOStream:Read() falls back to a raw coroutine.yield()/resume() in
-- that case - that's the only path these specs exercise. The
-- ProcessScheduler.Block/Unblock (kernel thread) path is covered separately.

return function()
	describe("SandboxReader / SandboxWriter", function()
		it("returns a reader whose Read delegates to the stream", function()
			local Stream = CIOStream.new()
			Stream:Write("hello")

			local Reader = Stream:SandboxReader()
			expect(Reader:Read()).to.equal("hello")
		end)

		it("returns a writer whose Write delegates to the stream", function()
			local Stream = CIOStream.new()
			local Writer = Stream:SandboxWriter()

			Writer:Write("hello")
			expect(Stream:Read()).to.equal("hello")
		end)

		it("returns a writer whose Close delegates to the stream", function()
			local Stream = CIOStream.new()
			local Writer = Stream:SandboxWriter()

			local Result = "not set"
			local Co = coroutine.create(function()
				Result = Stream:Read()
			end)
			coroutine.resume(Co)

			Writer:Close()
			expect(Result).to.equal(nil)
		end)
	end)

	describe("Write / Read", function()
		it("returns previously written data immediately, without blocking", function()
			local Stream = CIOStream.new()
			Stream:Write("hello")

			expect(Stream:Read()).to.equal("hello")
		end)

		it("concatenates multiple writes into one buffer", function()
			local Stream = CIOStream.new()
			Stream:Write("hello ")
			Stream:Write("world")

			expect(Stream:Read()).to.equal("hello world")
		end)

		it("returns at most ChunkSize bytes, leaving the rest buffered", function()
			local Stream = CIOStream.new()
			Stream:Write("hello world")

			expect(Stream:Read(5)).to.equal("hello")
			expect(Stream:Read()).to.equal(" world")
		end)

		it("defaults to a 1KB chunk size when none is given", function()
			local Stream = CIOStream.new()
			Stream:Write(string.rep("a", 2000))

			expect(#Stream:Read()).to.equal(1024)
			expect(#Stream:Read()).to.equal(976)
		end)
	end)

	describe("Read blocking on an empty stream", function()
		it("yields the calling coroutine until data is written", function()
			local Stream = CIOStream.new()

			local Result = nil
			local Co = coroutine.create(function()
				Result = Stream:Read()
			end)

			coroutine.resume(Co)
			expect(coroutine.status(Co)).to.equal("suspended")
			expect(Result).to.equal(nil)

			Stream:Write("hello")
			expect(coroutine.status(Co)).to.equal("dead")
			expect(Result).to.equal("hello")
		end)

		it("does not block when data is already available", function()
			local Stream = CIOStream.new()
			Stream:Write("hello")

			local Result = nil
			local Co = coroutine.create(function()
				Result = Stream:Read()
			end)

			coroutine.resume(Co)
			expect(coroutine.status(Co)).to.equal("dead")
			expect(Result).to.equal("hello")
		end)
	end)

	describe("Close", function()
		it("wakes a coroutine blocked on Read with nil, signalling the stream is closed", function()
			local Stream = CIOStream.new()

			local Result = "not set"
			local Co = coroutine.create(function()
				Result = Stream:Read()
			end)
			coroutine.resume(Co)

			Stream:Close()
			expect(coroutine.status(Co)).to.equal("dead")
			expect(Result).to.equal(nil)
		end)

		it("destroys the stream, so further calls error", function()
			-- Close() calls self:_Destroy(), which (per Class.luau) clears
			-- the instance's metatable - so there's no Read/Write method
			-- left to resolve afterward, not just an empty/closed buffer.
			local Stream = CIOStream.new()
			Stream:Close()

			expect(function()
				Stream:Read()
			end).to.throw()

			expect(function()
				Stream:Write("")
			end).to.throw()
		end)
	end)
end
