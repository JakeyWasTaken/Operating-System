-- !strict
const Class = require("@core/Class")
const ProcessScheduler = require("@kernel/Process/ProcessScheduler")

export type IOReader = {
    --- @param ChunkSize: number? - Defaults to 1KB
    ---
    --- @return Data: string? - Returns nil when the stream closes
    Read: (self: IOReader, ChunkSize: number?) -> string?,
}

export type IOWriter = {
    Write: (self: IOWriter, Data: string) -> (),
    Close: (self: IOWriter) -> (),
}

export type CIOStream = {

    new: () -> CIOStream,

    -- --------------------------------- Methods -------------------------------- --

    --- @return IOReader - A wrapped version of this stream which can only read
    SandboxReader: (self: CIOStream) -> IOReader,
    --- @return IOWriter - A wrapped version of this stream which can only write & close
    SandboxWriter: (self: CIOStream) -> IOWriter,

    --- @param ChunkSize: number? - Defaults to 1KB
    ---
    --- @return Data: string? - Returns nil when the stream closes
    Read: (self: CIOStream, ChunkSize: number?) -> string?,
    Write: (self: CIOStream, Data: string) -> (),

    --- Serves the same purpose as ::Destroy
    Close: (self: CIOStream) -> (),

    -- --------------------------------- Members -------------------------------- --

    m_Contents: string,

    m_SleepingKernelThreads: { number },
    m_SleepingThreads: { thread },

} & Class.Base

local ONE_KB = 1024

local CIOStream: CIOStream= Class("CIOStream") :: any

function CIOStream.new()
    local self: CIOStream = setmetatable({}, CIOStream) :: any
    (CIOStream :: any)(self)

    self.m_Contents = ""

    self.m_SleepingKernelThreads = {}
    self.m_SleepingThreads = {}

    return self
end

function CIOStream:SandboxReader()
    return {
        Read = function(_, ChunkSize)
            return self:Read(ChunkSize)
        end
    }
end

function CIOStream:SandboxWriter()
    return {
        Write = function(_, Data)
            return self:Write(Data)
        end,

        Close = function()
            self:Close()
        end
    }
end

function CIOStream:Read(ChunkSize: number)
    if self.m_Contents == "" then
        -- We need to handle this carefully so processes can interface with this
        local CurrentThreadId = ProcessScheduler.GetCurrentThreadId()
        if CurrentThreadId then
            table.insert(self.m_SleepingKernelThreads, CurrentThreadId)
            ProcessScheduler.Block(CurrentThreadId)
        else
            table.insert(self.m_SleepingThreads, coroutine.running())
            coroutine.yield()
        end
    end

    if self.m_Contents == "" then -- IO stream closed
        return nil
    end

    local Size = math.min(#self.m_Contents, (ChunkSize or ONE_KB))
    local Data = self.m_Contents:sub(1, Size)
    self.m_Contents = self.m_Contents:sub(Size + 1, #self.m_Contents)

    return Data
end

function CIOStream:Write(Data: string)
    self.m_Contents ..= Data

    for _, ThreadId in self.m_SleepingKernelThreads do
        ProcessScheduler.Unblock(ThreadId)
    end

    for _, Thread in self.m_SleepingThreads do
        coroutine.resume(Thread)
    end

    table.clear(self.m_SleepingKernelThreads)
    table.clear(self.m_SleepingThreads)
end

function CIOStream:Close()
    for _, ThreadId in self.m_SleepingKernelThreads do
        ProcessScheduler.Unblock(ThreadId)
    end

    for _, Thread in self.m_SleepingThreads do
        coroutine.resume(Thread)
    end

    table.clear(self.m_SleepingKernelThreads)
    table.clear(self.m_SleepingThreads)

    self:_Destroy()
end

return CIOStream
