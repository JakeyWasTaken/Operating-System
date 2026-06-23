--!strict

const Handle = require("@core/Handle")
const CScript = require("./Script")
const CPath = require("@kernel/File/Path")

type PID = number
type CPath = CPath.CPath
type Handle = Handle.Handle

local Cache: { [PID]: { [Handle]: any } } = {}

local ScriptFactory = {}
shared.ScriptFactory = ScriptFactory

-- TODO: look at script handle here, probably give new name? & a unique id / handle per script could be useful

--- This will check the process cache for the script handle and return that if it already exists
--- or will create the script if it is not in cache.
--- @param Source - Executable script contents
--- @param ScriptPath - The path this script should run in, this is different from the working directory. This is separate so that relative requires can work across different processes.
--- @param ScriptHandle - A handle for this script, it will not be unique globally, but it will be unique for this process
--- @param OwnerPID - The process id that owns this script
---
--- @return `CScript`
function ScriptFactory.CreateScript(Source: string, ScriptPath: CPath, ScriptHandle: Handle, OwnerPID: number): CScript.CScript
    if Cache[OwnerPID] and Cache[OwnerPID][ScriptHandle] then
        return Cache[OwnerPID][ScriptHandle]
    end

    Cache[OwnerPID] = Cache[OwnerPID] or {}

    local Script = CScript.new(Source, ScriptPath, ScriptHandle, OwnerPID)
    Cache[OwnerPID][ScriptHandle] = Script

    return Script
end

--- Called upon process termination, flushes that processes script cache
function ScriptFactory.OnProcessTermination(PID: number)
    if not Cache[PID] then
        return
    end

    for _, Script in Cache[PID] do
        Script:Destroy()
    end

    Cache[PID] = nil
end

return ScriptFactory
