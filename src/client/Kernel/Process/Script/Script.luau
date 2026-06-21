--!strict

const Class = require("@core/Class")
const Handle = require("@core/Handle")
const VendorTypes = require("@vendor/VendorTypes")
const Result = require("@core/Result")
const Log = require("@core/Log")
const CPath = require("@kernel/File/Path")
const EnvironmentFactory = require("@kernel/Process/Script/EnvironmentFactory")
const Fiu = require("@vendor/Fiu") :: VendorTypes.Fiu
const LuauCeptionCompiler = require("@vendor/LuauCeptionCompiler") :: VendorTypes.LuauCeptionCompiler

type Result<T> = Result.Result<T>
type PID = number
type CPath = CPath.CPath
type Handle = Handle.Handle

type ScriptState = "Waiting" | "Running" | "Blocked"
export type CScript = {
    new: (Source: string, ScriptPath: CPath, ScriptHandle: Handle, PID: PID) -> CScript,

	-- --------------------------------- Methods -------------------------------- --

    IsCompiled: (self: CScript) -> boolean,
    Compile: (self: CScript, OptimizationLevel: number?, DebugLevel: number?) -> Result<unknown>,

    Run: (self: CScript) -> Result<any>,

	Destroy: (self: CScript) -> (),

	-- --------------------------------- Members -------------------------------- --

    ScriptHandle: Handle,
    ScriptPath: CPath,
    OwnerPID: PID,

    m_Source: string,
    m_Bytecode: string?,
    m_Returns: any?,

    m_CloseHook: () -> (),

} & Class.Base

local CScript: CScript = Class("CScript") :: any

function CScript.new(Source: string, ScriptPath: CPath, ScriptHandle: Handle, OwnerPID: PID)
    local self: CScript = setmetatable({}, CScript) :: any
    (CScript :: any)(self)

    self.ScriptHandle = ScriptHandle
    self.ScriptPath = ScriptPath
    self.OwnerPID = OwnerPID

    self.m_Source = Source
    self.m_Bytecode = nil
    self.m_Returns = nil

    return self
end

function CScript:IsCompiled()
    return self.m_Bytecode ~= nil
end

function CScript:Compile(OptimizationLevel: number?, DebugLevel: number?)
    if self.m_Bytecode then
        return Result.new(false, "Already compiled")
    end

    local Success, Error = pcall(function()
        Log.debug(`Compiling script source`)

        local Bytecode, Size = LuauCeptionCompiler.luau_compile(self.m_Source, OptimizationLevel, DebugLevel)
        self.m_Bytecode = Bytecode

        Log.debug(`Compiled script size {Size}B`)

        return ""
    end)

    if not Success then
        Log.warn(`Failed to compile script\n\n{Error}`)
    end

    return Result.new(Success, Error)
end

function CScript:Run()
    if not self.m_Bytecode then
        return Result.new(false, "Script not compiled", nil)
    end

    if self.m_Returns then
        return Result.new(true, "", self.m_Returns)
    end

    do
        local luau_settings = Fiu.luau_newsettings()
        luau_settings.errorHandling = false
        luau_settings.allowProxyErrors = true
        luau_settings.vectorCtor = vector.create :: any

        local Run, Close = Fiu.luau_load(self.m_Bytecode, EnvironmentFactory.CreateEnvironment(self.OwnerPID, self.ScriptPath) :: any, luau_settings)
        self.m_CloseHook = Close

        local Returns = {}
        local Success, Error = pcall(function()
            Returns = { Run() }
            return ""
        end)

        if not Success then
            return Result.new(false, Error)
        end

        if #Returns ~= 1 then
            return Result.new(false, `Module did not return exactly one value.`)
        end

        self.m_Returns = Returns[1]
    end

    return Result.new(true, "", self.m_Returns)
end

function CScript:Destroy()
    if self.m_CloseHook then
        self.m_CloseHook()
    end

    self._Destroy()
end

return CScript
