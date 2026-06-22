--[[

    Thread blocker, blocks caller threads till another thread wakes them up with a value

]]

const Class = require("@core/Class")
const ProcessScheduler = require("@kernel/Process/ProcessScheduler")

export type CConditionVariable<T...> = {
    -- --------------------------------- Methods -------------------------------- --

    --- Blocks the caller thread, returns value provided by ::Notify
    Wait: (self: CConditionVariable<T...>) -> T...,

    --- Awakes all blocked threads
    Notify: (self: CConditionVariable<T...>, T...) -> (),

    -- --------------------------------- Members -------------------------------- --

    m_BlockedKernelThreads: { number },
    m_BlockedThreads: { thread },
}

local CConditionVariable: CConditionVariable<...any> = Class("CConditionVariable")

function CConditionVariable:Wait()
    local CurrentThreadId = ProcessScheduler.GetCurrentThreadId()
    if CurrentThreadId then
        table.insert(self.m_BlockedKernelThreads, CurrentThreadId)
        return ProcessScheduler.Block(CurrentThreadId)
    else
        table.insert(self.m_BlockedThreads, coroutine.running())
        return coroutine.yield()
    end
end

function CConditionVariable:Notify(...)
    for _, KernelThread in self.m_BlockedKernelThreads do
        ProcessScheduler.Unblock(KernelThread, ...)
    end

    for _, Thread in self.m_BlockedThreads do
        coroutine.resume(Thread, ...)
    end

    table.clear(self.m_BlockedKernelThreads)
    table.clear(self.m_BlockedThreads)
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
