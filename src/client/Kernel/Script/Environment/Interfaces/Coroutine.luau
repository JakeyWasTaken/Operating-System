const EnvironmentContext = require("../EnvironmentContext")
const ProcessScheduler = require("@kernel/Process/ProcessScheduler")

type userdata = any
type EnvironmentContext = EnvironmentContext.EnvironmentContext

return function(Context: EnvironmentContext)
    const PID = Context.PID

	const function Create(fn: (...any) -> ...any): userdata?
		const ThreadId = ProcessScheduler.CreateThread(PID, fn)
		return ProcessScheduler.GetThreadHandle(ThreadId)
	end

	const function Resume(Handle: userdata, ...: any): (boolean, ...any)
		return ProcessScheduler.ResumeHandle(PID, Handle, ...)
	end

	const function Status(Handle: userdata): string
		return ProcessScheduler.GetHandleStatus(Handle)
	end

	const function Wrap(fn: (...any) -> ...any): (...any) -> ...any
		const Handle = Create(fn)
		return function(...)
			const Results = table.pack(Resume(Handle, ...))
			const Ok = Results[1]
			if not Ok then
				error(Results[2], 0)
			end

			return table.unpack(Results, 2, Results.n)
		end
	end

	const function Close(Handle: userdata): (boolean, string?)
		return ProcessScheduler.CloseHandle(PID, Handle)
	end

	const function Running(): (userdata?, boolean)
		const ThreadId = ProcessScheduler.GetCurrentThreadId()
		if not ThreadId then
			return nil, true
		end

		return ProcessScheduler.GetThreadHandle(ThreadId), ProcessScheduler.IsMainThread(ThreadId)
	end

    return {
        Create = Create,
        Resume = Resume,
        Status = Status,
        Wrap = Wrap,
        Close = Close,
        Running = Running,
    }
end
