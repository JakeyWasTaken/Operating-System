local process = require("@osiris/process")
local window = require("@osiris/window")
local create = window.Graphics.Create

local WindowHandle = assert(window.Create())
local InputContext = window.GetInputContext(WindowHandle)

window.SetFullscreen(WindowHandle, true)
window.SetFocused(WindowHandle, true)
window.SetDrawCallback(WindowHandle, function()
	return create("Frame")({
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,

		create("Frame")({
			AnchorPoint = Vector2.one * 0.5,
			Size = UDim2.fromOffset(25, 25),
			BackgroundColor3 = Color3.new(1, 0.3, 0.3),
			Position = UDim2.new(0.5, math.sin(os.clock()) * 150, 0.5, math.cos(os.clock()) * 150),
		}),

		create("TextLabel")({
			Text = `A cool window\nPID: {process.GetPID()}\nHandle: {WindowHandle}`,
			Size = UDim2.fromScale(1, 1),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.25),
			BackgroundTransparency = 1,
			TextColor3 = Color3.new(1, 1, 1),
			TextWrapped = false,
			TextScaled = false,
			TextSize = 16,
			FontFace = Font.fromName("RobotoMono", Enum.FontWeight.Bold),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
		}),

		create("TextLabel")({
			Text = function()
				local KeyCodes = {}

				for _, Key in InputContext.GetKeysPressed() do
					table.insert(KeyCodes, InputContext.GetStringForKeyCode(Key.KeyCode, Enum.KeyCodeStringFormat.Default))
				end

				return `Pressed Keys:\n{table.concat(KeyCodes, "\n")}`
			end,
			Size = UDim2.fromScale(1, 1),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.75),
			BackgroundTransparency = 1,
			TextColor3 = Color3.new(1, 1, 1),
			TextWrapped = false,
			TextScaled = false,
			TextSize = 16,
			FontFace = Font.fromName("RobotoMono", Enum.FontWeight.Bold),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
		}),
	})
end)

while true do
	task.wait(60)
end
