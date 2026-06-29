--[[

	LibEncoding / encoding

]]

const CFilePath = require("@kernel/File/FilePath")
const Tar = require("@vendor/Tar")

const EncodingService = game:GetService("EncodingService")

type CFilePath = CFilePath.CFilePath

return {
	Name = "encoding",
	Enabled = true,
	MakeLibrary = function(LibraryPID: number, ScriptPath: CFilePath)
		return {
            Base64Encode = function(Input: buffer): buffer
                return EncodingService:Base64Encode(Input)
            end,

            Base64Decode = function(Input: buffer): buffer
                return EncodingService:Base64Decode(Input)
            end,

            CompressBuffer = function(Input: buffer, Algorithm: Enum.CompressionAlgorithm, CompressionLevel: number?): buffer
                return EncodingService:CompressBuffer(Input, Algorithm, CompressionLevel)
            end,

            DecompressBuffer = function(Input: buffer, Algorithm: Enum.CompressionAlgorithm): buffer
                return EncodingService:DecompressBuffer(Input, Algorithm)
            end,

            GetDecompressedBufferSize = function(Input: buffer, Algorithm: Enum.CompressionAlgorithm): number?
                return EncodingService:GetDecompressedBufferSize(Input, Algorithm)
            end,

            ComputeBufferHash = function(Input: buffer, Algorithm: Enum.HashAlgorithm): buffer
                return EncodingService:ComputeBufferHash(Input, Algorithm)
            end,

            ComputeStringHash = function(Input: string, Algorithm: Enum.HashAlgorithm): string
                return EncodingService:ComputeStringHash(Input, Algorithm)
            end,

            OpenTar = function(Input: buffer): Tar.Node
                -- We could do similar architecture here like we do in other libraries, but going to remain consistent with this library's functions
                local Node, Error = Tar(Input)
                if not Node then
                    error(Error, 0)
                end

                return Node
            end
		}
	end,
}
