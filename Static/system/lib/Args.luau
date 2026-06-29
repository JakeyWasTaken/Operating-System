--[[

	getopt-style argument and flag parsing for programs. Given the raw argument
	list (process.GetArguments()) and a spec, it returns the parsed options plus
	any leftover positional arguments, or nil and a reason on malformed input.

	Supported forms:
		-f                  boolean short flag
		-abc                clustered boolean short flags (same as -a -b -c)
		-o value / -ovalue  short option taking a value
		--flag              boolean long flag
		--key value         long option taking a value
		--key=value         long option with an inline value
		--                  stop parsing; everything after is positional

]]

local Args = {}

export type Option = {
	--- Key the parsed value is stored under in the result.
	Name: string,
	--- Single-character form, matched as -x.
	Short: string?,
	--- Long form, matched as --xxx.
	Long: string?,
	--- When true the option consumes a value; otherwise it is a boolean flag.
	TakesValue: boolean?,
	--- Value used when the option is absent.
	Default: (string | boolean)?,
	--- When true, parsing fails if the option is absent.
	Required: boolean?,
}

export type Parsed = {
	Options: { [string]: string | boolean },
	Positionals: { string },
}

function Args.Parse(Arguments: { string }, Spec: { Option }): (Parsed?, string)
	local ByShort: { [string]: Option } = {}
	local ByLong: { [string]: Option } = {}
	for _, Option in Spec do
		if Option.Short then
			ByShort[Option.Short] = Option
		end
		if Option.Long then
			ByLong[Option.Long] = Option
		end
	end

	local Result: Parsed = { Options = {}, Positionals = {} }

	local Index = 1
	local Count = #Arguments
	local OnlyPositionals = false

	while Index <= Count do
		local Token = Arguments[Index]

		if OnlyPositionals or Token == "-" or string.sub(Token, 1, 1) ~= "-" then
			-- A bare "-", or anything not starting with "-", is positional.
			table.insert(Result.Positionals, Token)
		elseif Token == "--" then
			OnlyPositionals = true
		elseif string.sub(Token, 1, 2) == "--" then
			local Body = string.sub(Token, 3)
			local EqualsAt = string.find(Body, "=", 1, true)
			local Name = if EqualsAt then string.sub(Body, 1, EqualsAt - 1) else Body
			local InlineValue = if EqualsAt then string.sub(Body, EqualsAt + 1) else nil

			local Option = ByLong[Name]
			if not Option then
				return nil, `unknown option "--{Name}"`
			end

			if Option.TakesValue then
				local Value = InlineValue
				if not Value then
					Index += 1
					Value = Arguments[Index]
					if Value == nil then
						return nil, `option "--{Name}" requires a value`
					end
				end
				Result.Options[Option.Name] = Value
			elseif InlineValue then
				return nil, `option "--{Name}" does not take a value`
			else
				Result.Options[Option.Name] = true
			end
		else
			-- A short cluster like "-abc" or "-o value".
			local Cluster = string.sub(Token, 2)
			local Cursor = 1
			while Cursor <= #Cluster do
				local Char = string.sub(Cluster, Cursor, Cursor)
				local Option = ByShort[Char]
				if not Option then
					return nil, `unknown option "-{Char}"`
				end

				if Option.TakesValue then
					-- The value is the rest of the cluster, or the next token.
					local Rest = string.sub(Cluster, Cursor + 1)
					if string.sub(Rest, 1, 1) == "=" then
						Rest = string.sub(Rest, 2)
					end

					local Value = if Rest ~= "" then Rest else nil
					if not Value then
						Index += 1
						Value = Arguments[Index]
						if Value == nil then
							return nil, `option "-{Char}" requires a value`
						end
					end
					Result.Options[Option.Name] = Value
					break -- the remainder of the cluster was the value
				end

				Result.Options[Option.Name] = true
				Cursor += 1
			end
		end

		Index += 1
	end

	-- Apply defaults and enforce required options.
	for _, Option in Spec do
		if Result.Options[Option.Name] ~= nil then
			continue
		end

		if Option.Required then
			local Label = if Option.Long then `--{Option.Long}` elseif Option.Short then `-{Option.Short}` else Option.Name
			return nil, `missing required option "{Label}"`
		end

		if Option.Default ~= nil then
			Result.Options[Option.Name] = Option.Default
		end
	end

	return Result, ""
end

return Args
