export type Context = {
	WorkingDirectory: string,
	HomeDirectory: string,
}

local Context = {}

function Context.new(): Context
	return {
		WorkingDirectory = "/",
		HomeDirectory = "/home",
	}
end

function Context.Copy(Context: Context): Context
	return {
		WorkingDirectory = Context.WorkingDirectory,
		HomeDirectory = Context.HomeDirectory,
	}
end

return Context
