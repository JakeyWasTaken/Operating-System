-- colors - show off the terminal's rich-text formatting modes
local Ansi = require("/system/lib/Ansi.luau")

local Lines = {}

table.insert(Lines, Ansi.Style("Text styles:", "Bold"))
table.insert(Lines, table.concat({
	Ansi.Style("bold", "Bold"),
	Ansi.Style("italic", "Italic"),
	Ansi.Style("underline", "Underline"),
	Ansi.Style("strike", "Strike"),
}, "  "))

table.insert(Lines, "")
table.insert(Lines, Ansi.Style("Colors:", "Bold"))

local Names = { "Red", "Green", "Yellow", "Blue", "Magenta", "Cyan", "White" }

local Normal = {}
local Bright = {}
for _, Name in Names do
	table.insert(Normal, Ansi.Style(Name, Name))
	table.insert(Bright, Ansi.Style("Bright" .. Name, "Bright" .. Name))
end
table.insert(Lines, table.concat(Normal, "  "))
table.insert(Lines, table.concat(Bright, "  "))

table.insert(Lines, "")
table.insert(Lines, Ansi.Style("Truecolor gradient:", "Bold"))

local Gradient = {}
for Index = 0, 31 do
	local T = Index / 31
	local R = math.floor(255 * T)
	local G = math.floor(128 + 127 * math.sin(T * math.pi))
	local B = math.floor(255 * (1 - T))
	table.insert(Gradient, Ansi.Rgb(R, G, B) .. "█")
end
table.insert(Lines, table.concat(Gradient) .. Ansi.Reset)

print(table.concat(Lines, "\n"))
