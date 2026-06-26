const EnvironmentContext = require("../EnvironmentContext")
const ProcessScheduler = require("@kernel/Process/ProcessScheduler")

type EnvironmentContext = EnvironmentContext.EnvironmentContext

return function(Context: EnvironmentContext)
    const PID = Context.PID

    return {
        Type = function(Value: any): string
            if ProcessScheduler.IsThreadHandle(Value) then
                return "thread"
            end

            return type(Value)
        end,

        TypeOf = function(Value: any): string
            if ProcessScheduler.IsThreadHandle(Value) then
                return "thread"
            end

            return typeof(Value)
        end,

        Exit = function(ExitCode: number?)
            assert(ExitCode and typeof(ExitCode) == "number", `Provided exit code was not a number`)
            shared.ProcessFactory.TerminateProcess(PID, ExitCode)
        end
    }
end
