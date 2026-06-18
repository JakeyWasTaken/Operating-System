--[[

RULES ON PATHS:

Paths prefixed with "/" are assumed to be absolute,
Paths prefixed with "./" or "../" are assumed to be relative,
Paths with NO prefix are assumed to be relative

]]

export type PathType = "Absolute" | "Relative"
export type ParsedPath = {
	Type: PathType,

	Traversal: {
		{
			--- If type is Escape then Name will be an empty string
			Type: "Escape" | "Enter",
			Name: string,
		}
	},
}

local Parser = {}

function Parser.GetPathType(Path: string): PathType
	if Path:sub(1, 1) == "/" then
		return "Absolute"
	else
		return "Relative"
	end
end

function Parser.Parse(Path: string): ParsedPath
	local ParsedPath: ParsedPath = {
		Type = Parser.GetPathType(Path),

		Traversal = {},
	}

	local SplitPath = Path:split("/")

	-- Clean empty segments
	local CleanedPath = {}
	for _, Split in SplitPath do
		if Split == "" then
			continue
		end

		table.insert(CleanedPath, Split)
	end

	-- Build out traversal from splits
	for _, Split in CleanedPath do
		local Type: "Escape" | "Enter" = "Enter"
		local Name = Split

		if Split == "." then -- Ignore single dots
			continue
		end

		if Split == ".." then
			Type = "Escape"
			Name = ""
		end

		table.insert(ParsedPath.Traversal, {
			Type = Type,
			Name = Name,
		})
	end

	return ParsedPath
end

return Parser
