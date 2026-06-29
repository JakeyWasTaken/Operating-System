local fs = require("@osiris/fs")
local process = require("@osiris/process")

local Ansi = require("/system/lib/Ansi.luau")
local Parser = require("./Parser.luau")
local Stdio = require("./Stdio.luau")
local WindowManager = require("./WindowManager.luau")

local HOME_DIRECTORY = "/"
local SEARCH_PATHS = { "/bin" }

local Output = Stdio.new()
local Terminal = WindowManager.new(Output)

local Environment = process.GetEnvironment() or {}
local WorkingDirectory = HOME_DIRECTORY

--- Collapses "." and ".." segments into a clean absolute path.
local function Normalize(Path: string): string
	local Parts = {}
	for _, Segment in Path:split("/") do
		if Segment == "" or Segment == "." then
			continue
		elseif Segment == ".." then
			if #Parts > 0 then
				table.remove(Parts)
			end
		else
			table.insert(Parts, Segment)
		end
	end

	return "/" .. table.concat(Parts, "/")
end

local function Prompt(): string
	return Ansi.Style(WorkingDirectory, "Cyan", "Bold") .. " $ "
end

--- Writes an error line in red.
local function WriteError(Message: string)
	Output:WriteLine(Ansi.Style(Message, "Red"))
end

--- Resolves a program name to an existing file path, searching SEARCH_PATHS for
--- bare names and trying a `.luau` extension. Returns nil if nothing is found.
local function ResolveProgram(Name: string): string?
	local function Exists(Path: string): boolean
		local Handle = fs.Open(Path)
		if Handle then
			fs.Close(Handle)
			return true
		end

		return false
	end

	local function FirstExisting(Base: string): string?
		if Exists(Base) then
			return Base
		end

		if string.sub(Base, -5) ~= ".luau" and Exists(Base .. ".luau") then
			return Base .. ".luau"
		end

		return nil
	end

	-- Explicit paths are used as-is.
	if string.find(Name, "/", 1, true) then
		local Base = if string.sub(Name, 1, 1) == "/" then Name else `{WorkingDirectory}/{Name}`
		return FirstExisting(Base)
	end

	for _, Directory in SEARCH_PATHS do
		local Resolved = FirstExisting(`{Directory}/{Name}`)
		if Resolved then
			return Resolved
		end
	end

	return nil
end

--- Builtins handled by the shell itself. Each returns true once handled.
local Builtins: { [string]: (Command: Parser.Command) -> boolean } = {}

Builtins.clear = function()
	Output:Clear()
	return true
end

Builtins.help = function()
	Output:WriteLine(Ansi.Style("builtins:", "Bold") .. " cd, clear, exit, help, pwd")

	for _, Directory in SEARCH_PATHS do
		local Entries = fs.List(Directory)
		if not Entries then
			continue
		end

		local Names = {}
		for _, Entry in Entries do
			if not Entry.IsDirectory then
				table.insert(Names, (string.gsub(Entry.Name, "%.luau$", "")))
			end
		end
		table.sort(Names)

		Output:WriteLine(Ansi.Style(`{Directory}:`, "Bold") .. " " .. table.concat(Names, ", "))
	end

	return true
end

Builtins.pwd = function()
	Output:WriteLine(WorkingDirectory)
	return true
end

Builtins.cd = function(Command)
	local Target = Command.Arguments[1] or HOME_DIRECTORY

	-- Resolve relative targets against the cwd, then collapse . and .. segments.
	if string.sub(Target, 1, 1) ~= "/" then
		Target = `{WorkingDirectory}/{Target}`
	end
	Target = Normalize(Target)

	local Entries = fs.List(Target)
	if not Entries then
		WriteError(`cd: {Command.Arguments[1] or Target}: no such directory`)
		return true
	end

	WorkingDirectory = Target
	return true
end

--- Spawns an external program, piping its output to the terminal and the user's
--- input lines to its stdin until it exits.
local function RunProgram(Command: Parser.Command)
	local Path = ResolveProgram(Command.Program)
	if not Path then
		WriteError(`{Command.Program}: command not found`)
		return
	end

	-- Children inherit the cwd both as their FileContext (so relative fs paths
	-- resolve there) and as $PWD (so they can display or reason about it).
	local SpawnEnvironment = table.clone(Environment)
	SpawnEnvironment.PWD = WorkingDirectory

	local Handle, SpawnError = process.Spawn(Path, SpawnEnvironment, Command.Arguments, {
		FileContext = { WorkingDirectory = WorkingDirectory, HomeDirectory = HOME_DIRECTORY },
	})

	if not Handle then
		WriteError(`{Command.Program}: {SpawnError}`)
		return
	end

	-- Drain the child's output into our buffer. These end when the streams close.
	local OutReader = task.spawn(function()
		Output:ListenToReader(Handle.StdOut)
	end)

	-- Disable till we only push errors which aren't caught
	-- local ErrReader = task.spawn(function()
	-- 	Output:ListenToReader(Handle.StdErr)
	-- end)

	-- Forward submitted lines to the child. It is responsible for its own echo.
	Terminal:SetPrompt("")
	Terminal:SetEcho(false)
	local InputForwarder = task.spawn(function()
		while true do
			Handle.StdIn:Write(Terminal:ReadLine() .. "\n")
		end
	end)

	Handle.Status()

	task.cancel(InputForwarder)
	task.cancel(OutReader)
	-- task.cancel(ErrReader)
end

Output:WriteLine(Ansi.Style("Osiris Shell", "Green", "Bold") .. " - type 'help' for builtins")

while true do
	Terminal:SetPrompt(Prompt())
	Terminal:SetEcho(true)

	local Line = Terminal:ReadLine()

	local Command, ParseError = Parser.Parse(Line)
	if not Command then
		if ParseError ~= "" then
			WriteError(`shell: {ParseError}`)
		end
		continue
	end

	if Command.Program == "exit" then
		break
	end

	local Builtin = Builtins[Command.Program]
	if Builtin then
		Builtin(Command)
		continue
	end

	RunProgram(Command)
end

process.Terminate(process.GetPID())
