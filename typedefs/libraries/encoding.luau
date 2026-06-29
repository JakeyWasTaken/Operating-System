export type TarFileNode = {
	type: "file",
	name: string,
	path: string,
	size: number,
	mode: number,
	mtime: number,
	data: string,
}

export type TarDirectoryNode = {
	type: "directory",
	name: string,
	path: string,
	children: { [string]: TarNode },
}

export type TarNode = TarFileNode | TarDirectoryNode

local encoding = {}

function encoding.Base64Encode(Input: buffer): buffer
	return nil :: any
end

function encoding.Base64Decode(Input: buffer): buffer
	return nil :: any
end

function encoding.CompressBuffer(Input: buffer, Algorithm: Enum.CompressionAlgorithm, CompressionLevel: number?): buffer
	return nil :: any
end

function encoding.DecompressBuffer(Input: buffer, Algorithm: Enum.CompressionAlgorithm): buffer
	return nil :: any
end

function encoding.GetDecompressedBufferSize(Input: buffer, Algorithm: Enum.CompressionAlgorithm): number?
	return nil :: any
end

function encoding.ComputeBufferHash(Input: buffer, Algorithm: Enum.HashAlgorithm): buffer
	return nil :: any
end

function encoding.ComputeStringHash(Input: string, Algorithm: Enum.HashAlgorithm): string
	return nil :: any
end

--- Parses a raw tar archive buffer into an in-memory tree of directory/file nodes.
function encoding.OpenTar(Input: buffer): TarNode
	return nil :: any
end

function encoding.ParseTOML(Source: string): ({ [string]: any }?, string)
	return nil :: any
end

return encoding
