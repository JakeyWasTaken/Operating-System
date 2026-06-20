const CPath = require("@kernel/File/Path")

type CPath = CPath.CPath

return {
	Name = "process",
	MakeLibrary = function(PID: number, ScriptPath: CPath)
        return {
            GetPID = function()
                return PID
            end
        }
    end,
}
