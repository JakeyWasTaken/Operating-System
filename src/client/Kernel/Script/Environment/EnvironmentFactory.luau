const EnvironmentContext = require("./EnvironmentContext")

const InterfaceCoroutine = require("./Interfaces/Coroutine")
const InterfaceTask = require("./Interfaces/Task")
const InterfaceRequire = require("./Interfaces/Require")
const InterfaceStdio = require("./Interfaces/Stdio")
const InterfaceProcess = require("./Interfaces/Process")

type EnvironmentContext = EnvironmentContext.EnvironmentContext

-- stylua: ignore
local GetSharedTable: (PID: number) -> {[any]: any?}, ReleaseSharedTable: (PID: number) -> () do
    local SharedTables: {[number]: {[any]: any?}} = {}

    function GetSharedTable(PID: number)
        local SharedTable = SharedTables[PID]
        SharedTables[PID] = SharedTable or {}

        return SharedTable
    end

    function ReleaseSharedTable(PID: number)
        SharedTables[PID] = nil
    end
end

local EnvironmentFactory = {}

function EnvironmentFactory.CreateEnvironment(Context: EnvironmentContext)
    local PID = Context.PID
    local SharedTable = GetSharedTable(PID)

    const Coroutine = InterfaceCoroutine(Context)
    const Task = InterfaceTask(Context)
    const Require = InterfaceRequire(Context)
    const Stdio = InterfaceStdio(Context)
    const Process = InterfaceProcess(Context)

    local Environment = {
        -- --------------------------- Custom Environment --------------------------- --
        print = Stdio.Print,
        warn = Stdio.Warn, -- Should we really have this? It's behaviour is on-par with print
        error = Stdio.Error,

        coroutine = {
            create = Coroutine.Create,
            resume = Coroutine.Resume,
            status = Coroutine.Status,
            wrap = Coroutine.Wrap,
            close = Coroutine.Close,
            running = Coroutine.Running,
            -- These are just the builtin calls since our scheduler handles the states fine
            yield = coroutine.yield,
            isyieldable = coroutine.isyieldable,
        },

        task = {
			wait = Task.Wait,
			spawn = Task.Spawn,
			defer = Task.Defer,
			delay = Task.Delay,
			cancel = Task.Cancel,
		},

        wait = Task.Wait,
		spawn = Task.Spawn,

		getfenv = function() error("getfenv is not enabled") end,
		setfenv = function() error("setfenv is not enabled") end,
        loadstring = function() error("loadstring is not enabled") end,

        type = Process.Type,
		typeof = Process.TypeOf,

        exit = Process.Exit,
        require = Require,

        _G = SharedTable,
        shared = SharedTable,
        _VERSION = "Osiris",

        -- --------------------------- Normal Environment --------------------------- --

        string = string,
		bit32 = bit32,
		utf8 = utf8,
		os = os,
		debug = debug,
		buffer = buffer,
		vector = vector,
		math = math,
		table = table,

		DateTime = DateTime,
        -- We provide vectors & cframe just for ease of use
        -- vector = vector -- This is handled by Fiu with the vectorCtor
		Vector3 = Vector3,
        Vector3int16 = Vector3int16,
        Vector2 = Vector2,
        Vector2int16 = Vector2int16,
		CFrame = CFrame,

        -- GUI datatypes, for the window library's draw callbacks
        Enum = Enum,
        UDim = UDim,
        UDim2 = UDim2,
        Rect = Rect,
        Color3 = Color3,
        BrickColor = BrickColor,
        Font = Font,
        ColorSequence = ColorSequence,
        ColorSequenceKeypoint = ColorSequenceKeypoint,
        NumberSequence = NumberSequence,
        NumberSequenceKeypoint = NumberSequenceKeypoint,
        NumberRange = NumberRange,

		tick = tick,
		time = time,
		elapsedTime = elapsedTime,

		assert = assert,
		gcinfo = gcinfo,
		getmetatable = getmetatable,
		ipairs = ipairs,
		newproxy = newproxy,
		next = next,
		pairs = pairs,
		pcall = pcall,
		rawequal = rawequal,
		rawget = rawget,
		rawlen = rawlen,
		rawset = rawset,
		select = select,
		setmetatable = setmetatable,
		tonumber = tonumber,
		tostring = tostring,
		unpack = unpack,
		xpcall = xpcall,
    }

    return Environment
end

function EnvironmentFactory.OnProcessTerminated(PID: number)
    ReleaseSharedTable(PID)
end

return EnvironmentFactory
