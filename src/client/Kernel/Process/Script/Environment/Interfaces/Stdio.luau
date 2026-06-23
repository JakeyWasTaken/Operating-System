const EnvironmentContext = require("../EnvironmentContext")

type EnvironmentContext = EnvironmentContext.EnvironmentContext

return function(Context: EnvironmentContext)
    const PID = Context.PID
    const Process = shared.ProcessFactory.GetProcess(PID)

    local function StdOut(Callback: (...any) -> ())
        return function(...: any)
            local Data = nil
            for _, Value in { ... } do
                local StrValue = tostring(Value)
                if not StrValue then
                    continue
                end

                Data = Data or ""
                Data ..= tostring(StrValue)
            end

            if Data then
                Process.StdOut:Write(Data)
            end

            Callback(...)
        end
    end

    local function StdErr(Callback: (Message: any, Level: number?) -> ())
        return function(Message: any, Level: number?)
            local Data = tostring(Message)
            if Data then
                Process.StdErr:Write(Data)
            end

            Callback(Message, Level)
        end
    end

    return {
        Print = StdOut(print),
        Warn = StdOut(warn),
        Error = StdErr(error :: any)
    }
end
