--[[

	WindowManager

	Owns the terminal window. Output is drawn into a fixed-size scrollback label
	showing whatever recent lines fit on screen; the current line is an actual
	Roblox TextBox, so Roblox handles all of the fiddly text editing (layout,
	shift, caps, caret, selection, paste) for us. Submitted lines are queued so
	the shell's read-eval-print loop can pull them with ReadLine.

]]

local Ansi = require("/system/lib/Ansi.luau")
local Stdio = require("./Stdio.luau")
local window = require("@osiris/window")

local create = window.Graphics.Create

type Stdio = Stdio.Stdio

local TEXT_SIZE = 16
local LINE_PADDING = 2
local LINE_HEIGHT = TEXT_SIZE + LINE_PADDING
local INPUT_HEIGHT = TEXT_SIZE + 6
local DEFAULT_SIZE = Vector2.new(800, 600)
local MAX_HISTORY = 200

local BACKGROUND_COLOR = Color3.fromRGB(12, 12, 14)
local TEXT_COLOR = Color3.fromRGB(220, 220, 220)
local FONT = Font.fromName("RobotoMono", Enum.FontWeight.Regular)
local BOLD_FONT = Font.fromName("RobotoMono", Enum.FontWeight.Bold)

local WindowManager = {}
WindowManager.__index = WindowManager

export type WindowManager = typeof(setmetatable(
	{} :: {
		m_Handle: string,
		m_Output: Stdio,

		m_Prompt: string,
		m_Echo: boolean,

		m_PendingLines: { string },
		m_TextBox: TextBox?,

		m_History: { string },
		--- 0 means the live, uncommitted line; 1 is the most recent history
		--- entry, 2 the one before that, etc.
		m_HistoryIndex: number,
		--- What the user was typing before they started navigating history, so
		--- pressing Down back past the first entry restores it.
		m_HistoryDraft: string,
	},
	WindowManager
))

--- Opens a fullscreen, focused terminal window backed by `Output`.
function WindowManager.new(Output: Stdio): WindowManager
	local self = setmetatable({}, WindowManager)

	self.m_Handle = assert(window.Create())
	self.m_Output = Output

	self.m_Prompt = ""
	self.m_Echo = true

	self.m_PendingLines = {}
	self.m_TextBox = nil

	self.m_History = {}
	self.m_HistoryIndex = 0
	self.m_HistoryDraft = ""

	window.SetFullscreen(self.m_Handle, true)

	-- TextBox doesn't surface Up/Down as editing events, so we watch raw key
	-- input ourselves just for those two keys and drive history navigation.
	local InputContext = assert(window.GetInputContext(self.m_Handle))
	InputContext.InputBegan:Connect(function(Input)
		if Input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end

		if Input.KeyCode == Enum.KeyCode.Up then
			self:HistoryUp()
		elseif Input.KeyCode == Enum.KeyCode.Down then
			self:HistoryDown()
		end
	end)

	-- Re-claim keyboard focus whenever this window becomes the focused one
	-- again (e.g. after another window, like the editor, closes or loses it).
	InputContext.WindowFocused:Connect(function()
		self:Focus()
	end)

	window.SetDrawCallback(self.m_Handle, function()
		return self:Render()
	end)

	return self
end

--- Records a submitted line for Up/Down recall, skipping blanks and immediate
--- repeats, and resets navigation back to the live line.
function WindowManager.PushHistory(self: WindowManager, Line: string)
	self.m_HistoryIndex = 0
	self.m_HistoryDraft = ""

	if Line == "" or self.m_History[#self.m_History] == Line then
		return
	end

	table.insert(self.m_History, Line)
	if #self.m_History > MAX_HISTORY then
		table.remove(self.m_History, 1)
	end
end

--- Recalls an older history entry, saving the in-progress draft on the way in.
function WindowManager.HistoryUp(self: WindowManager)
	local TextBox = self.m_TextBox
	if not TextBox or self.m_HistoryIndex >= #self.m_History then
		return
	end

	if self.m_HistoryIndex == 0 then
		self.m_HistoryDraft = TextBox.Text
	end

	self.m_HistoryIndex += 1

	local Entry = self.m_History[#self.m_History - self.m_HistoryIndex + 1]
	TextBox.Text = Entry
	TextBox.CursorPosition = #Entry + 1
end

--- Recalls a more recent history entry, or the saved draft once navigation
--- reaches the live line again.
function WindowManager.HistoryDown(self: WindowManager)
	local TextBox = self.m_TextBox
	if not TextBox or self.m_HistoryIndex <= 0 then
		return
	end

	self.m_HistoryIndex -= 1

	local Text = if self.m_HistoryIndex == 0 then self.m_HistoryDraft else self.m_History[#self.m_History - self.m_HistoryIndex + 1]

	TextBox.Text = Text
	TextBox.CursorPosition = #Text + 1
end

--- Ensures the input TextBox holds keyboard focus, but only while this window
--- itself has focus - otherwise we'd steal Roblox-level focus away from
--- whatever other window (e.g. the editor) is actually supposed to have it.
--- Deferred to the next frame so it's safe to call from inside a
--- focus-changed handler.
function WindowManager.Focus(self: WindowManager)
	task.defer(function()
		if self.m_TextBox and window.IsFocused(self.m_Handle) then
			self.m_TextBox:CaptureFocus()
		end
	end)
end

--- Fired by the TextBox when editing ends. Enter commits the line; either way we
--- grab focus again so the terminal always stays ready for typing.
function WindowManager.OnFocusLost(self: WindowManager, EnterPressed: boolean)
	local TextBox = self.m_TextBox
	if TextBox and EnterPressed then
		local Line = TextBox.Text

		if self.m_Echo then
			self.m_Output:Write(self.m_Prompt .. Line .. "\n")
		end

		TextBox.Text = ""
		table.insert(self.m_PendingLines, Line)
		self:PushHistory(Line)
	end

	self:Focus()
end

--- Yields until a line has been submitted, then returns it.
function WindowManager.ReadLine(self: WindowManager): string
	while #self.m_PendingLines == 0 do
		task.wait()
	end

	return table.remove(self.m_PendingLines, 1) :: string
end

--- Sets the prompt drawn in front of the input line.
function WindowManager.SetPrompt(self: WindowManager, Prompt: string)
	self.m_Prompt = Prompt
end

--- When echo is on, submitted lines are written into the output buffer. Turn it
--- off while forwarding input to a child process that echoes for itself.
function WindowManager.SetEcho(self: WindowManager, Echo: boolean)
	self.m_Echo = Echo
end

--- Builds the VNode tree for the terminal. Must not yield.
function WindowManager.Render(self: WindowManager)
	local WindowSize = window.GetSize(self.m_Handle) or DEFAULT_SIZE
	local ViewportHeight = math.max(0, WindowSize.Y - INPUT_HEIGHT - 8)
	local Rows = math.max(1, math.floor(ViewportHeight / LINE_HEIGHT))

	-- The buffer holds raw text with ANSI escapes; convert just the visible
	-- tail to RichText so styling carries across lines and tags stay balanced.
	local Scrollback = Ansi.ToRichText(table.concat(self.m_Output:GetTail(Rows), "\n"))
	local PromptText = Ansi.ToRichText(Ansi.Reset .. self.m_Prompt)

	return create("Frame")({
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = BACKGROUND_COLOR,
		BorderSizePixel = 0,

		create("TextLabel")({
			Text = "CLICK TO REGAIN FOCUS",
			Size = UDim2.new(1, 0, 1, 0),
			Position = UDim2.fromScale(0, 0),
			BackgroundTransparency = 1,
			TextColor3 = TEXT_COLOR,
			TextWrapped = false,
			TextScaled = false,
			TextSize = function()
				return TEXT_SIZE * (1 + (math.sin(os.clock() * 3) ^ 2 * 0.5))
			end,
			FontFace = BOLD_FONT,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			ZIndex = 1000,
			Visible = function()
				return not window.IsFocused(self.m_Handle)
			end,
		}),

		create("TextLabel")({
			Text = Scrollback,
			RichText = true,
			Size = UDim2.new(1, -16, 1, -INPUT_HEIGHT - 8),
			Position = UDim2.fromOffset(8, 8),
			BackgroundTransparency = 1,
			TextColor3 = TEXT_COLOR,
			TextWrapped = false,
			TextScaled = false,
			TextSize = TEXT_SIZE,
			FontFace = FONT,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Bottom,
		}),

		-- Input row: the prompt label followed by the editable TextBox.
		create("Frame")({
			Size = UDim2.new(1, -16, 0, INPUT_HEIGHT),
			Position = UDim2.new(0, 8, 1, -INPUT_HEIGHT),
			BackgroundTransparency = 1,

			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),

			create("TextLabel")({
				Text = PromptText,
				RichText = true,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromScale(0, 1),
				LayoutOrder = 1,
				BackgroundTransparency = 1,
				TextColor3 = TEXT_COLOR,
				TextSize = TEXT_SIZE,
				FontFace = FONT,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
			}),

			create("TextBox")({
				-- AncestryChanged fires for this box and again for each ancestor as
				-- the tree is parented; the first fire is the box's own parenting,
				-- so we capture it once and ignore the rest (whose Child is an
				-- ancestor) to keep our reference pointed at the TextBox.
				AncestryChanged = function(Child: Instance, Parent: Instance?)
					if Parent and self.m_TextBox == nil then
						self.m_TextBox = Child :: TextBox
						self:Focus()
					end
				end,

				FocusLost = function(EnterPressed: boolean)
					self:OnFocusLost(EnterPressed)
				end,

				-- Constant, so JDI writes it once at creation (clearing the default
				-- "TextBox" text) and never again - it won't fight the user's typing.
				Text = "",

				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromScale(0, 1),
				LayoutOrder = 2,
				BackgroundTransparency = 1,
				ClearTextOnFocus = false,
				MultiLine = false,
				TextEditable = true,
				TextColor3 = TEXT_COLOR,
				TextSize = TEXT_SIZE,
				FontFace = FONT,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
			}),
		}),
	})
end

return WindowManager
