--[[

	LibTOML / toml

	TOML parser

]]

const tinytoml = require("@vendor/tinytoml")
const CFilePath = require("@kernel/File/FilePath")

type CFilePath = CFilePath.CFilePath

return {
	Name = "toml",
	Enabled = true,
	MakeLibrary = function(_LibraryPID: number, _ScriptPath: CFilePath)
		return {
			Parse = function(Source: string): ({ [string]: any }?, string)
				if typeof(Source) ~= "string" then
					return nil, "Expected Source to be of type string"
				end

				local Ok, Result = pcall(tinytoml.parse, Source, { load_from_string = true })
				if not Ok then
					return nil, tostring(Result)
				end

				return Result, ""
			end,
		}
	end,
}
