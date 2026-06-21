const CPath = require("@kernel/File/Path")
const IOStream = require("@core/IO/Stream")

type IOReader = IOStream.IOReader
type IOWriter = IOStream.IOWriter
type CPath = CPath.CPath

return {
	Name = "process",
    Enabled = true,
	MakeLibrary = function(LibraryPID: number, ScriptPath: CPath)
        return {
            GetCurrentPID = function(): number
                return LibraryPID
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

            Create = function(ProgramPath: string): {PID: number, StdIn: IOWriter, StdOut: IOReader, StdErr: IOReader, Status: () -> number}

            end,

            Execute = function(ProgramPath: string): {PID: number, Ok: boolean, ExitCode: number, StdOut: string, StdErr: string}

            end,

            Terminate = function(PID: number, ExitCode: number): boolean
                assert(shared.ProcessFactory, `ProcessFactory was not ready`)
                local Process = shared.ProcessFactory.GetProcess(LibraryPID)
                -- Check if we can detach this
                if PID == LibraryPID or table.find(Process:GetChildPIDs(), PID) then
                    shared.ProcessFactory.TerminateProcess(PID, ExitCode)
                    return true
                end

                return false
            end,

            Detach = function(PID: number): boolean
                assert(shared.ProcessFactory, `ProcessFactory was not ready`)
                local Process = shared.ProcessFactory.GetProcess(LibraryPID)
                -- Check if we can detach this
                if PID == LibraryPID or table.find(Process:GetChildPIDs(), PID) then
                    return shared.ProcessFactory.DetachProcess(PID)
                end

                return false
            end,
        }
    end,
}
