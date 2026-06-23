--!strict

const Class = require("@core/Class")
const Context = require("@core/General/Context")
const FileContext = require("@kernel/File/Context")
const Result = require("@core/Result")
const CScript = require("@kernel/Process/Script/Script")
const CIOStream = require("@core/IO/Stream")
const CConditionVariable = require("@core/IO/ConditionVariable")

type IOStream = CIOStream.CIOStream
type CScript = CScript.CScript
type FileContext = FileContext.Context
type CConditionVariable<T...> = CConditionVariable.CConditionVariable<T...>
type Result<T> = Result.Result<T>

--- Construction and Destruction can only happen via `ProcessFactory`
export type CProcess = {
	new: (PID: number, Label: string, FileContext: FileContext) -> CProcess,

	-- --------------------------------- Methods -------------------------------- --

	GetPID: (self: CProcess) -> number,
	GetParentPID: (self: CProcess) -> number?,
	GetChildPIDs: (self: CProcess) -> { number },

	WaitForTermination: (self: CProcess) -> number,

	Destroy: (self: CProcess, ExitCode: number) -> (),

	-- --------------------------------- Members -------------------------------- --

	FileContext: FileContext,
	StartedAt: number,

	StdIn: IOStream,
	StdOut: IOStream,
	StdErr: IOStream,

	m_TerminationCV: CConditionVariable<number>,

	m_PID: number,
	m_ParentPID: number?,
	m_ChildPIDs: { number },

} & Class.Base

local CProcess: CProcess = Class("CProcess") :: any

function CProcess.new(PID: number, Label: string, FileContext: FileContext)
	if Context.IsTestRun then
		assert(debug.info(2, "s"):find("ProcessFactory"), `Cannot call CProcess constructor outside of ProcessFactory`)
	end

	local self: CProcess = setmetatable({}, CProcess) :: any
	(CProcess :: any)(self)

	self.FileContext = FileContext
	self.StartedAt = os.clock()

	self.StdIn = CIOStream.new()
	self.StdOut = CIOStream.new()
	self.StdErr = CIOStream.new()

	self.m_TerminationCV = CConditionVariable.new()

	self.m_PID = PID
	self.m_ParentPID = nil
	self.m_ChildPIDs = {}

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

function CProcess:WaitForTermination()
	return self.m_TerminationCV:Wait()
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
