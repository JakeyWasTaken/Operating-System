const CPath = require("@kernel/File/Path")
const Context = require("@core/General/Context")

const IOStream = require("@core/IO/Stream")

type CPath = CPath.CPath

return {
	Name = "test",
	Enabled = Context.IsTestRun,
	MakeLibrary = function(LibraryPID: number, ScriptPath: CPath)
		return {
			Core = {
				MakeIOStream = function()
					return IOStream.new()
				end
			}
		}
    end,
}
