const Class = require("@core/Class")
const Handle = require("@core/Handle")
const JDI = require("@vendor/JustDrawIt")

const Camera = workspace.CurrentCamera

type VNode = JDI.VNode

export type CWindow = {
	new: () -> CWindow,

    -- --------------------------------- Methods -------------------------------- --

    GetHandle: (self: CWindow) -> string,

    SetFocused: (self: CWindow, Focused: boolean) -> (),
    IsFocused: (self: CWindow) -> boolean,

    SetMinimized: (self: CWindow, Minimized: boolean) -> (),
    IsMinimized: (self: CWindow) -> boolean,

    SetFullscreen: (self: CWindow, Fullscreen: boolean) -> (),
    IsFullscreen: (self: CWindow) -> boolean,

    GetSize: (self: CWindow) -> Vector2,
    GetPosition: (self: CWindow) -> Vector2,

    --- The draw callback **MUST NOT** yield
    SetDrawCallback: (self: CWindow, Callback: () -> VNode) -> (),
    GetDrawCallback: (self: CWindow) -> ( () -> VNode ),

    BringToTop: (self: CWindow) -> (),
    GetZIndex: (self: CWindow) -> number,

    Destroy: (self: CWindow) -> (),

    -- --------------------------------- Members -------------------------------- --

    m_Handle: string,

    m_Focused: boolean,
    m_Minimized: boolean,
    m_Fullscreen: boolean,
    m_ZIndex: number,

    m_DrawCallback: () -> ()?,
} & Class.Base

local LastHighestZIndex = 0

local CWindow: CWindow = Class("CWindow") :: any

function CWindow.new()
	local self: CWindow = setmetatable({}, CWindow) :: any
	(CWindow :: any)(self)

    self.m_Handle = Handle()

    self.m_Focused = false
    self.m_Minimized = false
    self.m_Fullscreen = false
    self.m_ZIndex = 0

    self.m_DrawCallback = nil

	return self
end

function CWindow:GetHandle()
    return self.m_Handle
end

function CWindow:SetFocused(Focused: boolean)
    self.m_Focused = Focused
end

function CWindow:IsFocused()
    return self.m_Focused
end

function CWindow:SetMinimized(Minimized: boolean)
    self.m_Minimized = Minimized
end

function CWindow:IsMinimized()
    return self.m_Minimized
end

function CWindow:SetFullscreen(Fullscreen: boolean)
    self.m_Fullscreen = Fullscreen
end

function CWindow:IsFullscreen()
    return self.m_Fullscreen
end

function CWindow:GetSize()
    if self.m_Fullscreen then
        return Camera.ViewportSize
    end

    return Vector2.zero
end

function CWindow:GetPosition()
    if self.m_Fullscreen then
        return Vector2.zero
    end

    return Vector2.zero
end

function CWindow:SetDrawCallback(Callback: () -> VNode)
    self.m_DrawCallback = Callback
end

function CWindow:GetDrawCallback()
    return self.m_DrawCallback
end

function CWindow:BringToTop()
    LastHighestZIndex += 1
    self.m_ZIndex = LastHighestZIndex
end

function CWindow:GetZIndex()
    return self.m_ZIndex
end

function CWindow:Destroy()
    self._Destroy()
end

return CWindow
