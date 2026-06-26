const BootInterface = require("@kernel/Interface/Interfaces/BootInterface")
const FileSystemManager = require("@kernel/File/FileSystemManager")
const CFileSystem = require("@kernel/File/FileSystem")
const CFilePath = require("@kernel/File/FilePath")
const FileContext = require("@kernel/File/FileContext")

local FileSystem = CFileSystem.new()
FileSystemManager.SetActiveFileSystem(FileSystem)

local Directories = 0
local Files = 0

local FileSystemFolder = game:GetService("StarterPlayer")
							:FindFirstChild("Client")
							:FindFirstChild("Static")

local Context = FileContext()

local function LoadFolder(Folder: Folder, PathString: string)
	for _, Child in Folder:GetChildren() do
		if Child:IsA("Folder") then
			BootInterface.PushString(`Made directory "{`{PathString}/{Child.Name}`}"`)

			FileSystem:CreateDirectory(CFilePath.new(`{PathString}/{Child.Name}`), Context)
			LoadFolder(Child, `{PathString}/{Child.Name}`)

			Directories += 1
		elseif Child:IsA("ModuleScript") then
			xpcall(function()
				local File = require(Child)
				local FileName = File.Name
				local Contents = File.Contents

				local Path = CFilePath.new(`{PathString}/{FileName}`)
				local Result = FileSystem:CreateFile(Path, Context)
				assert(Result.Success, Result.Reason)

				Result.Value:Write(Contents)

				BootInterface.PushString(`Made file "{`{PathString}/{FileName}`}" {Result.Value:GetSize()}B`)
				Files += 1
			end, BootInterface.PushString)
		end

		task.wait()
	end
end

BootInterface.PushString("-- BUILDING FILE SYSTEM --")
BootInterface.PushString("")

LoadFolder(FileSystemFolder, "")

BootInterface.PushString("")
BootInterface.PushString(`Made {Directories} directories, {Files} files`)

return true
