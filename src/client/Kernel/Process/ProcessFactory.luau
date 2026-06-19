local CPath = require("@kernel/File/Path")
local CProcess = require("@kernel/Process/Process")
local Context = require("@kernel/File/Context")
local FileSystem = require("@kernel/File/FileSystem")
local Result = require("@core/Result")

type Result<T> = Result.Result<T>
type Context = Context.Context
type CPath = CPath.CPath
type CProcess = CProcess.CProcess

-- stylua: ignore
local GetFreePID: () -> number, ReleasePID: (number) -> () do
	local FreePIDs = {}
	local PIDCounter = 0

	GetFreePID = function()
		if #FreePIDs == 0 then
			PIDCounter += 1
			return PIDCounter
		end

		return table.remove(FreePIDs)
	end

	ReleasePID = function(PID: number)
		table.insert(FreePIDs, PID)
	end
end

local AllProcesses: { [number]: CProcess } = {}

local ProcessFactory = {}

function ProcessFactory.CreateProcess(ProgramPath: CPath, Context: Context): Result<CProcess>
	local FileResult = FileSystem:Resolve(ProgramPath, Context)
	if not FileResult.Success then
		return FileResult
	end

	local FileHandle = FileResult.Value

	if FileResult:GetType(FileHandle).Value ~= "File" then
		return Result.new(false, "Program was not a file")
	end

	local FileContentsResult = FileSystem:Read(FileResult.Value)
	if not FileContentsResult.Success then
		return FileContentsResult
	end

	local PID = GetFreePID()
	local Process = CProcess.new(PID, FileResult:GetName(FileHandle).Value or "Unknown")
	AllProcesses[PID] = Process

	return Process
end

function ProcessFactory.TerminateProcess(PID: number)
	local Process = AllProcesses[PID]
	if not Process then
		return
	end

	Process:Destroy()
	ReleasePID(PID)
end

return ProcessFactory
