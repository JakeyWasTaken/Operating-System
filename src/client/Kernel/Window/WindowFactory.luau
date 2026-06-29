const CWindow = require("@kernel/Window/Window")

type CWindow = CWindow.CWindow

local AllWindows: { [string]: CWindow } = {}
local FocusedWindowHandle = nil

local WindowFactory = {}

function WindowFactory.CreateWindow(OwnerPid: number): CWindow
    local Window = CWindow.new(OwnerPid)
    AllWindows[Window:GetHandle()] = Window

    Window:BringToTop()
    WindowFactory.SetFocused(Window:GetHandle(), true)

    return Window
end

function WindowFactory.GetWindow(Handle: string): CWindow?
    return AllWindows[Handle]
end

function WindowFactory.GetAllWindows(): { [string]: CWindow }
    return AllWindows
end

function WindowFactory.DestroyWindow(Handle: string)
    local Window = AllWindows[Handle]
    if not Window then
        return
    end

    if FocusedWindowHandle == Handle then
        FocusedWindowHandle = nil
    end

    AllWindows[Handle] = nil
    Window:Destroy()
end

-- Focuses the provided window, un-focusing whatever was focused before. Passing
-- Focused = false un-focuses the window, but only if it was the focused one.
function WindowFactory.SetFocused(Handle: string, Focused: boolean)
    local Window = AllWindows[Handle]
    if not Window then
        return
    end

    if Focused then
        if FocusedWindowHandle == Handle then
            return
        end

        local PreviousWindow = FocusedWindowHandle and AllWindows[FocusedWindowHandle]
        if PreviousWindow then
            PreviousWindow:SetFocused(false)
            PreviousWindow.InputContext.WindowFocusReleased:Fire()
        end

        Window:SetFocused(true)
        Window.InputContext.WindowFocused:Fire()
        FocusedWindowHandle = Handle
    else
        if FocusedWindowHandle ~= Handle then
            return
        end

        Window:SetFocused(false)
        Window.InputContext.WindowFocusReleased:Fire()
        FocusedWindowHandle = nil
    end
end

--- Called upon process termination, destroys every window it owned
function WindowFactory.OnProcessTerminated(PID: number)
    for Handle, Window in AllWindows do
        if Window:GetOwnerPID() == PID then
            WindowFactory.DestroyWindow(Handle)
        end
    end
end

return WindowFactory
