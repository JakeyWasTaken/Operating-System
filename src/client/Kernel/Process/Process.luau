local Class = require("@core/Class")
local Context = require("@core/General/Context")

--- Construction and Destruction can only happen via `ProcessFactory`
export type CProcess = {
	new: (PID: number, Label: string) -> CProcess,

	-- --------------------------------- Methods -------------------------------- --

	Destroy: (self: CProcess) -> (),

	-- --------------------------------- Members -------------------------------- --
	PID: number,
} & Class.Base

local CProcess: CProcess = Class("CProcess")

function CProcess.new(PID: number, ExecutableContents: string)
	if Context.IsTestRun then
		assert(debug.info():find("ProcessFactory"), `Cannot call CProcess constructor outside of ProcessFactory`)
	end

	local self: CProcess = setmetatable({}, CProcess) :: any
	(CProcess :: any)(self)

	self.PID = PID

	return self
end

function CProcess:Destroy()
	if Context.IsTestRun then
		assert(debug.info():find("ProcessFactory"), `Cannot call CProcess destructor outside of ProcessFactory`)
	end

	self:_Destroy()
end

return CProcess
