--!strict

const Class = require("@core/Class")
const Context = require("@core/General/Context")
const FileContext = require("@kernel/File/FileContext")
const Result = require("@core/Result")
const CScript = require("@kernel/Process/Script/Script")
const CIOStream = require("@core/IO/Stream")
const CConditionVariable = require("@core/IO/ConditionVariable")
const Handle = require("@core/Handle")

type IOStream = CIOStream.CIOStream
type CScript = CScript.CScript
type FileContext = FileContext.FileContext
type CConditionVariable<T...> = CConditionVariable.CConditionVariable<T...>
type Result<T> = Result.Result<T>

--- Construction and Destruction can only happen via `ProcessFactory`
export type CProcess = {
	new: (PID: number, Label: string, Environment: {[string]: string?}, Arguments: {string}, FileContext: FileContext) -> CProcess,

	-- --------------------------------- Methods -------------------------------- --

	GetPID: (self: CProcess) -> number,
	GetParentPID: (self: CProcess) -> number?,
	GetChildPIDs: (self: CProcess) -> { number },

	--- Waits for termination and returns exit code
	GetExitCode: (self: CProcess) -> number,

	--- Creates a process-scoped handle, returns the process-scoped handle
	CreateScopedHandle: (self: CProcess, GlobalHandle: string) -> string,
	RemoveScopedHandle: (self: CProcess, ScopedHandle: string) -> (),

	GetScopedHandle: (self: CProcess, GlobalHandle: string) -> string?,
	GetGlobalHandle: (self: CProcess, ScopedHandle: string) -> string?,

	Destroy: (self: CProcess, ExitCode: number) -> (),

	-- --------------------------------- Members -------------------------------- --

	FileContext: FileContext,

	Environment: {[string]: string?},
	Arguments: {string},

	StartedAt: number,

	StdIn: IOStream,
	StdOut: IOStream,
	StdErr: IOStream,

	m_TerminationCV: CConditionVariable<number>,

	m_PID: number,
	m_ParentPID: number?,
	m_ChildPIDs: { number },

	m_HandleTable: { [string]: string },
} & Class.Base

local CProcess: CProcess = Class("CProcess") :: any

function CProcess.new(PID: number, Label: string, Environment: {[string]: string?}, Arguments: {string}, FileContext: FileContext)
	if Context.IsTestRun then
		assert(debug.info(2, "s"):find("ProcessFactory"), `Cannot call CProcess constructor outside of ProcessFactory`)
	end

	local self: CProcess = setmetatable({}, CProcess) :: any
	(CProcess :: any)(self)

	self.FileContext = FileContext
	self.Environment = Environment
	self.Arguments = Arguments
	self.StartedAt = os.clock()

	self.StdIn = CIOStream.new()
	self.StdOut = CIOStream.new()
	self.StdErr = CIOStream.new()

	self.m_TerminationCV = CConditionVariable.new()

	self.m_PID = PID
	self.m_ParentPID = nil
	self.m_ChildPIDs = {}

	self.m_HandleTable = {}

	return self
end

function CProcess:GetPID()
	return self.m_PID
end

function CProcess:GetParentPID()
	return self.m_ParentPID
end

function CProcess:GetChildPIDs()
	return table.clone(self.m_ChildPIDs)
end

function CProcess:GetExitCode()
	return self.m_TerminationCV:Wait()
end

function CProcess:CreateScopedHandle(GlobalHandle: string)
	local ScopedHandle = Handle()
	self.m_HandleTable[ScopedHandle] = GlobalHandle

	return ScopedHandle
end

function CProcess:RemoveScopedHandle(ScopedHandle: string)
	self.m_HandleTable[ScopedHandle] = nil
end

function CProcess:GetScopedHandle(GlobalHandle)
	for Scoped, Handle in self.m_HandleTable do
		if Handle == GlobalHandle then
			return Scoped
		end
	end

	return nil
end

function CProcess:GetGlobalHandle(ScopedHandle: string)
	return self.m_HandleTable[ScopedHandle]
end

function CProcess:Destroy(ExitCode: number)
	if Context.IsTestRun then
		assert(debug.info(2, "s"):find("ProcessFactory"), `Cannot call CProcess destructor outside of ProcessFactory`)
	end

	self.StdIn:Close()
	self.StdOut:Close()
	self.StdErr:Close()

	self.m_TerminationCV:Notify(ExitCode)

	self._Destroy()
end

return CProcess
