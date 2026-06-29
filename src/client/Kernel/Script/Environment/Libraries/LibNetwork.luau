--[[

	LibNetwork / network

	Wraps the most important parts of HttpService

]]

const CFilePath = require("@kernel/File/FilePath")

const HttpService = game:GetService("HttpService")

type CFilePath = CFilePath.CFilePath

return {
	Name = "network",
	Enabled = true,
	MakeLibrary = function(LibraryPID: number, ScriptPath: CFilePath)
		return {
            RequestAsync = function(Options: { Url: string, Method: string?, Headers: { [string]: string }?, Body: string?, Compress: Enum.HttpCompression?, Timeout: number? }): { Success: boolean, StatusCode: number, StatusMessage: string, Headers: { [string]: string }, Body: unknown }
                -- Try get event
                local Event = workspace:FindFirstChild("RequestAsync")
                if not Event then
                    error(`Could not get RequestAsync event`, 0)
                end

                return Event:InvokeServer(Options)
            end,

            JSONEncode = function(Input: unknown): string
                return HttpService:JSONEncode(Input)
            end,

            JSONDecode = function(Data: string): unknown
                return HttpService:JSONDecode(Data)
            end,

            UrlEncode = function(Data: string): string
                return HttpService:UrlEncode(Data)
            end,

            GenerateGUID = function(WrapInCurlyBraces: boolean): string
                return HttpService:GenerateGUID(WrapInCurlyBraces)
            end,
		}
	end,
}
