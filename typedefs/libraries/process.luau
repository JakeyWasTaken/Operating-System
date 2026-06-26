type FileContext = {
	WorkingDirectory: string,
	HomeDirectory: string,
}

export type IOReader = {
	--- @param ChunkSize: number? - Defaults to 1KB
	---
	--- @return Data: string? - Returns nil when the stream closes
	Read: (self: IOReader, ChunkSize: number?) -> string?,
}

export type IOWriter = {
	Write: (self: IOWriter, Data: string) -> (),
	Close: (self: IOWriter) -> (),
}

local process = {}

function process.GetPID(): number
	return nil :: any
end

function process.GetArguments(): { string }
	return nil :: any
end

function process.GetEnvironment(): { [string]: string? }
	return nil :: any
end

function process.GetPermissions(): { Elevated: boolean }
	return nil :: any
end

function process.GetParentPID(): number?
	return nil :: any
end

function process.GetChildPIDs(): { number }
	return nil :: any
end

function process.Spawn(
	ProgramPath: string,
	Environment: { [string]: string? },
	Arguments: { string },
	Options: { FileContext: FileContext?, ForwardStdIO: boolean? }
): ({ PID: number, StdIn: IOWriter, StdOut: IOReader, StdErr: IOReader, Status: () -> number }?, string)
	return nil :: any
end

function process.Terminate(PID: number): (boolean?, string)
	return nil :: any
end

function process.Detach(PID: number): (boolean?, string)
	return nil :: any
end

return process
