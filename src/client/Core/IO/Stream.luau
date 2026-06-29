-- !strict
const Class = require("@core/Class")
const CConditionVariable = require("@core/IO/ConditionVariable")

type CConditionVariable<T...> = CConditionVariable.CConditionVariable<T...>

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
    m_ConditionVariable: CConditionVariable<>,

} & Class.Base

local ONE_KB = 1024

local CIOStream: CIOStream= Class("CIOStream") :: any

function CIOStream.new()
    local self: CIOStream = setmetatable({}, CIOStream) :: any
    (CIOStream :: any)(self)

    self.m_Contents = ""
    self.m_ConditionVariable = CConditionVariable.new()

    return self
end

function CIOStream:SandboxReader()
    return {
        Read = function(_, ChunkSize)
            if Class.IsDestroyed(self) then
                return nil
            end

            return self:Read(ChunkSize)
        end
    }
end

function CIOStream:SandboxWriter()
    return {
        Write = function(_, Data)
            if Class.IsDestroyed(self) then
                return nil
            end

            return self:Write(Data)
        end,

        Close = function()
            if Class.IsDestroyed(self) then
                return
            end

            self:Close()
        end
    }
end

function CIOStream:Read(ChunkSize: number)
    if self.m_Contents == "" then
        self.m_ConditionVariable:Wait()
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
    self.m_ConditionVariable:Notify()
end

function CIOStream:Close()
    self.m_ConditionVariable:Notify()

    self:_Destroy()
end

return CIOStream
