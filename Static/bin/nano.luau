-- nano - a simple, full-screen text editor (Ctrl+S save, Ctrl+X exit)
local process = require("@osiris/process")
local Ansi = require("/system/lib/Ansi.luau")

local Arguments = process.GetArguments() or {}
local Path = Arguments[1]

if not Path then
	warn(Ansi.Style("nano: missing file operand", "Red"))
	exit(-1)
end

-- Resolve a bare/relative path against $PWD, same convention as run.luau.
local Environment = process.GetEnvironment() or {}
local PWD = Environment.PWD or "/"

if Path:sub(1, 1) ~= "/" then
	Path = if PWD == "/" then `/{Path}` else `{PWD}/{Path}`
end

local Editor = require("/system/bin/Nano/Editor.luau")
Editor.Open(Path)

exit(0)
