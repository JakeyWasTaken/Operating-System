export type Context = {
	WorkingDirectory: string,
	HomeDirectory: string,
}

local Context = {}

function Context.new(): Context
	return {
		WorkingDirectory = "home",
		HomeDirectory = "home",
	}
end

return Context
