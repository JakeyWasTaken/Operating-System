--!strict

const FilePath = require("@kernel/File/FileSystem/FilePath")
const FileSystemInterface = require("@kernel/File/FileSystemInterface")
const CProcess = require("@kernel/Process/Process")
const FileContext = require("@kernel/File/FileContext")
const FileSystemManager = require("@kernel/File/FileSystemManager")
const Result = require("@core/Result")
const ScriptFactory = require("@kernel/Process/Script/ScriptFactory")
const Log = require("@core/Log")
const ProcessScheduler = require("@kernel/Process/ProcessScheduler")

type Result<T> = Result.Result<T>
type FileContext = FileContext.FileContext
type CFilePath = FilePath.CFilePath
type CProcess = CProcess.CProcess

-- stylua: ignore
local GetNextPID: () -> number do
	local PIDCounter = 0

	GetNextPID = function()
		PIDCounter += 1
		return PIDCounter
	end
end

local AllProcesses: { [number]: CProcess } = {}

local ProcessFactory = {}
shared.ProcessFactory = ProcessFactory

function ProcessFactory.CreateProcess(ProgramPath: CFilePath, Environment: { [string]: string? }, Arguments: {string}, ProgramContext: FileContext): Result<CProcess>
	-- Validate environment
	for K, EnvironmentVariable in Environment do
		if typeof(K) ~= "string" then
			return Result.new(false, `Environment must be a map of string to string`) :: Result<CProcess>
		end

		if typeof(EnvironmentVariable) ~= "string" then
			return Result.new(false, `Environment variable at key "{K}" was not a string.`) :: Result<CProcess>
		end
	end

	-- Validate arguments
	for i, Argument in Arguments do
		if typeof(i) ~= "number" then
			return Result.new(false, `Arguments must be an array of strings`) :: Result<CProcess>
		end

		if typeof(Argument) ~= "string" then
			return Result.new(false, `Argument at index [{i}] was not a string.`) :: Result<CProcess>
		end
	end

	if not FilePath.ValidateStrings({ ProgramContext.WorkingDirectory, ProgramContext.HomeDirectory }) then
		return Result.new(false, `Program context was in-valid`) :: Result<CProcess>
	end

	local FS = FileSystemManager.GetActiveFileSystem()
	if not FS then
		return Result.new(false, `No active file system`) :: Result<CProcess>
	end

	-- Fetch file and validate it & params
	local Node = FS:ResolvePath(ProgramPath, ProgramContext)
	if not Node then
		return Result.new(false, `Program path does not exist`) :: Result<CProcess>
	end

	if not Node:IsFile() then
		return Result.new(false, "Program was not a file") :: Result<CProcess>
	end

	local File = Node :: FileSystemInterface.IFile
	local FileContents = File:Read()

	-- Create process & run script

	local PID = GetNextPID()
	local Label = Node:GetName()
	local Process = CProcess.new(PID, Label, Environment, Arguments, ProgramContext)
	AllProcesses[PID] = Process

	Log.debug(`Created new process PID: {PID} Label: "{Label}"`)

	-- We pass in the program path parent here as opposed to working directory since they are different
	local Script = ScriptFactory.CreateScript(FileContents, ProgramPath:GetParent(), Node:GetHandle(), PID)

	local CompilationResult = Script:Compile()
	if not CompilationResult.Success then
		ProcessFactory.TerminateProcess(PID, -1)
		return Result.new(false, `Failed to compile script\n{CompilationResult.Reason}`) :: Result<CProcess>
	end

	-- Any other exit code should be passed via env::exit or libprocess::Terminate
	ProcessScheduler.SpawnThreadDeferred(PID, true, function()
		local Result = Script:Run()
		ProcessFactory.TerminateProcess(PID, Result.Success and 0 or -1)
	end)

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

	Process:Destroy(ExitCode)
	ScriptFactory.OnProcessTermination(PID)
	ProcessScheduler.OnProcessTerminated(PID)
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
		return
	end

	if PID == ParentPID then
		warn(`ProcessFactory::SetParentProcess, cannot set cyclic parent child relationship`)
		return
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

	return
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
