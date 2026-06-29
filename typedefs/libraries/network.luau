local network = {}

function network.RequestAsync(Options: {
	Url: string,
	Method: string?,
	Headers: { [string]: string }?,
	Body: string?,
	Compress: Enum.HttpCompression?,
	Timeout: number?,
}): { Success: boolean, StatusCode: number, StatusMessage: string, Headers: { [string]: string }, Body: unknown }
	return nil :: any
end

function network.JSONEncode(Input: unknown): string
	return nil :: any
end

function network.JSONDecode(Data: string): unknown
	return nil :: any
end

function network.UrlEncode(Data: string): string
	return nil :: any
end

function network.GenerateGUID(WrapInCurlyBraces: boolean): string
	return nil :: any
end

return network
