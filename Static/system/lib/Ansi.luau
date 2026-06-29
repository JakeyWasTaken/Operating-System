--[[

	Ansi

	A small ANSI SGR (Select Graphic Rendition) layer shared by the shell and its
	programs. Programs emit escape sequences like "\27[31m" with the helpers here;
	the terminal calls ToRichText to convert a finished block of text into Roblox
	RichText markup when it draws.

	Literal text is always escaped, so a program that knows nothing about
	formatting (and just prints text containing "<" or "&") still renders safely.

]]

local Ansi = {}

local ESC = "\27"

--- Named SGR codes, for programs that prefer names over numbers.
local NAMED: { [string]: number } = {
	Reset = 0,
	Bold = 1,
	Dim = 2,
	Italic = 3,
	Underline = 4,
	Strike = 9,

	Black = 30,
	Red = 31,
	Green = 32,
	Yellow = 33,
	Blue = 34,
	Magenta = 35,
	Cyan = 36,
	White = 37,

	BrightBlack = 90,
	BrightRed = 91,
	BrightGreen = 92,
	BrightYellow = 93,
	BrightBlue = 94,
	BrightMagenta = 95,
	BrightCyan = 96,
	BrightWhite = 97,
}

Ansi.Codes = NAMED
Ansi.Reset = ESC .. "[0m"

--- Foreground colour palette used when converting to RichText.
local PALETTE: { [number]: string } = {
	[30] = "#1c1c1c",
	[31] = "#d4534f",
	[32] = "#4fb04f",
	[33] = "#d4b94f",
	[34] = "#5079d4",
	[35] = "#b05ec2",
	[36] = "#4fb9c2",
	[37] = "#c7c7c7",

	[90] = "#6e6e6e",
	[91] = "#ff7b76",
	[92] = "#7be07b",
	[93] = "#ffec84",
	[94] = "#84a8ff",
	[95] = "#e08ef0",
	[96] = "#84e6f0",
	[97] = "#ffffff",
}

--- Builds an escape sequence from a list of numeric codes or code names, e.g.
--- Ansi.SGR("Red", "Bold") or Ansi.SGR(31, 1).
function Ansi.SGR(...): string
	local Params = {}
	for _, Code in { ... } do
		if type(Code) == "string" then
			Code = NAMED[Code] or 0
		end
		table.insert(Params, tostring(Code))
	end

	return ESC .. "[" .. table.concat(Params, ";") .. "m"
end

--- Wraps Text in the given styles, resetting afterwards, e.g.
--- Ansi.Style("hi", "Red", "Bold").
function Ansi.Style(Text: string, ...): string
	return Ansi.SGR(...) .. Text .. Ansi.Reset
end

--- A truecolor foreground escape.
function Ansi.Rgb(R: number, G: number, B: number): string
	return `{ESC}[38;2;{R};{G};{B}m`
end

local LITERAL_ESCAPES = { ["&"] = "&amp;", ["<"] = "&lt;", [">"] = "&gt;" }
local function EscapeLiteral(Text: string): string
	return (string.gsub(Text, "[&<>]", LITERAL_ESCAPES))
end

--- Converts a string that may contain ANSI SGR escapes into Roblox RichText.
--- Unrecognised escape sequences (cursor moves and the like) are dropped, and
--- all tags are balanced, so the result is always safe to assign to a label.
function Ansi.ToRichText(Text: string): string
	local Out = {}
	local Open = {} -- Close-tag strings for everything currently open, in order.

	local State = {
		Bold = false,
		Italic = false,
		Underline = false,
		Strike = false,
		Color = nil :: string?,
	}

	local function CloseAll()
		for Index = #Open, 1, -1 do
			Out[#Out + 1] = Open[Index]
			Open[Index] = nil
		end
	end

	local function OpenState()
		if State.Color then
			Out[#Out + 1] = `<font color="{State.Color}">`
			Open[#Open + 1] = "</font>"
		end
		if State.Bold then
			Out[#Out + 1] = "<b>"
			Open[#Open + 1] = "</b>"
		end
		if State.Italic then
			Out[#Out + 1] = "<i>"
			Open[#Open + 1] = "</i>"
		end
		if State.Underline then
			Out[#Out + 1] = "<u>"
			Open[#Open + 1] = "</u>"
		end
		if State.Strike then
			Out[#Out + 1] = "<s>"
			Open[#Open + 1] = "</s>"
		end
	end

	local function ApplyParams(Params: { string })
		local Index = 1
		while Index <= #Params do
			local Code = tonumber(Params[Index]) or 0

			if Code == 0 then
				State.Bold, State.Italic, State.Underline, State.Strike, State.Color = false, false, false, false, nil
			elseif Code == 1 then
				State.Bold = true
			elseif Code == 22 then
				State.Bold = false
			elseif Code == 3 then
				State.Italic = true
			elseif Code == 23 then
				State.Italic = false
			elseif Code == 4 then
				State.Underline = true
			elseif Code == 24 then
				State.Underline = false
			elseif Code == 9 then
				State.Strike = true
			elseif Code == 29 then
				State.Strike = false
			elseif Code == 39 then
				State.Color = nil
			elseif PALETTE[Code] then
				State.Color = PALETTE[Code]
			elseif Code == 38 then
				local Mode = tonumber(Params[Index + 1])
				if Mode == 2 then
					-- 38;2;r;g;b truecolor
					local R = tonumber(Params[Index + 2]) or 0
					local G = tonumber(Params[Index + 3]) or 0
					local B = tonumber(Params[Index + 4]) or 0
					State.Color = string.format("#%02x%02x%02x", R, G, B)
					Index += 4
				elseif Mode == 5 then
					-- 38;5;n indexed; map the first 16 onto our palette
					local N = tonumber(Params[Index + 2]) or 0
					State.Color = PALETTE[if N < 8 then 30 + N else 82 + N] or State.Color
					Index += 2
				end
			end

			Index += 1
		end
	end

	local Literal = {}
	local function FlushLiteral()
		if #Literal > 0 then
			Out[#Out + 1] = EscapeLiteral(table.concat(Literal))
			table.clear(Literal)
		end
	end

	local Index, Length = 1, #Text
	while Index <= Length do
		local Char = string.sub(Text, Index, Index)

		if Char == ESC and string.sub(Text, Index + 1, Index + 1) == "[" then
			-- Consume a CSI sequence: ESC [ <params> <final byte 0x40-0x7e>.
			local Scan = Index + 2
			while Scan <= Length do
				local Byte = string.byte(Text, Scan)
				if Byte and Byte >= 0x40 and Byte <= 0x7e then
					break
				end
				Scan += 1
			end

			-- Only colour (`m`) sequences mean anything to us; ignore the rest.
			if string.sub(Text, Scan, Scan) == "m" then
				FlushLiteral()
				CloseAll()
				ApplyParams(string.sub(Text, Index + 2, Scan - 1):split(";"))
				OpenState()
			end

			Index = Scan + 1
		else
			Literal[#Literal + 1] = Char
			Index += 1
		end
	end

	FlushLiteral()
	CloseAll()

	return table.concat(Out)
end

return Ansi
