const CWindow = require("@kernel/Window/Window")

type CWindow = CWindow.CWindow

local AllWindows: { [string]: CWindow } = {}
local FocusedWindowHandle = nil

local WindowFactory = {}

function WindowFactory.CreateWindow(): CWindow
    local Window = CWindow.new()
    AllWindows[Window:GetHandle()] = Window

    return Window
end

function WindowFactory.GetWindow(Handle: string): CWindow?
    return AllWindows[Handle]
end

function WindowFactory.GetAllWindows(): { [string]: CWindow }
    return AllWindows
end

-- Will un-focus currently focused window, and focus provided handle
function WindowFactory.FocusWindow(Handle: string)
    local PreviousWindow = FocusedWindowHandle and AllWindows[FocusedWindowHandle]
    if PreviousWindow then
        PreviousWindow:SetFocused(false)
    end

    local Window = AllWindows[Handle]
    if Window then
        Window:SetFocused(true)
    end

    FocusedWindowHandle = Handle
end

return WindowFactory
