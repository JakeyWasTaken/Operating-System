--!strict
const CPath = require("@kernel/File/Path")
const FileSystem = require("@kernel/File/FileSystem")
const FileContext = require("@kernel/File/Context")
const ProcessScheduler = require("@kernel/Process/ProcessScheduler")

const Libraries = {
	require("./Libraries/LibProcess")
}

type CPath = CPath.CPath

-- No builtin type name for runtime userdata. Same trick ProcessScheduler.luau uses.
type userdata = any

-- Environment is shared across all scripts within one process
-- this is mainly for _G & shared
local GlobalCache = {}

local EnvironmentFactory = {}

function EnvironmentFactory.CreateEnvironment(PID: number, ScriptPath: CPath)
	local function Output(Category: string, Callback: (string) -> ())
		return function(Text: string)
			-- push to process output

			Callback(Text)
		end
	end

	local IncludedLibraries = {}
	local function GetLibrary(Name: string)
		if IncludedLibraries[Name] then
			return IncludedLibraries[Name]
		end

		for _, LibraryDefinition in Libraries do
			if LibraryDefinition.Name == Name then
				local Library = LibraryDefinition.MakeLibrary(PID, ScriptPath)
				IncludedLibraries[Name] = Library
				return Library
			end
		end

		return nil
	end

	local function Wait(Time: number?)
		local ThreadId = ProcessScheduler.GetCurrentThreadId()
		assert(ThreadId, `Scheduler global called under unknown thread`)
		ProcessScheduler.Sleep(ThreadId, Time or 0) -- Sleep yields internally, so the thread actually suspends here
	end

	-- Target can be a function or a handle, genuinely either, so it stays unknown.
	local function Spawn(Target: unknown, ...: any): userdata?
		return ProcessScheduler.TaskSpawn(PID, Target, ...)
	end

	local function TaskDefer(fn: (...any) -> ...any, ...: any): userdata?
		-- Leaves it Waiting without a JumpExecution, so it runs next Tick
		-- instead of right now. Matches real task.defer.
		local ThreadId = ProcessScheduler.SpawnThread(PID, false, fn, ...)
		return ProcessScheduler.GetThreadHandle(ThreadId)
	end

	local function TaskDelay(Seconds: number, fn: (...any) -> ...any, ...: any): userdata?
		return Spawn(function(...)
			Wait(Seconds)
			fn(...)
		end, ...)
	end

	local function TaskCancel(Handle: userdata)
		ProcessScheduler.CancelHandle(PID, Handle)
	end

	-- Every "thread" a script holds is one of these opaque handles, never a
	-- real `thread`. resume/status/close/cancel all funnel through
	-- ProcessScheduler, so the kernel stays the only thing that can ever
	-- run one. yield/isyieldable are still the real native functions below,
	-- since they only act on whatever's currently running, which is
	-- already kernel-tracked no matter how it got resumed.
	local function CoroutineCreate(fn: (...any) -> ...any): userdata?
		local ThreadId = ProcessScheduler.CreateThread(PID, fn)
		return ProcessScheduler.GetThreadHandle(ThreadId)
	end

	local function CoroutineResume(Handle: userdata, ...: any): (boolean, ...any)
		return ProcessScheduler.ResumeHandle(PID, Handle, ...)
	end

	local function CoroutineStatus(Handle: userdata): string
		return ProcessScheduler.GetHandleStatus(Handle)
	end

	local function CoroutineWrap(fn: (...any) -> ...any): (...any) -> ...any
		local Handle = CoroutineCreate(fn)
		return function(...)
			local Results = table.pack(CoroutineResume(Handle, ...))
			local Ok = Results[1]
			if not Ok then
				error(Results[2], 0)
			end

			return table.unpack(Results, 2, Results.n)
		end
	end

	local function CoroutineClose(Handle: userdata): (boolean, string?)
		return ProcessScheduler.CloseHandle(PID, Handle)
	end

	local function CoroutineRunning(): (userdata?, boolean)
		local ThreadId = ProcessScheduler.GetCurrentThreadId()
		if not ThreadId then
			return nil, true
		end

		return ProcessScheduler.GetThreadHandle(ThreadId), ProcessScheduler.IsMainThread(ThreadId)
	end

	-- Proxy typeof so our threads return the correct type
	local function Typeof(Value: any): string
		if ProcessScheduler.IsThreadHandle(Value) then
			return "thread"
		end

		return typeof(Value)
	end

	local function Exit(ExitCode: number)
		-- TODO: handle this better eventually
		assert(shared.ProcessFactory, `ProcessFactory was not ready in-time`)
		shared.ProcessFactory.TerminateProcess(PID, ExitCode)
	end

	local function Require(Target: string)
		if Target:sub(1, 1) == "@" then
			local Name = Target:sub(2, #Target)
			local Library = GetLibrary(Name)
			if Library == nil then
				error(`error requiring "{Target}": library does not exist`)
			end

			return Library
		end

		local FilePathStr = Target

		-- TODO: handle this better eventually
		assert(shared.ProcessFactory, `ProcessFactory was not ready in-time`)
		local Process = shared.ProcessFactory.GetProcess(PID)
		assert(Process, `No process with PID "{PID}"`)

		local FilePath = CPath.new(FilePathStr)
		if not FilePath:IsValid() then
			error(`error requiring "{FilePathStr}": invalid path`)
		end

		if FilePath:GetPathType() == "Relative" then
			FilePath = ScriptPath:Append(FilePathStr)
		end

		if not FilePath:IsValid() then
			-- This is pretty vague, this could be weird to debug
			error(`error requiring "{FilePathStr}": expanded path was invalid`)
		end

		local Context = FileContext.Copy(Process.FileContext)
		Context.WorkingDirectory = ScriptPath:ToString()

		local NodeHandle = FileSystem:Resolve(FilePath, Context)
		if not NodeHandle.Success then
			error(`error requiring "{FilePathStr}": no path exists`)
		end

		local Type = FileSystem:GetType(NodeHandle.Value :: string)
		if not Type.Success or Type.Value ~= "File" then
			error(`error requiring "{FilePathStr}": provided path does not point to a file`)
		end

		local Contents = FileSystem:Read(NodeHandle.Value :: string)
		if not Contents.Success then
			error(`error requiring "{FilePathStr}": failed to read file contents`)
		end

		-- Make script
		local Script = shared.ScriptFactory.CreateScript(Contents.Value, FilePath:GetParent(), NodeHandle.Value, PID)
		local CompilationResult = Script:Compile()
		if not CompilationResult.Success then
			error(`error requiring "{FilePathStr}": failed to compile, {CompilationResult.Reason}`)
		end

		local RunResult = Script:Run()
		if not RunResult.Success then
			error(`error requiring "{FilePathStr}": failed to run, {RunResult.Reason}`)
		end

		return RunResult.Value
	end

	-- Global is shared across a process
	local Global = GlobalCache[PID] or {}
	GlobalCache[PID] = Global

	local Environment = {
		-- LOGGING
		print = Output("Print", print),
		warn = Output("Warn", warn),
		error = Output("Error", error :: any),

		string = string,
		bit32 = bit32,
		utf8 = utf8,
		os = os,
		debug = debug,
		buffer = buffer,
		vector = vector,
		math = math,
		table = table,

		DateTime = DateTime,
		Vector3 = Vector3,
		CFrame = CFrame,

		-- Not the real `coroutine` library. Every value here is one of our
		-- opaque handles, never a real `thread`. yield and isyieldable are
		-- still the real native functions, nothing to mediate there.
		coroutine = {
			create = CoroutineCreate,
			resume = CoroutineResume,
			yield = coroutine.yield,
			status = CoroutineStatus,
			wrap = CoroutineWrap,
			close = CoroutineClose,
			running = CoroutineRunning,
			isyieldable = coroutine.isyieldable,
		},

		task = {
			wait = Wait,
			spawn = Spawn,
			defer = TaskDefer,
			delay = TaskDelay,
			cancel = TaskCancel,
		},

		wait = Wait,
		spawn = Spawn,

		tick = tick,
		time = time,
		elapsedTime = elapsedTime,

		getfenv = function() error("getfenv is not enabled") end,
		setfenv = function() error("setfenv is not enabled") end,

		assert = assert,
		gcinfo = gcinfo,
		getmetatable = getmetatable,
		ipairs = ipairs,
		loadstring = function() error("loadstring is not enabled") end,
		newproxy = newproxy,
		next = next,
		pairs = pairs,
		pcall = pcall,
		rawequal = rawequal,
		rawget = rawget,
		rawlen = rawlen,
		rawset = rawset,
		select = select,
		setmetatable = setmetatable,
		tonumber = tonumber,
		tostring = tostring,
		type = type,
		typeof = Typeof,
		unpack = unpack,
		xpcall = xpcall,

		exit = Exit,

		require = Require,

		_G = Global,
		shared = Global,
		_VERSION = "Fiu Interpreter",
	}

	return Environment
end

function EnvironmentFactory.FlushCache(PID: number)
	GlobalCache[PID] = nil
end

return EnvironmentFactory
