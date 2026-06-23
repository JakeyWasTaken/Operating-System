const EnvironmentContext = require("../EnvironmentContext")
const ProcessScheduler = require("@kernel/Process/ProcessScheduler")

type userdata = any
type EnvironmentContext = EnvironmentContext.EnvironmentContext

return function(Context: EnvironmentContext)
    const PID = Context.PID

    const function Wait(Time: number?)
		const ThreadId = ProcessScheduler.GetCurrentThreadId()
		assert(ThreadId, `Cannot wait under non-process thread`)
		ProcessScheduler.Sleep(ThreadId, Time or 0) -- Sleep yields internally, so the thread actually suspends here
	end

	-- Target can be a function or a handle, genuinely either, so it stays unknown.
	const function Spawn(Target: unknown, ...: any): userdata?
		return ProcessScheduler.TaskSpawn(PID, Target, ...)
	end

	const function Defer(fn: (...any) -> ...any, ...: any): userdata?
		-- Leaves it Waiting without a JumpExecution, so it runs next Tick
		-- instead of right now. Matches real task.defer.
		const ThreadId = ProcessScheduler.SpawnThreadDeferred(PID, false, fn, ...)
		return ProcessScheduler.GetThreadHandle(ThreadId)
	end

	const function Delay(Seconds: number, fn: (...any) -> ...any, ...: any): userdata?
		return Spawn(function(...)
			Wait(Seconds)
			fn(...)
		end, ...)
	end

	const function Cancel(Handle: userdata)
		ProcessScheduler.CancelHandle(PID, Handle)
	end

    return {
        Wait = Wait,
        Spawn = Spawn,
        Defer = Defer,
        Delay = Delay,
        Cancel = Cancel
    }

end
