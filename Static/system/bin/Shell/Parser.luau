--[[

	Tokenisation rules (a small POSIX-like subset):
		- Tokens are separated by runs of whitespace.
		- Single quotes preserve everything literally until the next single quote.
		- Double quotes preserve everything except a backslash escaping a `"` or `\`.
		- A backslash outside of quotes escapes the next character.

]]

local Parser = {}

export type Command = {
	Program: string,
	Arguments: { string },
}

--- Splits a line into tokens. Returns nil and a reason on malformed input
--- (e.g. an unterminated quote).
function Parser.Tokenize(Line: string): ({ string }?, string)
	local Tokens = {}

	-- `Current` is nil when we are between tokens and a string (possibly empty)
	-- while we are building one. This lets `""` produce an empty argument.
	local Current: string? = nil
	local Quote: string? = nil

	local Index = 1
	local Length = #Line

	while Index <= Length do
		local Char = string.sub(Line, Index, Index)

		if Quote then
			if Char == Quote then
				Quote = nil
			elseif Char == "\\" and Quote == '"' then
				local Next = string.sub(Line, Index + 1, Index + 1)
				if Next == '"' or Next == "\\" then
					Current = (Current or "") .. Next
					Index += 2
					continue
				end

				Current = (Current or "") .. Char
			else
				Current = (Current or "") .. Char
			end
		elseif Char == "'" or Char == '"' then
			Quote = Char
			Current = Current or ""
		elseif Char == "\\" then
			local Next = string.sub(Line, Index + 1, Index + 1)
			if Next ~= "" then
				Current = (Current or "") .. Next
				Index += 2
				continue
			end
		elseif string.match(Char, "%s") then
			if Current ~= nil then
				table.insert(Tokens, Current)
				Current = nil
			end
		else
			Current = (Current or "") .. Char
		end

		Index += 1
	end

	if Quote then
		return nil, `unterminated {Quote} quote`
	end

	if Current ~= nil then
		table.insert(Tokens, Current)
	end

	return Tokens, ""
end

--- Parses a line into a Command. Returns nil with an empty reason for a blank
--- line, or nil with a reason when tokenisation fails.
function Parser.Parse(Line: string): (Command?, string)
	local Tokens, Reason = Parser.Tokenize(Line)
	if not Tokens then
		return nil, Reason
	end

	if #Tokens == 0 then
		return nil, ""
	end

	local Program = table.remove(Tokens, 1) :: string

	return {
		Program = Program,
		Arguments = Tokens,
	}, ""
end

return Parser
