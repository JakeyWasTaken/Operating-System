--[[

	Stdio

	The terminal's output buffer. Text written to it is split into lines so the
	window manager can render the tail that fits on screen. It can also drain an
	IOReader (a spawned process' stdout or stderr) straight into the buffer.

	To stop the buffer growing without bound it keeps a running character count
	and discards the oldest content once it passes MaxCharacters.

]]

local process = require("@osiris/process")

type IOReader = process.IOReader

local Stdio = {}
Stdio.__index = Stdio

export type Stdio = typeof(setmetatable(
	{} :: {
		m_Lines: { string },
		m_Length: number,
		m_MaxCharacters: number,
	},
	Stdio
))

local DEFAULT_MAX_CHARACTERS = 150_000

--- @param MaxCharacters number? - How many characters of scrollback to retain. Defaults to 150,000.
function Stdio.new(MaxCharacters: number?): Stdio
	local self = setmetatable({}, Stdio)

	-- The final entry is always the "current" line; writes append to it until a
	-- newline starts a fresh one. m_Length tracks the total character count
	-- including the newline that joins each line to the next.
	self.m_Lines = { "" }
	self.m_Length = 0
	self.m_MaxCharacters = MaxCharacters or DEFAULT_MAX_CHARACTERS

	return self
end

--- Discards the oldest content until the buffer is within its character budget.
function Stdio.Trim(self: Stdio)
	local Lines = self.m_Lines

	-- Drop whole lines from the front first; each carries its joining newline.
	while self.m_Length > self.m_MaxCharacters and #Lines > 1 do
		local Removed = table.remove(Lines, 1) :: string
		self.m_Length -= #Removed + 1
	end

	-- A single line longer than the whole budget: drop its oldest characters.
	if self.m_Length > self.m_MaxCharacters then
		local Excess = self.m_Length - self.m_MaxCharacters
		Lines[1] = string.sub(Lines[1], Excess + 1)
		self.m_Length -= Excess
	end
end

--- Appends raw text, expanding newlines into new lines and trimming scrollback.
function Stdio.Write(self: Stdio, Text: string)
	-- Carriage returns from programs would otherwise render as stray glyphs.
	Text = (string.gsub(tostring(Text), "\r", ""))
	if Text == "" then
		return
	end

	local Lines = self.m_Lines
	local Start = 1

	while true do
		local NewlineAt = string.find(Text, "\n", Start, true)
		if not NewlineAt then
			Lines[#Lines] ..= string.sub(Text, Start)
			break
		end

		Lines[#Lines] ..= string.sub(Text, Start, NewlineAt - 1)
		table.insert(Lines, "")
		Start = NewlineAt + 1
	end

	-- Every character of Text ends up in the buffer: non-newline characters as
	-- line contents, each newline as a line separator.
	self.m_Length += #Text
	self:Trim()
end

--- Appends text followed by a newline.
function Stdio.WriteLine(self: Stdio, Text: string?)
	self:Write((Text or "") .. "\n")
end

--- Returns a copy of every retained line.
function Stdio.GetLines(self: Stdio): { string }
	return table.clone(self.m_Lines)
end

--- Returns the last `Count` lines (fewer if the buffer is shorter).
function Stdio.GetTail(self: Stdio, Count: number): { string }
	local Lines = self.m_Lines
	local Tail = {}

	for Index = math.max(1, #Lines - Count + 1), #Lines do
		table.insert(Tail, Lines[Index])
	end

	return Tail
end

--- Empties the buffer.
function Stdio.Clear(self: Stdio)
	self.m_Lines = { "" }
	self.m_Length = 0
end

--- Reads from `Reader` until the stream closes, appending each chunk. This
--- yields, so run it in its own task.
function Stdio.ListenToReader(self: Stdio, Reader: IOReader)
	while true do
		local Data = Reader:Read()
		if Data == nil then
			break
		end

		self:Write(Data)
	end
end

return Stdio
