--[[

	Editor

	The actual nano-like full-screen text editor. /bin/nano.luau just requires
	this and calls Editor.Open(Path). No syntax highlighting/linting - it's a
	plain multi-line TextBox with a title bar and a hint/status footer.

	Keybinds: Ctrl+S to save, Ctrl+X to exit.

]]

local fs = require("@osiris/fs")
local window = require("@osiris/window")

local create = window.Graphics.Create

local TEXT_SIZE = 16
local BAR_HEIGHT = TEXT_SIZE + 10
local SCROLLBAR_THICKNESS = 6
-- Roblox's own top bar overlaps fullscreen windows unless we leave room for it.
local TOP_INSET = 58
local FONT = Font.fromName("RobotoMono", Enum.FontWeight.Regular)
local BOLD_FONT = Font.fromName("RobotoMono", Enum.FontWeight.Bold)

local BACKGROUND_COLOR = Color3.fromRGB(12, 12, 14)
local BAR_COLOR = Color3.fromRGB(40, 60, 90)
local TEXT_COLOR = Color3.fromRGB(220, 220, 220)
local HINT_COLOR = Color3.fromRGB(160, 160, 160)
local ERROR_COLOR = Color3.fromRGB(255, 120, 120)
local OK_COLOR = Color3.fromRGB(140, 220, 140)

local Editor = {}

local function Exists(Path: string): boolean
	local Handle = fs.Open(Path)
	if Handle then
		fs.Close(Handle)
		return true
	end

	return false
end

--- Replaces a file's entire contents. fs.Write only ever overwrites in place
--- or grows a file - the tail past the new data is always preserved - so a
--- real "replace" has to delete and recreate the file first.
local function SaveFile(Path: string, Content: string): (boolean?, string)
	if Exists(Path) then
		local Ok, Err = fs.Delete(Path)
		if not Ok then
			return nil, `failed to clear old contents: {Err}`
		end
	end

	local Ok, Err = fs.CreateFile(Path)
	if not Ok then
		return nil, `failed to create file: {Err}`
	end

	local Handle, OpenErr = fs.Open(Path)
	if not Handle then
		return nil, `failed to open file: {OpenErr}`
	end

	local WriteOk, WriteErr = fs.Write(Handle, Content, 0)
	fs.Close(Handle)

	if not WriteOk then
		return nil, `failed to write file: {WriteErr}`
	end

	return true, ""
end

--- Opens Path (creating it fresh if it doesn't exist yet) in a fullscreen
--- editor window. Blocks until the user exits (Ctrl+X).
function Editor.Open(Path: string)
	local Handle = assert(window.Create())
	local InputContext = assert(window.GetInputContext(Handle))

	window.SetFullscreen(Handle, true)
	window.SetFocused(Handle, true)
	window.BringToTop(Handle)

	local InitialContent = ""
	if Exists(Path) then
		local FileHandle = fs.Open(Path)
		if FileHandle then
			InitialContent = fs.Read(FileHandle) or ""
			fs.Close(FileHandle)
		end
	end

	local TextBox: TextBox? = nil
	local LastSavedContent = InitialContent
	local StatusMessage = ""
	local StatusIsError = false
	local Closed = false

	local function SetStatus(Message: string, IsError: boolean?)
		StatusMessage = Message
		StatusIsError = IsError == true
	end

	local function Save()
		if not TextBox then
			return
		end

		local Ok, Err = SaveFile(Path, TextBox.Text)
		if Ok then
			LastSavedContent = TextBox.Text
			SetStatus(`Wrote {#TextBox.Text:split("\n")} lines`)
		else
			SetStatus(`Error: {Err}`, true)
		end
	end

	InputContext.InputBegan:Connect(function(Input)
		if Input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end

		local CtrlDown = InputContext.IsKeyDown(Enum.KeyCode.LeftControl) or InputContext.IsKeyDown(Enum.KeyCode.RightControl)
		if not CtrlDown then
			return
		end

		if Input.KeyCode == Enum.KeyCode.S then
			Save()
		elseif Input.KeyCode == Enum.KeyCode.X then
			Closed = true
		end
	end)

	window.SetDrawCallback(Handle, function()
		local IsDirty = TextBox ~= nil and TextBox.Text ~= LastSavedContent

		return create("Frame")({
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = BACKGROUND_COLOR,
			BorderSizePixel = 0,

			-- Everything else sits inset from the top, so Roblox's own top bar
			-- doesn't overlap the title bar.
			create("Frame")({
				Size = UDim2.new(1, 0, 1, -TOP_INSET),
				Position = UDim2.fromOffset(0, TOP_INSET),
				BackgroundTransparency = 1,

				-- Title bar
				create("Frame")({
					Size = UDim2.new(1, 0, 0, BAR_HEIGHT),
					BackgroundColor3 = BAR_COLOR,
					BorderSizePixel = 0,

					create("TextLabel")({
						Text = `  {Path}{if IsDirty then " *" else ""}`,
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						TextColor3 = TEXT_COLOR,
						FontFace = BOLD_FONT,
						TextSize = TEXT_SIZE,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Center,
					}),
				}),

				-- Body: a ScrollingFrame so documents taller than the window can be
				-- scrolled through. AutomaticCanvasSize is a property on
				-- ScrollingFrame whose value is an Enum.AutomaticSize member (there
				-- is no separate "AutomaticCanvasSize" enum) - it grows the canvas
				-- to fit the TextBox below automatically.
				create("ScrollingFrame")({
					Size = UDim2.new(1, -16, 1, -BAR_HEIGHT * 2),
					Position = UDim2.fromOffset(8, BAR_HEIGHT),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,

					AutomaticCanvasSize = Enum.AutomaticSize.XY,
					CanvasSize = UDim2.new(1, 0, 0, 0),
					ScrollingDirection = Enum.ScrollingDirection.XY,
					ScrollBarThickness = SCROLLBAR_THICKNESS,
					ScrollBarImageColor3 = TEXT_COLOR,

					create("TextBox")({
						-- AncestryChanged fires for this box and again for each ancestor
						-- as the tree is parented; the first fire is the box's own
						-- parenting, so we capture it once and ignore the rest.
						AncestryChanged = function(Child: Instance, Parent: Instance?)
							if Parent and TextBox == nil then
								TextBox = Child :: TextBox
								task.defer(function()
									(TextBox :: TextBox):CaptureFocus()
								end)
							end
						end,

						-- Constant, so JDI writes it once at creation and never again -
						-- it won't fight the user's typing.
						Text = InitialContent,

						AutomaticSize = Enum.AutomaticSize.XY,
						Size = UDim2.fromScale(0, 0),
						BackgroundTransparency = 1,
						ClearTextOnFocus = false,
						MultiLine = true,
						TextEditable = true,
						TextWrapped = false,
						TextColor3 = TEXT_COLOR,
						TextSize = TEXT_SIZE,
						FontFace = FONT,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Top,
					}),
				}),

				-- Footer: key hints on the left, last status message on the right.
				create("Frame")({
					Size = UDim2.new(1, 0, 0, BAR_HEIGHT),
					Position = UDim2.new(0, 0, 1, -BAR_HEIGHT),
					BackgroundColor3 = BAR_COLOR,
					BorderSizePixel = 0,

					create("TextLabel")({
						Text = "  ^S Save    ^X Exit",
						Size = UDim2.fromScale(0.5, 1),
						BackgroundTransparency = 1,
						TextColor3 = HINT_COLOR,
						FontFace = FONT,
						TextSize = TEXT_SIZE,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Center,
					}),

					create("TextLabel")({
						Text = StatusMessage .. "  ",
						Size = UDim2.fromScale(0.5, 1),
						Position = UDim2.fromScale(0.5, 0),
						BackgroundTransparency = 1,
						TextColor3 = if StatusIsError then ERROR_COLOR else OK_COLOR,
						FontFace = FONT,
						TextSize = TEXT_SIZE,
						TextXAlignment = Enum.TextXAlignment.Right,
						TextYAlignment = Enum.TextYAlignment.Center,
					}),
				}),
			}),
		})
	end)

	while not Closed do
		task.wait()
	end

	window.Destroy(Handle)
end

return Editor
