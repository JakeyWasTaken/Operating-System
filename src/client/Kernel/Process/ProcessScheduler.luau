const Log = require("@core/Log")

-- No builtin type name for runtime userdata. Same trick VendorTypes.luau uses.
type userdata = any

type KernelThread = {
	ThreadId: number,
	PID: number,
	Coroutine: thread,
	-- Suspended: created but never resumed. Tick leaves these alone.
	State: "Waiting" | "Running" | "Sleeping" | "Blocked" | "Suspended" | "Dead",
	IsMain: boolean,
	WakeAt: number?,
	ExitCode: number?,
}

local dbg = false and Log.debug or function() end

-- stylua: ignore
local GetFreeTID: () -> number, ReleaseTID: (number) -> () do
	local FreeTIDs: { number } = {}
	local TIDCounter = 0

	GetFreeTID = function()
		if #FreeTIDs == 0 then
			TIDCounter += 1
			return TIDCounter
		end

		return table.remove(FreeTIDs) :: number
	end

	ReleaseTID = function(TID: number)
		table.insert(FreeTIDs, TID)
	end
end

local Threads: { [number]: KernelThread } = {}

-- Scripts only ever hold this newproxy, never a real thread.
-- Everything they do with it comes back through us to resolve a KernelThread.
-- Weak both ways, so dropped handles and dead threads just disappear.
local HandleToThreadId: { [userdata]: number } = setmetatable({}, { __mode = "k" }) :: any
local ThreadIdToHandle: { [number]: userdata } = setmetatable({}, { __mode = "v" }) :: any

local function GetOrCreateHandle(ThreadId: number): userdata
	local Existing = ThreadIdToHandle[ThreadId]
	if Existing then
		return Existing
	end

	local NewHandle = newproxy(true)
	local Meta = getmetatable(NewHandle :: any)
	Meta.__tostring = function()
		return `thread: 0x{string.format("%08x", ThreadId)}`
	end
	Meta.__metatable = "The metatable is locked"

	HandleToThreadId[NewHandle] = ThreadId
	ThreadIdToHandle[ThreadId] = NewHandle

	return NewHandle
end

local function ResolveHandle(Handle: unknown): number?
	if typeof(Handle) ~= "userdata" then
		return nil
	end

	return HandleToThreadId[Handle :: any]
end

-- Stops A jumping to B jumping back to A forever and hanging Tick.
local MAX_JUMP_CHAIN = 1024

-- JumpExecution stashes the next thread to run here.
-- Tick picks it up right away instead of waiting for its normal turn.
local PendingJump: number? = nil

-- Only the main thread's fn returns a Result<T> (CScript:Run()).
-- A plain task.spawn/coroutine.create thread can return anything, or
-- nothing. Don't assume it's shaped like a Result.
local function ComputeExitCode(Ok: boolean, ReturnValue: unknown): number
	if not Ok then
		return -1
	elseif typeof(ReturnValue) == "table" and (ReturnValue :: any).Success ~= nil then
		local Result = ReturnValue :: { Success: boolean, Value: unknown? }
		return (Result.Success and (Result.Value :: number?) or -1) :: number
	elseif typeof(ReturnValue) == "number" then
		return ReturnValue :: number
	end

	return 0
end

local function ResumeThread(Thread: KernelThread, ...: any): (boolean, ...any)
	Thread.State = "Running"
	local Results = table.pack(coroutine.resume(Thread.Coroutine, ...))
	local Ok = Results[1] :: boolean

	if coroutine.status(Thread.Coroutine) == "dead" then
		Thread.State = "Dead"
		Thread.ExitCode = ComputeExitCode(Ok, Results[2])
	elseif Thread.State == "Running" then
		-- It yielded, but nothing set a more specific state first.
		-- A bare coroutine.yield(), for example. Fall back to Waiting
		-- so it isn't stuck on Running forever.
		Thread.State = "Waiting"
	end

	return table.unpack(Results, 1, Results.n)
end

local ProcessScheduler = {}

function ProcessScheduler.IsThreadHandle(Value: unknown): boolean
	return ResolveHandle(Value) ~= nil
end

function ProcessScheduler.Tick()
	for ThreadId, Thread in Threads do
		if Thread.State == "Dead" then
			if coroutine.status(Thread.Coroutine) ~= "dead" then
				coroutine.close(Thread.Coroutine)
			end

			Threads[ThreadId] = nil
			ReleaseTID(ThreadId)
            dbg(`Terminated thread PID: {Thread.PID} TID: {Thread.ThreadId} IsMain: {tostring(Thread.IsMain)}`)

			if Thread.IsMain then
				shared.ProcessFactory.TerminateProcess(Thread.PID, Thread.ExitCode or 0)
			end

			continue
		end

		if Thread.State == "Sleeping" then
			if os.clock() < Thread.WakeAt then
				continue
			end

			Thread.State = "Waiting"
			Thread.WakeAt = nil
		end

		if Thread.State ~= "Waiting" then
			continue -- Running (shouldn't persist across ticks) / Blocked
		end

		ResumeThread(Thread)

		-- It might've jumped to another thread, which jumped to another.
		-- Chase the whole chain now so it's done within this tick.
		local JumpHops = 0
		while PendingJump do
			JumpHops += 1
			if JumpHops > MAX_JUMP_CHAIN then
				Log.warn(`JumpExecution chain exceeded {MAX_JUMP_CHAIN} hops, breaking to avoid a hang`)
				PendingJump = nil
				break
			end

			local JumpThreadId = PendingJump
			PendingJump = nil

			local JumpTarget = Threads[JumpThreadId]
			if JumpTarget and JumpTarget.State == "Waiting" then
				ResumeThread(JumpTarget)
			end
		end
	end
end

function ProcessScheduler.Sleep(ThreadId: number, Seconds: number)
	local Thread = Threads[ThreadId]
	if not Thread then
		return
	end

	Thread.State = "Sleeping"
	Thread.WakeAt = os.clock() + Seconds
	coroutine.yield()
end

function ProcessScheduler.Block(ThreadId: number)
	local Thread = Threads[ThreadId]
	if not Thread then
		return
	end

	Thread.State = "Blocked"
	coroutine.yield()
end

function ProcessScheduler.Unblock(ThreadId: number)
	local Thread = Threads[ThreadId]
	if not Thread or Thread.State ~= "Blocked" then
		return
	end

	Thread.State = "Waiting"
	coroutine.resume(Thread.Coroutine)
end

local function RegisterThread(PID: number, Coroutine: thread, IsMain: boolean, InitialState: "Waiting" | "Suspended"): KernelThread
	local Thread: KernelThread = {
		ThreadId = GetFreeTID(),
		PID = PID,
		Coroutine = Coroutine,
		State = InitialState,
		IsMain = IsMain,
		WakeAt = nil,
		ExitCode = nil,
	}

	Threads[Thread.ThreadId] = Thread

	return Thread
end

function ProcessScheduler.SpawnThread<A>(PID: number, IsMain: boolean, fn: (...A) -> ...any, ...: A): number
	local Args = { ... }
	local Thread = RegisterThread(PID, coroutine.create(function()
		return fn(table.unpack(Args))
	end), IsMain, "Waiting")

    dbg(`Spawned thread PID: {PID} TID: {Thread.ThreadId} IsMain: {tostring(IsMain)}`)

    return Thread.ThreadId
end

--- coroutine.create() takes no args, those come later via resume.
--- Unlike SpawnThread, this thread doesn't run until something resumes it.
function ProcessScheduler.CreateThread(PID: number, fn: (...any) -> ...any): number
	local Thread = RegisterThread(PID, coroutine.create(fn), false, "Suspended")

    dbg(`Created suspended thread PID: {PID} TID: {Thread.ThreadId}`)

	return Thread.ThreadId
end

--- Nil if the thread is already gone, e.g. finished and cleaned up by Tick.
function ProcessScheduler.GetThreadHandle(ThreadId: number): userdata?
	if not Threads[ThreadId] then
		return nil
	end

	return GetOrCreateHandle(ThreadId)
end

function ProcessScheduler.GetAllThreads()
	return Threads
end

function ProcessScheduler.IsMainThread(ThreadId: number): boolean
	local Thread = Threads[ThreadId]
	return Thread ~= nil and Thread.IsMain
end

--- Backs task.spawn(fn | thread).
--- A function gets wrapped in a new thread. A handle gets forced back to
--- Waiting, cancelling any pending Sleep, same as real task.spawn.
--- Either way it runs immediately and we hand back its handle.
function ProcessScheduler.TaskSpawn(PID: number, Target: unknown, ...: any): userdata
	local ThreadId: number

	if typeof(Target) == "function" then
		ThreadId = ProcessScheduler.SpawnThread(PID, false, Target :: any, ...)
	else
		local ResolvedThreadId = ResolveHandle(Target)
		assert(ResolvedThreadId, "task.spawn expects a function or a thread handle")

		local Thread = Threads[ResolvedThreadId]
		assert(Thread, "Thread handle refers to a thread that no longer exists")
		assert(Thread.PID == PID, "Cannot spawn a thread belonging to another process")
		assert(Thread.State ~= "Dead", "Cannot spawn a dead thread")

		Thread.State = "Waiting"
		Thread.WakeAt = nil
		ThreadId = ResolvedThreadId
	end

	ProcessScheduler.JumpExecution(ThreadId)
	return GetOrCreateHandle(ThreadId)
end

--- Backs coroutine.resume(handle, ...).
--- Resumes the target right now, nested on the caller's own stack.
--- Hands back whatever it returned or yielded, same as real resume.
function ProcessScheduler.ResumeHandle(PID: number, Handle: userdata, ...: any): (boolean, ...any)
	local ThreadId = ResolveHandle(Handle)
	local Thread = ThreadId and Threads[ThreadId]
	if not Thread then
		return false, "cannot resume a non-thread value"
	end

	if Thread.PID ~= PID then
		return false, "cannot resume a thread belonging to another process"
	end

	if Thread.State ~= "Waiting" and Thread.State ~= "Suspended" then
		return false, `cannot resume non-suspended coroutine`
	end

	return ResumeThread(Thread, ...)
end

--- Backs coroutine.status(handle).
--- Reports our own State, not native coroutine.status.
--- Our State is what actually explains why a thread can or can't run.
function ProcessScheduler.GetHandleStatus(Handle: userdata): "running" | "normal" | "suspended" | "dead"
	local ThreadId = ResolveHandle(Handle)
	local Thread = ThreadId and Threads[ThreadId]
	if not Thread or Thread.State == "Dead" then
		return "dead"
	end

	if Thread.State == "Running" then
		return if ThreadId == ProcessScheduler.GetCurrentThreadId() then "running" else "normal"
	end

	return "suspended"
end

--- Backs coroutine.close(handle).
--- Leaves the real coroutine.close to Tick, same as TerminateThread,
--- so we never close a coroutine that's currently running.
function ProcessScheduler.CloseHandle(PID: number, Handle: userdata): (boolean, string?)
	local ThreadId = ResolveHandle(Handle)
	local Thread = ThreadId and Threads[ThreadId]
	if not Thread then
		return false, "cannot close a non-thread value"
	end

	if Thread.PID ~= PID then
		return false, "cannot close a thread belonging to another process"
	end

	if Thread.State == "Running" then
		return false, "cannot close a running coroutine"
	end

	ProcessScheduler.TerminateThread(ThreadId :: number)
	return true
end

--- Backs task.cancel(handle).
--- Can target the calling thread itself. TerminateThread only marks it
--- Dead and leaves the real close for later, so self-cancel is safe.
function ProcessScheduler.CancelHandle(PID: number, Handle: userdata)
	local ThreadId = ResolveHandle(Handle)
	local Thread = ThreadId and Threads[ThreadId]
	if not Thread or Thread.PID ~= PID then
		return
	end

	ProcessScheduler.TerminateThread(ThreadId :: number)
end

--- Ends the caller's turn early and tells Tick to run ThreadId next.
--- The caller goes back to Waiting and gets another turn later.
--- It is not nested underneath the target.
function ProcessScheduler.JumpExecution(ThreadId: number)
	local Target = Threads[ThreadId]
	if not Target or Target.State ~= "Waiting" then
		return
	end

	local CurrentThreadId = ProcessScheduler.GetCurrentThreadId()
	local CurrentThread = CurrentThreadId and Threads[CurrentThreadId]
	if not CurrentThread then
		return
	end

	CurrentThread.State = "Waiting"
	PendingJump = ThreadId
	coroutine.yield()
end

function ProcessScheduler.GetCurrentThreadId(): number?
	local Running = coroutine.running()
	for _, Thread in Threads do
		if Thread.Coroutine == Running then
			return Thread.ThreadId
		end
	end

	return nil
end

function ProcessScheduler.TerminateThread(ThreadId: number)
	local Thread = Threads[ThreadId]
	if not Thread then
		return
	end

	Thread.State = "Dead"
end

function ProcessScheduler.ProcessTerminated(PID: number)
	for ThreadId, Thread in Threads do
		if Thread.PID ~= PID then
			continue
		end

		ProcessScheduler.TerminateThread(ThreadId)
	end
end

return ProcessScheduler
