export type FileContext = {
	HomeDirectory: string,
	WorkingDirectory: string,
}

return function(Copy: FileContext?)
	return {
		WorkingDirectory = Copy and Copy.WorkingDirectory or "/",
		HomeDirectory = Copy and Copy.HomeDirectory or "/home",
	}
end
