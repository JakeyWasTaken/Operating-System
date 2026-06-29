local stdio = {}

--- Writes its arguments to the process's stdout, exactly like print did before
--- it started appending a trailing newline. No newline is added.
function stdio.StdOut(...: any): (boolean?, string)
	return nil :: any
end

--- Writes its arguments to the process's stderr, exactly like warn did before
--- it started appending a trailing newline. No newline is added.
function stdio.StdError(...: any): (boolean?, string)
	return nil :: any
end

return stdio
