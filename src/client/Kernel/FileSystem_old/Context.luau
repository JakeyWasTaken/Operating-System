export type Context = {
	WorkingDirectory: string,
}

local Context = {}

function Context.new(): Context
	return {
		WorkingDirectory = "/",
	}
end

return Context
