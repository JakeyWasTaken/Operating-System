--[[

	LibTest / test

	Testing only library, disabled out of studio

]]

const FilePath = require("@kernel/File/FilePath")
const Context = require("@core/General/Context")

const IOStream = require("@core/IO/Stream")
const ConditionVariable = require("@core/IO/ConditionVariable")

type CFilePath = FilePath.CFilePath

return {
	Name = "test",
	Enabled = Context.IsTestRun,
	MakeLibrary = function(LibraryPID: number, ScriptPath: CFilePath)
		return {
			Core = {
				MakeIOStream = function()
					return IOStream.new()
				end,

				MakeConditionVariable = function()
					return ConditionVariable.new()
				end
			}
		}
    end,
}
