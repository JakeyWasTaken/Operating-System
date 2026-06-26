local fs = {}

function fs.CreateFile(Path: string): (boolean?, string)
	return nil :: any
end

function fs.CreateDirectory(Path: string): (boolean?, string)
	return nil :: any
end

function fs.Delete(Path: string): (boolean?, string)
	return nil :: any
end

function fs.Open(Path: string, Exclusive: boolean?): (string?, string)
	return nil :: any
end

function fs.Close(ScopedHandle: string): (boolean?, string)
	return nil :: any
end

function fs.Read(ScopedHandle: string): (string?, string)
	return nil :: any
end

function fs.Write(ScopedHandle: string, Data: string, Offset: number?): (boolean?, string)
	return nil :: any
end

function fs.GetMetadata(ScopedHandle: string): ({ CreatedAt: number, UpdatedAt: number }?, string)
	return nil :: any
end

function fs.GetName(ScopedHandle: string): (string?, string)
	return nil :: any
end

function fs.Rename(ScopedHandle: string, Name: string): (boolean?, string)
	return nil :: any
end

function fs.Move(ScopedHandle: string, DestinationPath: string): (boolean?, string)
	return nil :: any
end

return fs
