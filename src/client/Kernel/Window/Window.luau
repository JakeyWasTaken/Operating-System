const Class = require("@core/Class")
const Handle = require("@core/Handle")
const JDI = require("@vendor/JustDrawIt")
const Signal = require("@core/Signal")

const Camera = workspace.CurrentCamera
const UserInputService = game:GetService("UserInputService")

type VNode = JDI.VNode
type Signal<T...> = Signal.Signal<T...>

export type CWindow = {
	new: () -> CWindow,

    -- --------------------------------- Methods -------------------------------- --

    GetHandle: (self: CWindow) -> string,
    GetOwnerPID: (self: CWindow) -> number,

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

    -- ------------------------------ Input Methods ----------------------------- --

    DigestInput: (self: CWindow, State: Enum.UserInputState, Input: InputObject, GameProcessed: boolean) -> (),
    DigestLastInputType: (self: CWindow, LastInputType: Enum.UserInputType) -> (),

    GetMouseLocation: (self: CWindow) -> Vector2,
    GetMouseButtonsPressed: (self: CWindow) -> { InputObject },

    GetKeysPressed: (self: CWindow) -> { InputObject },

    IsGamepadButtonDown: (self: InputContext, GamepadNum: Enum.UserInputType, GamepadKeyCode: Enum.KeyCode) -> boolean,
    IsKeyDown: (self: InputContext, KeyCode: Enum.KeyCode) -> boolean,
    IsMouseButtonPressed: (self: InputContext, MouseButton: Enum.UserInputType) -> boolean,

    Destroy: (self: CWindow) -> (),

    -- --------------------------------- Members -------------------------------- --

    m_Handle: string,
    m_OwnerPID: number,

    m_Focused: boolean,
    m_Minimized: boolean,
    m_Fullscreen: boolean,
    m_ZIndex: number,

    InputContext: {
        InputBegan: Signal<InputObject, true>,
        InputChanged: Signal<InputObject, true>,
        InputEnded: Signal<InputObject, true>,

        LastInputTypeChanged: Signal<Enum.UserInputType>,

        WindowFocused: Signal<>,
        WindowFocusReleased: Signal<>,

        --- Used to call fire InputEnded when we lose focus
        ActiveInputs: { [InputObject]: boolean },
    },

    m_DrawCallback: () -> ()?,
} & Class.Base

local LastHighestZIndex = 0

local CWindow: CWindow = Class("CWindow") :: any

function CWindow.new(OwnerPID: number)
	local self: CWindow = setmetatable({}, CWindow) :: any
	(CWindow :: any)(self)

    self.m_Handle = Handle()
    self.m_OwnerPID = OwnerPID

    self.m_Focused = false
    self.m_Minimized = false
    self.m_Fullscreen = false
    self.m_ZIndex = 0

    self.InputContext = {
        InputBegan = Signal.new(),
        InputChanged = Signal.new(),
        InputEnded = Signal.new(),

        LastInputTypeChanged = Signal.new(),

        WindowFocused = Signal.new(),
        WindowFocusReleased = Signal.new(),

        ActiveInputs = {}
    }

    self.m_DrawCallback = nil

    self.InputContext.WindowFocusReleased:Connect(function()
        for Input, GameProcessed in self.InputContext.ActiveInputs do
            self.InputContext.InputEnded:Fire(Input, GameProcessed)
        end

        table.clear(self.InputContext.ActiveInputs)
    end)

	return self
end

function CWindow:GetHandle()
    return self.m_Handle
end

function CWindow:GetOwnerPID()
    return self.m_OwnerPID
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

function CWindow:DigestInput(State: Enum.UserInputState, Input: InputObject, GameProcessed: boolean)
    if not self.m_Focused then
        return
    end

    if State == Enum.UserInputState.Begin then
        self.InputContext.ActiveInputs[Input] = GameProcessed
        self.InputContext.InputBegan:Fire(Input, GameProcessed)

        return
    elseif State == Enum.UserInputState.Change then
        self.InputContext.InputChanged:Fire(Input, GameProcessed)

        return
    elseif State == Enum.UserInputState.End then
        self.InputContext.InputEnded:Fire(Input, GameProcessed)
        self.InputContext.ActiveInputs[Input] = nil

        return
    end

    warn(`Failed to digest input state "{State.Name}"`)
end

function CWindow:DigestLastInputType(LastInputType: Enum.UserInputType)
    if not self.m_Focused then
        return
    end

    self.InputContext.LastInputTypeChanged:Fire(LastInputType)
end

function CWindow:GetMouseLocation()
    local ScreenPosition = UserInputService:GetMouseLocation()
    local RelativePosition = ScreenPosition - self:GetPosition()

    return RelativePosition
end

function CWindow:GetMouseButtonsPressed()
    if not self.m_Focused then
        return {}
    end

    return UserInputService:GetMouseButtonsPressed()
end

function CWindow:GetKeysPressed()
    if not self.m_Focused then
        return {}
    end

    return UserInputService:GetKeysPressed()
end

function CWindow:IsGamepadButtonDown(...)
    if not self.m_Focused then
        return false
    end

    return UserInputService:IsGamepadButtonDown(...)
end

function CWindow:IsKeyDown(...)
    if not self.m_Focused then
        return false
    end

    return UserInputService:IsKeyDown(...)
end

function CWindow:IsMouseButtonPressed(...)
    if not self.m_Focused then
        return false
    end

    return UserInputService:IsMouseButtonPressed(...)
end

function CWindow:Destroy()
    self._Destroy()
end

return CWindow
