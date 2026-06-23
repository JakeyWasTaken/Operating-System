--[[

    LibProcess / @process

    Process library

]]

const CPath = require("@kernel/File/Path")
const IOStream = require("@core/IO/Stream")
const FileContext = require("@kernel/File/Context")

type FileContext = FileContext.Context
type IOReader = IOStream.IOReader
type IOWriter = IOStream.IOWriter
type CPath = CPath.CPath

return {
	Name = "process",
    Enabled = true,
	MakeLibrary = function(LibraryPID: number, ScriptPath: CPath)
        return {
            GetPID = function(): number
                return LibraryPID
            end,

            GetArguments = function(): {string}
                assert(shared.ProcessFactory, `ProcessFactory was not ready`)
                local Process = shared.ProcessFactory.GetProcess(LibraryPID)
                return Process and Process.Arguments or {}
            end,

            GetParentPID = function(): number?
                assert(shared.ProcessFactory, `ProcessFactory was not ready`)
                local Process = shared.ProcessFactory.GetProcess(LibraryPID)
                return Process and Process:GetParentPID()
            end,

            GetChildPIDs = function(): { number }
                assert(shared.ProcessFactory, `ProcessFactory was not ready`)
                local Process = shared.ProcessFactory.GetProcess(LibraryPID)
                return Process and Process:GetChildPIDs()
            end,

            Spawn = function(
                ProgramPath: string,
                Arguments: { string },
                Options: { FileContext: FileContext?, ForwardStdIO: boolean? }
            ): {PID: number, StdIn: IOWriter, StdOut: IOReader, StdErr: IOReader, Status: () -> number}

                assert(typeof(ProgramPath) == "string", `Expected parameter ProgramPath`)
                assert(typeof(Arguments) == "table", `Expected parameter Arguments`)
                assert(typeof(Options) == "table", `Expected parameter Options`)

                assert(shared.ProcessFactory, `ProcessFactory was not ready`)
                local OurProcess = shared.ProcessFactory.GetProcess(LibraryPID)
                assert(OurProcess, `PID {LibraryPID} did not have a process attributed`)

                local Path = CPath.new(ProgramPath)
                if not Path:IsValid() then
                    error(`Program path "{ProgramPath}" was invalid`)
                end

                if Path:GetPathType() == "Relative" then
                    Path = ScriptPath:Append(ProgramPath)
                end

                local FileContext = Options.FileContext or OurProcess.FileContext
                local SpawningResult = shared.ProcessFactory.CreateProcess(Path, Arguments, FileContext)
                local SpawnedProcess = SpawningResult.Value
                assert(SpawningResult.Success, SpawningResult.Reason)

                shared.ProcessFactory.SetParentProcess(SpawnedProcess:GetPID(), LibraryPID)

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
                    ExitCode = SpawnedProcess:WaitForTermination()
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
                        return SpawnedProcess:WaitForTermination()
                    end,
                }
            end,

            Terminate = function(PID: number, ExitCode: number)
                assert(shared.ProcessFactory, `ProcessFactory was not ready`)
                local Process = shared.ProcessFactory.GetProcess(LibraryPID)
                -- Check if we can terminate this
                if PID ~= LibraryPID and not table.find(Process:GetChildPIDs(), PID) then
                    error(`PID {PID} is not the caller or one of its children`, 0)
                end

                shared.ProcessFactory.TerminateProcess(PID, ExitCode)
            end,

            Detach = function(PID: number)
                assert(shared.ProcessFactory, `ProcessFactory was not ready`)
                local Process = shared.ProcessFactory.GetProcess(LibraryPID)
                -- Check if we can detach this
                if PID ~= LibraryPID and not table.find(Process:GetChildPIDs(), PID) then
                    error(`PID {PID} is not the caller or one of its children`, 0)
                end

                shared.ProcessFactory.DetachProcess(PID)
            end,
        }
    end,
}
