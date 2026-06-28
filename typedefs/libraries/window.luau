export type Connection = {
	Disconnect: (self: Connection) -> (),
	Destroy: (self: Connection) -> (),
	Connected: boolean,
}

export type Signal<T...> = {
	Connect: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	Once: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	DisconnectAll: (self: Signal<T...>) -> (),
	GetConnections: (self: Signal<T...>) -> { Connection },
	Wait: (self: Signal<T...>) -> T...,
}

export type InputContext = {
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

local window = {}

window.Graphics = {
	Create = (nil :: any) :: (Class: string) -> (Properties: { [any]: any }) -> any,
}

function window.Create(): (string?, string)
	return nil :: any
end

function window.Destroy(ScopedHandle: string): (boolean?, string)
	return nil :: any
end

--- The draw callback **MUST NOT** yield
function window.SetDrawCallback(ScopedHandle: string, Callback: (() -> unknown)?): (boolean?, string)
	return nil :: any
end

function window.Focus(ScopedHandle: string, Focused: boolean): (boolean?, string)
	return nil :: any
end

function window.IsFocused(ScopedHandle: string): (boolean?, string)
	return nil :: any
end

function window.SetMinimized(ScopedHandle: string, Minimized: boolean): (boolean?, string)
	return nil :: any
end

function window.IsMinimized(ScopedHandle: string): (boolean?, string)
	return nil :: any
end

function window.SetFullscreen(ScopedHandle: string, Fullscreen: boolean): (boolean?, string)
	return nil :: any
end

function window.IsFullscreen(ScopedHandle: string): (boolean?, string)
	return nil :: any
end

function window.GetSize(ScopedHandle: string): (Vector2?, string)
	return nil :: any
end

function window.GetPosition(ScopedHandle: string): (Vector2?, string)
	return nil :: any
end

function window.BringToTop(ScopedHandle: string): (boolean?, string)
	return nil :: any
end

function window.GetInputContext(ScopedHandle: string): (InputContext?, string)
	return nil :: any
end

return window
