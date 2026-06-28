const Log = require("@core/Log")
const FilePath = require("@kernel/File/FilePath")
const FileContext = require("@kernel/File/FileContext")
const ProcessFactory = require("@kernel/Process/ProcessFactory")

const INIT_PATH = "/system/bin/main.luau"

local Result = ProcessFactory.CreateProcess(FilePath.new(INIT_PATH), {}, {}, FileContext())
if not Result.Success or not Result.Value then
	Log.warn(`Failed to start init "{INIT_PATH}": {Result.Reason}`)
	return false
end

-- init must be elevated so it can spawn system services. The process thread is
-- deferred, so this lands before init runs.
Result.Value:SetElevated(true)

Log.info(`Started init, PID {Result.Value:GetPID()}`)

return true
