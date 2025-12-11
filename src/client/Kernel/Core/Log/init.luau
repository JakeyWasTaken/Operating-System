--- @class Log
--- Log class with rich text capabilities

local Players = game:GetService("Players")
local Player = Players.LocalPlayer

local Rich = _G.PRETTY_LOG
local DevOutputEnabled = true

local Log = {}

local function concatenate(...: any): string
	local result = ""

	for i, v in ipairs({ ... }) do
		result ..= tostring(v)

		if i ~= #{ ... } then
			result ..= " "
		end
	end

	return result
end

local function createLogFunction(levelName: string, logFn: (...string) -> (), Color: Color3, PrintOutDev: boolean, ShowPath: boolean?)
	ShowPath = (ShowPath == nil) and true or ShowPath

	return function(...: any)
		if not DevOutputEnabled and not PrintOutDev then
			return
		end

		-- Get the full path of the module (Path.To.Module), and then take the
		-- final segment as the name (`[To][Module]`).
		local modulePath = debug.info(2, "s"):split(".")
		local moduleName = #modulePath == 0 and "" or `{modulePath[#modulePath - 1]}][{modulePath[#modulePath]}`
		local date = DateTime.now():ToLocalTime()

		if not ShowPath then
			moduleName = ""
		else
			moduleName = `[{moduleName}]`
		end

		local Hour = string.format("%02d", date.Hour)
		local Minute = string.format("%02d", date.Minute)
		local Second = string.format("%02d", date.Second)
		local Millisecond = string.format("%03d", date.Millisecond)

		local RichOpen = Rich
				and `<font color="rgb({math.floor(Color.R * 255)}, {math.floor(Color.G * 255)}, {math.floor(Color.B * 255)})"><font weight="SemiBold">`
			or ""
		local RichClose = Rich and "</font>" or ""
		local Time = Rich and `{Hour}:{Minute}:{Second}.{Millisecond}: ` or ""

		logFn(concatenate(`{Time}{RichOpen}{levelName}{moduleName}:{RichClose}`, ..., `{RichClose}`))
	end
end

local DebugColor = Color3.fromRGB(96, 190, 77)
local InfoColor = Color3.fromRGB(255, 255, 255)
local WarnColor = Color3.fromRGB(255, 148, 33)
local FatalColor = Color3.fromRGB(255, 85, 85)

local FatalFunction = function(...)
	warn(...) -- Warn so it makes it through to analytics
	Player:Kick(concatenate("Fatal error;\n", ..., "\nPlease report this immediately."))
end

--- @within Log
--- Log function prefixed with [DEBUG] that only passes through if DEV global is true
Log.debug = createLogFunction("[DEBUG]", print, DebugColor, false)
--- @within Log
--- Log function prefixed with [INFO]
Log.info = createLogFunction("[INFO]", print, InfoColor, true)
--- @within Log
--- Log function prefixed with [WARN]
Log.warn = createLogFunction("[WARN]", warn, WarnColor, true)
--- @within Log
--- Log function prefixed with [ERROR]
Log.error = createLogFunction("[ERROR]", error :: (string) -> (), FatalColor, true)
--- @within Log
--- Log function prefixed with [FATAL], also kicks the player
Log.fatal = createLogFunction("[FATAL]", FatalFunction, FatalColor, true)

return Log
