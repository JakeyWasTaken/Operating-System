--!strict

const Class = require("@core/Class")
const Context = require("@core/General/Context")
const FileContext = require("@kernel/File/Context")
const Result = require("@core/Result")
const CScript = require("@kernel/Process/Script/Script")

type CScript = CScript.CScript
type FileContext = FileContext.Context
type Result<T> = Result.Result<T>

--- Construction and Destruction can only happen via `ProcessFactory`
export type CProcess = {
	new: (PID: number, Label: string, FileContext: FileContext, Terminate: (ExitCode: number) -> ()) -> CProcess,

	-- --------------------------------- Methods -------------------------------- --

	GetParentPID: (self: CProcess) -> number?,
	GetChildPIDs: (self: CProcess) -> { number },

	Destroy: (self: CProcess) -> (),

	-- --------------------------------- Members -------------------------------- --

	Terminate: (ExitCode: number) -> (),

	PID: number,
	m_ParentPID: number?,
	m_ChildPIDs: { number },

	FileContext: FileContext,

	StartedAt: number,
} & Class.Base

local CProcess: CProcess = Class("CProcess") :: any

function CProcess.new(PID: number, Label: string, FileContext: FileContext, Terminate: (ExitCode: number) -> ())
	if Context.IsTestRun then
		assert(debug.info(2, "s"):find("ProcessFactory"), `Cannot call CProcess constructor outside of ProcessFactory`)
	end

	local self: CProcess = setmetatable({}, CProcess) :: any
	(CProcess :: any)(self)

	self.Terminate = Terminate

	self.PID = PID
	self.m_ParentPID = nil
	self.m_ChildPIDs = {}

	self.FileContext = FileContext

	self.StartedAt = os.clock()

	return self
end

function CProcess:GetParentPID()
	return self.m_ParentPID
end

function CProcess:GetChildPIDs()
	return table.clone(self.m_ChildPIDs)
end

function CProcess:Destroy()
	if Context.IsTestRun then
		assert(debug.info(2, "s"):find("ProcessFactory"), `Cannot call CProcess destructor outside of ProcessFactory`)
	end

	self._Destroy()
end

return CProcess
