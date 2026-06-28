--[[

    LibWindow / window

    Userspace window library. Lets a process open windows, draw to them each
    frame and read input directed at them.

    Every method takes the scoped handle returned by Create and returns its
    result plus an error string - the result is nil (and the string non-empty)
    on failure.

]]

const WindowFactory = require("@kernel/Window/WindowFactory")
const JDI = require("@vendor/JustDrawIt")
const Signal = require("@core/Signal")

const UserInputService = game:GetService("UserInputService")

type Signal<T...> = Signal.Signal<T...>

--- Per-window input. Signals only fire, and the queries only report input,
--- while the window is focused.
type InputContext = {
    -- Signals
    InputBegan: Signal<InputObject, boolean>,
    InputChanged: Signal<InputObject, boolean>,
    InputEnded: Signal<InputObject, boolean>,

    LastInputTypeChanged: Signal<Enum.UserInputType>,

    WindowFocused: Signal<>,
    WindowFocusReleased: Signal<>,

    -- Methods
    GetStringForKeyCode: (KeyCode: Enum.KeyCode, Format: Enum.KeyCodeStringFormat) -> string,
    GetImageForKeyCode: (KeyCode: Enum.KeyCode) -> string,
    GetLastInputType: () -> Enum.UserInputType,

    --- This can return numbers outside of the windows bounds
    GetMouseLocation: () -> Vector2,
    GetMouseButtonsPressed: () -> { InputObject },

    GetSupportedGamepadKeyCodes: (GamepadNum: Enum.UserInputType) -> { Enum.KeyCode },
    GetGamepadState: (GamepadNum: Enum.UserInputType) -> { InputObject },
    GetGamepadConnected: (GamepadNum: Enum.UserInputType) -> boolean,
    GetConnectedGamePads: () -> { Enum.UserInputType },

    GetKeysPressed: () -> { InputObject },

    IsGamepadButtonDown: (GamepadNum: Enum.UserInputType, GamepadKeyCode: Enum.KeyCode) -> boolean,
    IsKeyDown: (KeyCode: Enum.KeyCode) -> boolean,
    IsMouseButtonPressed: (MouseButton: Enum.UserInputType) -> boolean,
}

return {
    Name = "window",
    Enabled = true,
    MakeLibrary = function(LibraryPID: number)
        return {
            --- Element constructor for use inside draw callbacks, e.g.
            --- Graphics.Create("Frame")({ ... }). Mirrors the JustDrawIt API.
            Graphics = {
                Create = JDI.create
            },

            --- Opens a new window owned by the calling process. Returns its scoped handle.
            Create = function(): (string?, string)
                if not shared.ProcessFactory then
                    return nil, "ProcessFactory was not ready"
                end

                local Process = shared.ProcessFactory.GetProcess(LibraryPID)
                if not Process then
                    return nil, `PID {LibraryPID} did not have a process attributed`
                end

                local Window = WindowFactory.CreateWindow(LibraryPID)
                local ScopedHandle = Process:CreateScopedHandle(Window:GetHandle())

                return ScopedHandle, ""
            end,

            --- Closes the window and releases its handle.
            Destroy = function(ScopedHandle: string): (boolean?, string)
                if typeof(ScopedHandle) ~= "string" then
                    return nil, "Expected ScopedHandle to be of type string"
                end

                if not shared.ProcessFactory then
                    return nil, "ProcessFactory was not ready"
                end

                local Process = shared.ProcessFactory.GetProcess(LibraryPID)
                if not Process then
                    return nil, `PID {LibraryPID} did not have a process attributed`
                end

                local GlobalHandle = Process:GetGlobalHandle(ScopedHandle)
                if not GlobalHandle then
                    return nil, "ScopedHandle does not refer to an open window"
                end

                if not WindowFactory.GetWindow(GlobalHandle) then
                    return nil, "ScopedHandle's window no longer exists"
                end

                WindowFactory.DestroyWindow(GlobalHandle)
                Process:RemoveScopedHandle(ScopedHandle)

                return true, ""
            end,

            --- Sets the function called each frame to draw the window's contents. It
            --- must return a VNode (see Graphics.Create) and **MUST NOT** yield.
            --- Pass nil to clear it.
            SetDrawCallback = function(ScopedHandle: string, Callback: (() -> unknown)?): (boolean?, string)
                if typeof(ScopedHandle) ~= "string" then
                    return nil, "Expected ScopedHandle to be of type string"
                end

                if Callback ~= nil and typeof(Callback) ~= "function" then
                    return nil, "Expected Callback to be a function or nil"
                end

                if not shared.ProcessFactory then
                    return nil, "ProcessFactory was not ready"
                end

                local Process = shared.ProcessFactory.GetProcess(LibraryPID)
                if not Process then
                    return nil, `PID {LibraryPID} did not have a process attributed`
                end

                local GlobalHandle = Process:GetGlobalHandle(ScopedHandle)
                if not GlobalHandle then
                    return nil, "ScopedHandle does not refer to an open window"
                end

                local Window = WindowFactory.GetWindow(GlobalHandle)
                if not Window then
                    return nil, "ScopedHandle's window no longer exists"
                end

                Window:SetDrawCallback(Callback)

                return true, ""
            end,

            --- Focuses the window (un-focusing any other), or un-focuses it when
            --- Focused is false. Only a focused window receives input.
            SetFocused = function(ScopedHandle: string, Focused: boolean): (boolean?, string)
                if typeof(ScopedHandle) ~= "string" then
                    return nil, "Expected ScopedHandle to be of type string"
                end

                if typeof(Focused) ~= "boolean" then
                    return nil, "Expected Focused to be of type boolean"
                end

                if not shared.ProcessFactory then
                    return nil, "ProcessFactory was not ready"
                end

                local Process = shared.ProcessFactory.GetProcess(LibraryPID)
                if not Process then
                    return nil, `PID {LibraryPID} did not have a process attributed`
                end

                local GlobalHandle = Process:GetGlobalHandle(ScopedHandle)
                if not GlobalHandle then
                    return nil, "ScopedHandle does not refer to an open window"
                end

                WindowFactory.SetFocused(GlobalHandle, Focused)

                return true, ""
            end,

            --- Returns whether the window is currently focused.
            IsFocused = function(ScopedHandle: string): (boolean?, string)
                if typeof(ScopedHandle) ~= "string" then
                    return nil, "Expected ScopedHandle to be of type string"
                end

                if not shared.ProcessFactory then
                    return nil, "ProcessFactory was not ready"
                end

                local Process = shared.ProcessFactory.GetProcess(LibraryPID)
                if not Process then
                    return nil, `PID {LibraryPID} did not have a process attributed`
                end

                local GlobalHandle = Process:GetGlobalHandle(ScopedHandle)
                if not GlobalHandle then
                    return nil, "ScopedHandle does not refer to an open window"
                end

                local Window = WindowFactory.GetWindow(GlobalHandle)
                if not Window then
                    return nil, "ScopedHandle's window no longer exists"
                end

                return Window:IsFocused(), ""
            end,

            --- Minimizes the window, or restores it when Minimized is false.
            SetMinimized = function(ScopedHandle: string, Minimized: boolean): (boolean?, string)
                if typeof(ScopedHandle) ~= "string" then
                    return nil, "Expected ScopedHandle to be of type string"
                end

                if typeof(Minimized) ~= "boolean" then
                    return nil, "Expected Minimized to be of type boolean"
                end

                if not shared.ProcessFactory then
                    return nil, "ProcessFactory was not ready"
                end

                local Process = shared.ProcessFactory.GetProcess(LibraryPID)
                if not Process then
                    return nil, `PID {LibraryPID} did not have a process attributed`
                end

                local GlobalHandle = Process:GetGlobalHandle(ScopedHandle)
                if not GlobalHandle then
                    return nil, "ScopedHandle does not refer to an open window"
                end

                local Window = WindowFactory.GetWindow(GlobalHandle)
                if not Window then
                    return nil, "ScopedHandle's window no longer exists"
                end

                Window:SetMinimized(Minimized)

                return true, ""
            end,

            --- Returns whether the window is currently minimized.
            IsMinimized = function(ScopedHandle: string): (boolean?, string)
                if typeof(ScopedHandle) ~= "string" then
                    return nil, "Expected ScopedHandle to be of type string"
                end

                if not shared.ProcessFactory then
                    return nil, "ProcessFactory was not ready"
                end

                local Process = shared.ProcessFactory.GetProcess(LibraryPID)
                if not Process then
                    return nil, `PID {LibraryPID} did not have a process attributed`
                end

                local GlobalHandle = Process:GetGlobalHandle(ScopedHandle)
                if not GlobalHandle then
                    return nil, "ScopedHandle does not refer to an open window"
                end

                local Window = WindowFactory.GetWindow(GlobalHandle)
                if not Window then
                    return nil, "ScopedHandle's window no longer exists"
                end

                return Window:IsMinimized(), ""
            end,

            --- Makes the window fullscreen, or windowed when Fullscreen is false.
            SetFullscreen = function(ScopedHandle: string, Fullscreen: boolean): (boolean?, string)
                if typeof(ScopedHandle) ~= "string" then
                    return nil, "Expected ScopedHandle to be of type string"
                end

                if typeof(Fullscreen) ~= "boolean" then
                    return nil, "Expected Fullscreen to be of type boolean"
                end

                if not shared.ProcessFactory then
                    return nil, "ProcessFactory was not ready"
                end

                local Process = shared.ProcessFactory.GetProcess(LibraryPID)
                if not Process then
                    return nil, `PID {LibraryPID} did not have a process attributed`
                end

                local GlobalHandle = Process:GetGlobalHandle(ScopedHandle)
                if not GlobalHandle then
                    return nil, "ScopedHandle does not refer to an open window"
                end

                local Window = WindowFactory.GetWindow(GlobalHandle)
                if not Window then
                    return nil, "ScopedHandle's window no longer exists"
                end

                Window:SetFullscreen(Fullscreen)

                return true, ""
            end,

            --- Returns whether the window is currently fullscreen.
            IsFullscreen = function(ScopedHandle: string): (boolean?, string)
                if typeof(ScopedHandle) ~= "string" then
                    return nil, "Expected ScopedHandle to be of type string"
                end

                if not shared.ProcessFactory then
                    return nil, "ProcessFactory was not ready"
                end

                local Process = shared.ProcessFactory.GetProcess(LibraryPID)
                if not Process then
                    return nil, `PID {LibraryPID} did not have a process attributed`
                end

                local GlobalHandle = Process:GetGlobalHandle(ScopedHandle)
                if not GlobalHandle then
                    return nil, "ScopedHandle does not refer to an open window"
                end

                local Window = WindowFactory.GetWindow(GlobalHandle)
                if not Window then
                    return nil, "ScopedHandle's window no longer exists"
                end

                return Window:IsFullscreen(), ""
            end,

            --- Returns the window's size in pixels.
            GetSize = function(ScopedHandle: string): (Vector2?, string)
                if typeof(ScopedHandle) ~= "string" then
                    return nil, "Expected ScopedHandle to be of type string"
                end

                if not shared.ProcessFactory then
                    return nil, "ProcessFactory was not ready"
                end

                local Process = shared.ProcessFactory.GetProcess(LibraryPID)
                if not Process then
                    return nil, `PID {LibraryPID} did not have a process attributed`
                end

                local GlobalHandle = Process:GetGlobalHandle(ScopedHandle)
                if not GlobalHandle then
                    return nil, "ScopedHandle does not refer to an open window"
                end

                local Window = WindowFactory.GetWindow(GlobalHandle)
                if not Window then
                    return nil, "ScopedHandle's window no longer exists"
                end

                return Window:GetSize(), ""
            end,

            --- Returns the window's top-left position in pixels.
            GetPosition = function(ScopedHandle: string): (Vector2?, string)
                if typeof(ScopedHandle) ~= "string" then
                    return nil, "Expected ScopedHandle to be of type string"
                end

                if not shared.ProcessFactory then
                    return nil, "ProcessFactory was not ready"
                end

                local Process = shared.ProcessFactory.GetProcess(LibraryPID)
                if not Process then
                    return nil, `PID {LibraryPID} did not have a process attributed`
                end

                local GlobalHandle = Process:GetGlobalHandle(ScopedHandle)
                if not GlobalHandle then
                    return nil, "ScopedHandle does not refer to an open window"
                end

                local Window = WindowFactory.GetWindow(GlobalHandle)
                if not Window then
                    return nil, "ScopedHandle's window no longer exists"
                end

                return Window:GetPosition(), ""
            end,

            --- Raises the window above all others.
            BringToTop = function(ScopedHandle: string): (boolean?, string)
                if typeof(ScopedHandle) ~= "string" then
                    return nil, "Expected ScopedHandle to be of type string"
                end

                if not shared.ProcessFactory then
                    return nil, "ProcessFactory was not ready"
                end

                local Process = shared.ProcessFactory.GetProcess(LibraryPID)
                if not Process then
                    return nil, `PID {LibraryPID} did not have a process attributed`
                end

                local GlobalHandle = Process:GetGlobalHandle(ScopedHandle)
                if not GlobalHandle then
                    return nil, "ScopedHandle does not refer to an open window"
                end

                local Window = WindowFactory.GetWindow(GlobalHandle)
                if not Window then
                    return nil, "ScopedHandle's window no longer exists"
                end

                Window:BringToTop()

                return true, ""
            end,

            --- Returns the window's input context: signals and queries for keyboard,
            --- mouse and gamepad input scoped to this window (see InputContext).
            GetInputContext = function(ScopedHandle: string): (InputContext?, string)
                if typeof(ScopedHandle) ~= "string" then
                    return nil, "Expected ScopedHandle to be of type string"
                end

                if not shared.ProcessFactory then
                    return nil, "ProcessFactory was not ready"
                end

                local Process = shared.ProcessFactory.GetProcess(LibraryPID)
                if not Process then
                    return nil, `PID {LibraryPID} did not have a process attributed`
                end

                local GlobalHandle = Process:GetGlobalHandle(ScopedHandle)
                if not GlobalHandle then
                    return nil, "ScopedHandle does not refer to an open window"
                end

                local Window = WindowFactory.GetWindow(GlobalHandle)
                if not Window then
                    return nil, "ScopedHandle's window no longer exists"
                end

                return {
                    InputBegan = Window.InputContext.InputBegan,
                    InputChanged = Window.InputContext.InputChanged,
                    InputEnded = Window.InputContext.InputEnded,

                    LastInputTypeChanged = Window.InputContext.LastInputTypeChanged,

                    WindowFocused = Window.InputContext.WindowFocused,
                    WindowFocusReleased = Window.InputContext.WindowFocusReleased,

                    GetStringForKeyCode = function(...) return UserInputService:GetStringForKeyCode(...) end,
                    GetImageForKeyCode = function(...) return UserInputService:GetImageForKeyCode(...) end,
                    GetLastInputType = function(...) return UserInputService:GetLastInputType(...) end,

                    GetMouseLocation = function() return Window:GetMouseLocation() end,
                    GetMouseButtonsPressed = function() return Window:GetMouseButtonsPressed() end,

                    GetSupportedGamepadKeyCodes = function(...) return UserInputService:GetSupportedGamepadKeyCodes(...) end,
                    GetGamepadState = function(...) return UserInputService:GetGamepadState(...) end,
                    GetGamepadConnected = function(...) return UserInputService:GetGamepadConnected(...) end,
                    GetConnectedGamePads = function(...) return UserInputService:GetConnectedGamePads(...) end,

                    GetKeysPressed = function() return Window:GetKeysPressed() end,

                    IsGamepadButtonDown = function(...) return Window:IsGamepadButtonDown(...) end,
                    IsKeyDown = function(...) return Window:IsKeyDown(...) end,
                    IsMouseButtonPressed = function(...) return Window:IsMouseButtonPressed(...) end,
                }, ""
            end
        }
    end,
}
