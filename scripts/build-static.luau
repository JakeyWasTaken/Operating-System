-- Builds static-build/ from Static/, via lune.
--
-- Every file under Static/ is treated as raw source. Each one gets wrapped
-- into a Luau module of the shape: return { Name = "...", Contents = "..." }
-- so it can be loaded as a static file by the kernel's FileSystem. Directory
-- structure is preserved 1:1 between Static/ and static-build/.
--
-- e.g. lune run scripts/build-static

local fs = require("@lune/fs")

local SOURCE_DIR = "Static"
local OUTPUT_DIR = "static-build"

-- Contents gets dropped into a [[ ]] long string. If the source itself
-- contains a `]]` (or `]=]`, `]==]`, ...) that would terminate it early, so
-- pick an equals-count that doesn't collide with anything already in the file.
local function GetSafeBracketLevel(Contents: string): number
	local Level = 0

	for EqualsRun in Contents:gmatch("%]=*%]") do
		local N = #EqualsRun - 2
		if N >= Level then
			Level = N + 1
		end
	end

	return Level
end

local function WrapFile(FileName: string, Contents: string): string
	local Level = GetSafeBracketLevel(Contents)
	local Equals = ("="):rep(Level)
	local OpenBracket = `[{Equals}[`
	local CloseBracket = `]{Equals}]`

	return 'return {\n\tName = "' .. FileName .. '",\n\tContents = ' .. OpenBracket .. "\n" .. Contents .. "\n" .. CloseBracket .. ",\n}\n"
end

local FileCount = 0
local DirCount = 0

local function ProcessDirectory(RelativePath: string)
	local SourcePath = RelativePath == "" and SOURCE_DIR or `{SOURCE_DIR}/{RelativePath}`
	local OutputPath = RelativePath == "" and OUTPUT_DIR or `{OUTPUT_DIR}/{RelativePath}`

	fs.writeDir(OutputPath)
	DirCount += 1

	for _, Name in fs.readDir(SourcePath) do
		local EntrySourcePath = `{SourcePath}/{Name}`
		local EntryRelativePath = RelativePath == "" and Name or `{RelativePath}/{Name}`

		if fs.isDir(EntrySourcePath) then
			ProcessDirectory(EntryRelativePath)
		else
			local Contents = fs.readFile(EntrySourcePath)

			-- The wrapped module must end in .luau so rojo syncs it as a
			-- ModuleScript. The original filename is preserved in Name, so the
			-- VFS still sees e.g. "test.service".
			local OutputName = Name:match("%.luau?$") and Name or `{Name}.luau`
			local OutputRelativePath = RelativePath == "" and OutputName or `{RelativePath}/{OutputName}`

			fs.writeFile(`{OUTPUT_DIR}/{OutputRelativePath}`, WrapFile(Name, Contents))
			FileCount += 1
		end
	end
end

if not fs.isDir(SOURCE_DIR) then
	error(`"{SOURCE_DIR}" does not exist, nothing to build`)
end

if fs.isDir(OUTPUT_DIR) then
	fs.removeDir(OUTPUT_DIR)
end

ProcessDirectory("")

print(`Built {FileCount} file(s) across {DirCount} director(y/ies) into "{OUTPUT_DIR}"`)
