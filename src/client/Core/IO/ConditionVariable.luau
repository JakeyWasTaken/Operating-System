--[[

    Thread blocker, blocks caller threads till another thread wakes them up with a value

]]

const Class = require("@core/Class")
const Log = require("@core/Log")
const ProcessScheduler = require("@kernel/Process/ProcessScheduler")

export type CConditionVariable<T...> = {
    -- --------------------------------- Methods -------------------------------- --

    --- Blocks the caller thread, returns value provided by ::Notify
    --- **DO NOT** call ::Wait() in a require thead
    ---
    --- e.g:
    --- ```
    --- require("./module")
    --- -- ./module:
    --- ConditionVariable:Wait() -- DO NOT DO, this will forever yield the requirer
    --- ```
    Wait: (self: CConditionVariable<T...>) -> T...,

    --- Awakes all blocked threads
    Notify: (self: CConditionVariable<T...>, T...) -> (),

    -- --------------------------------- Members -------------------------------- --

    m_BlockedKernelThreads: { number },
    m_BlockedThreads: { thread },
}

local CConditionVariable: CConditionVariable<...any> = Class("CConditionVariable")

function CConditionVariable:Wait()
    assert(ProcessScheduler.IsBlockingAllowed(), "ConditionVariable:Wait blocked inside a non-blocking context (e.g. a draw callback's root coroutine)")

    local CurrentThreadId = ProcessScheduler.GetCurrentThreadId()
    if CurrentThreadId then
        table.insert(self.m_BlockedKernelThreads, CurrentThreadId)
        return ProcessScheduler.Block(CurrentThreadId)
    else
        local Thread = coroutine.running()

        table.insert(self.m_BlockedThreads, Thread)
        return coroutine.yield()
    end
end

function CConditionVariable:Notify(...)
    local KernelThreads = self.m_BlockedKernelThreads
    local Threads = self.m_BlockedThreads

    self.m_BlockedKernelThreads = {}
    self.m_BlockedThreads = {}

    for _, KernelThread in KernelThreads do
        ProcessScheduler.Unblock(KernelThread, ...)
    end

    for _, Thread in Threads do
        local Ok, Err = coroutine.resume(Thread, ...)
        if not Ok then
            Log.warn(`ConditionVariable:Notify resumed thread errored: {Err}`)
        end
    end
end

return {
    new = function<T...>(): CConditionVariable<T...>
        local self: CConditionVariable<T...> = setmetatable({}, CConditionVariable) :: any
        (CConditionVariable :: any)(self)

        self.m_BlockedKernelThreads = {}
        self.m_BlockedThreads = {}

        return self
    end
}
