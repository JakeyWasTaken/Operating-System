--[[

    LibProcess / process

    Process library

]]

const CFilePath = require("@kernel/File/FilePath")
const IOStream = require("@core/IO/Stream")
const FileContext = require("@kernel/File/FileContext")

type FileContext = FileContext.FileContext
type IOReader = IOStream.IOReader
type IOWriter = IOStream.IOWriter
type CFilePath = CFilePath.CFilePath

return {
	Name = "process",
    Enabled = true,
	MakeLibrary = function(LibraryPID: number, ScriptPath: CFilePath)
        return {
            GetPID = function(): number
                return LibraryPID
            end,

            GetArguments = function(): ({string}?, string)
                if not shared.ProcessFactory then
                    return nil, "ProcessFactory was not ready"
                end

                local Process = shared.ProcessFactory.GetProcess(LibraryPID)
                return Process and Process.Arguments or {}, ""
            end,

            GetEnvironment = function(): ({ [string]: string? }?, string)
                if not shared.ProcessFactory then
                    return nil, "ProcessFactory was not ready"
                end

                local Process = shared.ProcessFactory.GetProcess(LibraryPID)
                return Process and Process.Environment or {}, ""
            end,

            GetPermissions = function(): ({ Elevated: boolean }?, string)
                if not shared.ProcessFactory then
                    return nil, "ProcessFactory was not ready"
                end

                local Process = shared.ProcessFactory.GetProcess(LibraryPID)
                return {
                    Elevated = Process:IsElevated()
                }, ""
            end,

            GetParentPID = function(): (number?, string)
                if not shared.ProcessFactory then
                    return nil, "ProcessFactory was not ready"
                end

                local Process = shared.ProcessFactory.GetProcess(LibraryPID)
                return Process and Process:GetParentPID(), ""
            end,

            GetChildPIDs = function(): ({ number }?, string)
                if not shared.ProcessFactory then
                    return nil, "ProcessFactory was not ready"
                end

                local Process = shared.ProcessFactory.GetProcess(LibraryPID)
                return Process and Process:GetChildPIDs(), ""
            end,

            Spawn = function(
                ProgramPath: string,
                Environment: {[string]: string?},
                Arguments: { string },
                Options: { FileContext: FileContext?, ForwardStdIO: boolean?, Elevated: boolean? }
            ): ({ PID: number, StdIn: IOWriter, StdOut: IOReader, StdErr: IOReader, Status: () -> number }?, string)
                if typeof(ProgramPath) ~= "string" then
                    return nil, "Expected parameter ProgramPath"
                end

                if typeof(Environment) ~= "table" then
                    return nil, "Expected parameter Environment"
                end

                if typeof(Arguments) ~= "table" then
                    return nil, "Expected parameter Arguments"
                end

                if typeof(Options) ~= "table" then
                    return nil, "Expected parameter Options"
                end

                if not shared.ProcessFactory then
                    return nil, "ProcessFactory was not ready"
                end

                local OurProcess = shared.ProcessFactory.GetProcess(LibraryPID)
                if not OurProcess then
                    return nil, `PID {LibraryPID} did not have a process attributed`
                end

                -- Only an already-elevated process may spawn elevated children
                if Options.Elevated and not OurProcess:IsElevated() then
                    return nil, "Cannot spawn an elevated process from a non-elevated process"
                end

                local Path = CFilePath.new(ProgramPath)
                if not Path:IsValid() then
                    return nil, `Program path "{ProgramPath}" was invalid`
                end

                local FirstPart = Path:GetParts()[1]
                if not FirstPart or (FirstPart.Type ~= "Root" and FirstPart.Type ~= "Home") then
                    Path = ScriptPath:Append(ProgramPath)
                end

                local FileContext = Options.FileContext or OurProcess.FileContext
                local SpawningResult = shared.ProcessFactory.CreateProcess(Path, Environment, Arguments, FileContext)
                if not SpawningResult.Success then
                    return nil, SpawningResult.Reason
                end

                local SpawnedProcess = SpawningResult.Value
                shared.ProcessFactory.SetParentProcess(SpawnedProcess:GetPID(), LibraryPID)

                if Options.Elevated then
                    SpawnedProcess:SetElevated(true)
                end

                -- Forward IO
                if Options.ForwardStdIO then
                    task.spawn(function()
                        while true do
                            local Data = SpawnedProcess.StdOut:Read()
                            if not Data then
                                break
                            end

                            OurProcess.StdOut:Write(Data)
                        end
                    end)

                    task.spawn(function()
                        while true do
                            local Data = SpawnedProcess.StdErr:Read()
                            if not Data then
                                break
                            end

                            OurProcess.StdErr:Write(Data)
                        end
                    end)
                end

                -- Hook exit code here, if program exits before we call .Status() we still need to return something
                local ExitCode = nil
                task.spawn(function()
                    ExitCode = SpawnedProcess:GetExitCode()
                end)

                return {
                    PID = SpawnedProcess:GetPID(),
                    StdIn = SpawnedProcess.StdIn:SandboxWriter(),
                    StdOut = SpawnedProcess.StdOut:SandboxReader(),
                    StdErr = SpawnedProcess.StdErr:SandboxReader(),
                    Status = function()
                        -- If the process has already exited
                        if ExitCode then
                            return ExitCode
                        end

                        -- Wait for termination
                        return SpawnedProcess:GetExitCode()
                    end,
                }, ""
            end,

            Terminate = function(PID: number, ExitCode: number): (boolean?, string)
                if not shared.ProcessFactory then
                    return nil, "ProcessFactory was not ready"
                end

                local Process = shared.ProcessFactory.GetProcess(LibraryPID)
                -- Check if we can terminate this
                if PID ~= LibraryPID and not table.find(Process:GetChildPIDs(), PID) then
                    return nil, `PID {PID} is not the caller or one of its children`
                end

                shared.ProcessFactory.TerminateProcess(PID, ExitCode)
                return true, ""
            end,

            Detach = function(PID: number): (boolean?, string)
                if not shared.ProcessFactory then
                    return nil, "ProcessFactory was not ready"
                end

                local Process = shared.ProcessFactory.GetProcess(LibraryPID)
                -- Check if we can detach this
                if PID ~= LibraryPID and not table.find(Process:GetChildPIDs(), PID) then
                    return nil, `PID {PID} is not the caller or one of its children`
                end

                shared.ProcessFactory.DetachProcess(PID)
                return true, ""
            end,
        }
    end,
}
