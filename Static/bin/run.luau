--[[

    run

    Runs one or more files.

    arguments:

    -a - Run files asynchronously (concurrently) instead of one at a time

    example:

    run a.luau b.luau
    run -a a.luau b.luau
]]

local fs = require("@osiris/fs")
local process = require("@osiris/process")

local Ansi = require("/system/lib/Ansi.luau")
local Args = require("/system/lib/Args.luau")

local Parsed, ParseError = Args.Parse(process.GetArguments(), {
	{ Name = "Async", Short = "a", Default = false },
})

if not Parsed then
	warn(Ansi.Style(`run: {ParseError}`, "Red"))
	exit(-1)
end

if #Parsed.Positionals == 0 then
	warn(Ansi.Style("run: missing file operand", "Red"))
	exit(-1)
end

local Environment = process.GetEnvironment() or {}
local PWD = Environment.PWD or "/"

local function Exists(Path: string): boolean
	local Handle = fs.Open(Path)
	if Handle then
		fs.Close(Handle)
		return true
	end

	return false
end

-- Joins a raw file argument onto $PWD (unless it's already absolute) and
-- tries a ".luau" extension if the bare name doesn't exist.
local function ResolveFile(Raw: string): string?
	local Absolute = if Raw:sub(1, 1) == "/" then Raw elseif PWD == "/" then `/{Raw}` else `{PWD}/{Raw}`

	if Exists(Absolute) then
		return Absolute
	end

	if Absolute:sub(-5) ~= ".luau" and Exists(Absolute .. ".luau") then
		return Absolute .. ".luau"
	end

	return nil
end

local Targets = {}
for _, Raw in Parsed.Positionals do
	local Resolved = ResolveFile(Raw)
	if not Resolved then
		warn(Ansi.Style(`run: {Raw}: no such file`, "Red"))
		exit(-1)
	end

	table.insert(Targets, Resolved)
end

local FailureCount = 0

local function RunOne(Path: string): ({ PID: number, Status: () -> number }?, string)
	return process.Spawn(Path, Environment, {}, { ForwardStdIO = true })
end

if Parsed.Options.Async then
	-- Spawn every target up front so they run concurrently, then collect them.
	local Handles = {}

	for _, Path in Targets do
		local Handle, SpawnError = RunOne(Path)
		if not Handle then
			warn(Ansi.Style(`run: {Path}: {SpawnError}`, "Red"))
			FailureCount += 1
			continue
		end

		table.insert(Handles, Handle)
	end

	for _, Handle in Handles do
		if Handle.Status() ~= 0 then
			FailureCount += 1
		end
	end
else
	-- Wait for each one to finish before starting the next.
	for _, Path in Targets do
		local Handle, SpawnError = RunOne(Path)
		if not Handle then
			warn(Ansi.Style(`run: {Path}: {SpawnError}`, "Red"))
			FailureCount += 1
			continue
		end

		if Handle.Status() ~= 0 then
			FailureCount += 1
		end
	end
end

exit(if FailureCount > 0 then 1 else 0)
