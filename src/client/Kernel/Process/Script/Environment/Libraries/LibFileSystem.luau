--[[

	LibFileSystem / fs

	Testing only library, disabled out of studio

]]

const CPath = require("@kernel/File/Path")

type CPath = CPath.CPath

return {
	Name = "fs",
	Enabled = true,
	MakeLibrary = function(LibraryPID: number, ScriptPath: CPath)
		return {
            -- isdir, isfile, makedir, makefile, etc..
            -- just read lune shit

            --[[
            have open return a handle unique to this process, which is then used in all other calls
            ]]

            Open = function()

            end,

            Close = function()

            end,

            Read = function()

            end,

            Write = function()

            end,

            GetMetadata = function()

            end,
		}
    end,
}
