const FileSystemInterface = require("./FileSystemInterface")

local ActiveFileSystem: FileSystemInterface.IFileSystem? = nil
local FileSystemManager = {}

function FileSystemManager.GetActiveFileSystem(): FileSystemInterface.IFileSystem?
    return ActiveFileSystem
end

function FileSystemManager.SetActiveFileSystem(FileSystem: FileSystemInterface.IFileSystem?)
    ActiveFileSystem = FileSystem
end

return FileSystemManager
