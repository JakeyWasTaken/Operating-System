--[[

    load

    exists to load in .tar.zst archives

    arguments:

    -a - Archive type [supported: tar]
    -c - Compression type [supported: zstd]
    -d - Data string
    -o - Output location, if not provided working directory will be used (opt)
    -n - When provided, data string is treated as a url to the raw data (opt)


    example:

    load -a tar -c zstd -n -d "https://gist.githubusercontent.com/JakeyWasTaken/5b1d408a7b0f1eff25f63dd94a3c60f8/raw/7ffe319f7dc766b7d051389db73e386561f86c65/os%2520load"
]]

local SUPPORTED_ARCHIVES = { "tar" }
local SUPPORTED_COMPRESSION = { "zstd" }

local ONE_GB = 1024 * 1024 * 1024

local encoding = require("@osiris/encoding")
local fs = require("@osiris/fs")
local network = require("@osiris/network")
local process = require("@osiris/process")

local Ansi = require("/system/lib/Ansi.luau")
local Args = require("/system/lib/Args.luau")

-- Parse arguments
local Parsed, ParseError = Args.Parse(process.GetArguments(), {
	{ Name = "ArchiveType", Short = "a", TakesValue = true },
	{ Name = "CompressionType", Short = "c", TakesValue = true },
	{ Name = "Data", Short = "d", TakesValue = true },
	{ Name = "Output", Short = "o", TakesValue = true },
	{ Name = "IsUrl", Short = "n", Default = false },
})

if not Parsed then
	warn(Ansi.Style(`load: {ParseError}`, "Red"))
	exit(-1)
end

local Arguments = Parsed.Options

if not Arguments.Data then
	warn(Ansi.Style("load: missing data", "Red"))
	exit(-1)
end

if not Arguments.ArchiveType then
	warn(Ansi.Style("load: missing archive type", "Red"))
	exit(-1)
end

if not Arguments.CompressionType then
	warn(Ansi.Style("load: missing compression type", "Red"))
	exit(-1)
end

if not table.find(SUPPORTED_ARCHIVES, Arguments.ArchiveType) then
	warn(Ansi.Style(`load: unsupported archive type "{Arguments.ArchiveType}", supports: {table.concat(SUPPORTED_ARCHIVES, ", ")}`, "Red"))
	exit(-1)
end

if not table.find(SUPPORTED_COMPRESSION, Arguments.CompressionType) then
	warn(Ansi.Style(`load: unsupported compression type "{Arguments.CompressionType}", supports: {table.concat(SUPPORTED_COMPRESSION, ", ")}`, "Red"))
	exit(-1)
end

local EncodedData = Arguments.Data :: string

if Arguments.IsUrl then
	local Ok, Error = pcall(function()
		local Response = network.RequestAsync({
			Url = Arguments.Data,
			Method = "GET",
		})

		if not Response.Success then
			error(`failed with status code: [{Response.StatusCode}] status message: "{Response.StatusMessage}"`, 0)
		end

		EncodedData = Response.Body
	end)

	if not Ok then
		warn(Ansi.Style(`load: failed to get data over network, error:\n{Error}`, "Red"))
		exit(-1)
	end
end

local RawData = encoding.Base64Decode(buffer.fromstring(EncodedData))

local ArchiveData: buffer

do -- Decompress
	if Arguments.CompressionType == "zstd" then
		local Ok, Error = pcall(function()
			local Size = encoding.GetDecompressedBufferSize(RawData, Enum.CompressionAlgorithm.Zstd)
			if not Size then
				error(`unable to get decompressed size`)
			elseif Size > ONE_GB then
				error(("decompressed size is too large >1GB [%.1fGB]"):format(Size / ONE_GB))
			end

			ArchiveData = encoding.DecompressBuffer(RawData, Enum.CompressionAlgorithm.Zstd)
		end)

		if not Ok then
			warn(Ansi.Style(`load: failed to decompress data, error:\n{Error}`, "Red"))
			exit(-1)
		end
	end
end

local function MakeDirectory(Path: string)
	local ExpandedPath = Arguments.Output and `{Arguments.Output}/{Path}` or Path
	local Success, Error = fs.CreateDirectory(ExpandedPath)

	if not Success then
		warn(Ansi.Style(`load: failed to make directory "{ExpandedPath}", error:\n{Error}`, "Red"))
		exit(-1)
	end

	print(Ansi.Style(`Made directory "{ExpandedPath}"`, "Blue", "Bold"))
end

local function MakeFile(Path: string, Data: string)
	local ExpandedPath = Arguments.Output and `{Arguments.Output}/{Path}` or Path
	local Success, Error = fs.CreateFile(ExpandedPath)

	if not Success then
		warn(Ansi.Style(`load: failed to make file "{ExpandedPath}", error:\n{Error}`, "Red"))
		exit(-1)
	end

	local Handle, OpenError = fs.Open(ExpandedPath)

	if not Handle then
		warn(Ansi.Style(`load: failed to open file "{ExpandedPath}", error:\n{OpenError}`, "Red"))
		exit(-1)
	end

	local WriteSuccess, WriteError = fs.Write(Handle, Data, 0)

	if not WriteSuccess then
		warn(Ansi.Style(`load: failed to write to file "{ExpandedPath}", error:\n{WriteError}`, "Red"))
		exit(-1)
	end

	fs.Close(Handle)

	print(`Made file "{ExpandedPath}" {#Data}B`)
end

do -- Load archive
	if Arguments.ArchiveType == "tar" then
		local RootNode
		local Ok, Error = pcall(function()
			RootNode = encoding.OpenTar(ArchiveData)
		end)

		if not Ok then
			warn(Ansi.Style(`load: failed to open archive, error:\n{Error}`, "Red"))
			exit(-1)
		end

		local Directories: { string } = {}
		local Files: { [string]: string } = {}

		local function ProcessNode(Node)
			if Node.type == "directory" then
				for _, Child in Node.children do
					ProcessNode(Child)
				end

				if Node.path ~= "" then
					table.insert(Directories, Node.path)
				end
			else
				if Node.path ~= "" then
					Files[Node.path] = Node.data
				end
			end
		end

		ProcessNode(RootNode)

		for _, Directory in Directories do
			MakeDirectory(Directory)
		end

		for Directory, Data in Files do
			MakeFile(Directory, Data)
		end
	end
end
