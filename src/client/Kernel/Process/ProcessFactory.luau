--!strict

const CPath = require("@kernel/File/Path")
const CProcess = require("@kernel/Process/Process")
const Context = require("@kernel/File/Context")
const FileSystem = require("@kernel/File/FileSystem")
const Result = require("@core/Result")
const ScriptFactory = require("@kernel/Process/Script/ScriptFactory")
const Log = require("@core/Log")
const ProcessScheduler = require("@kernel/Process/ProcessScheduler")

type Result<T> = Result.Result<T>
type Context = Context.Context
type CPath = CPath.CPath
type CProcess = CProcess.CProcess

-- stylua: ignore
local GetFreePID: () -> number, ReleasePID: (number) -> () do
	local FreePIDs: { number } = {}
	local PIDCounter = 0

	GetFreePID = function()
		if #FreePIDs == 0 then
			PIDCounter += 1
			return PIDCounter
		end

		return table.remove(FreePIDs) :: number
	end

	ReleasePID = function(PID: number)
		table.insert(FreePIDs, PID)
	end
end

local AllProcesses: { [number]: CProcess } = {}

local ProcessFactory = {}
shared.ProcessFactory = ProcessFactory

function ProcessFactory.CreateProcess(ProgramPath: CPath, ProgramContext: Context): Result<CProcess>
	-- Fetch file and validate it & params
	local FileResult = FileSystem:Resolve(ProgramPath, ProgramContext)
	if not FileResult.Success then
		return FileResult :: Result<CProcess>
	end

	local FileHandle = FileResult.Value :: string

	if FileSystem:GetType(FileHandle).Value ~= "File" then
		return Result.new(false, "Program was not a file") :: Result<CProcess>
	end

	local FileContentsResult = FileSystem:Read(FileHandle)
	if not FileContentsResult.Success then
		return FileContentsResult :: Result<CProcess>
	end

	if not CPath.ValidateContext(ProgramContext) then
		return Result.new(false, `Program context was in-valid`) :: Result<CProcess>
	end

	-- Create process & run script

	local PID = GetFreePID()
	local Label = FileSystem:GetName(FileHandle).Value or "Unknown"
	local Process = CProcess.new(PID, Label, ProgramContext, function(ExitCode: number)
		ProcessFactory.TerminateProcess(PID, ExitCode)
	end)
	AllProcesses[PID] = Process

	Log.debug(`Created new process PID: {PID} Label: "{Label}"`)

	-- We pass in the program path parent here as opposed to working directory since they are different
	local Script = ScriptFactory.CreateScript(FileContentsResult.Value :: string, ProgramPath:GetParent(), FileHandle, PID)

	local CompilationResult = Script:Compile()
	if not CompilationResult.Success then
		ProcessFactory.TerminateProcess(PID, -1)
		return Result.new(false, `Failed to compile script\n{CompilationResult.Reason}`) :: Result<CProcess>
	end

	ProcessScheduler.SpawnThread(PID, true, Script.Run :: any, Script)

	return Result.new(true, "", Process)
end

function ProcessFactory.TerminateProcess(PID: number, ExitCode: number)
	local Process = AllProcesses[PID]
	if not Process then
		return
	end

	-- Delete children processes
	for _, ChildPID in Process.m_ChildPIDs do
		ProcessFactory.TerminateProcess(ChildPID, ExitCode)
	end

	-- Detach our process so that it doesn't leak in our parent process
	ProcessFactory.DetachProcess(PID)

	Process:Destroy()
	ScriptFactory.FlushProcessCache(PID)
	ProcessScheduler.ProcessTerminated(PID)
	ReleasePID(PID)
	AllProcesses[PID] = nil

	Log.debug(`Terminated process PID: {PID} ExitCode: {ExitCode}`)
end

function ProcessFactory.GetProcess(PID: number): CProcess?
	return AllProcesses[PID]
end

function ProcessFactory.GetAllProcesses(): { [number]: CProcess }
	return AllProcesses
end

function ProcessFactory.SetParentProcess(PID: number, ParentPID: number)
	local Process, ParentProcess = AllProcesses[PID], AllProcesses[ParentPID]
	if not Process or not ParentProcess then
		warn(`ProcessFactory::SetParentProcess, one of the provided PID's were invalid [{PID}] [{ParentPID}]`)
		return false
	end

	if PID == ParentPID then
		warn(`ProcessFactory::SetParentProcess, cannot set cyclic parent child relationship`)
		return false
	end

	local OldParent = Process.m_ParentPID and AllProcesses[Process.m_ParentPID]
	if OldParent then
		local Index = table.find(OldParent.m_ChildPIDs, PID)
		if Index then
			table.remove(OldParent.m_ChildPIDs, Index)
		end
	end

	Process.m_ParentPID = ParentPID
	table.insert(ParentProcess.m_ChildPIDs, PID)

	return true
end

function ProcessFactory.DetachProcess(PID: number)
	local Process = AllProcesses[PID]
	if not Process then
		warn(`ProcessFactory::DetachProcess, provided PID does not exist`)
		return
	end

	if not Process.m_ParentPID then
		return
	end

	local ParentProcess = Process.m_ParentPID and AllProcesses[Process.m_ParentPID]
	if not ParentProcess then -- We have parent pid but no process exists?
		Process.m_ParentPID = nil
		warn(`ProcessFactory::DetachProcess, process was hanging, had parent PID but no parent process`)
		return
	end

	local Index = table.find(ParentProcess.m_ChildPIDs, PID)
	if Index then
		table.remove(ParentProcess.m_ChildPIDs, Index)
	end

	return
end

return ProcessFactory
