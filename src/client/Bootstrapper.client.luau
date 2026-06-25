_G.DEV = true

const CFileSystem = require("@kernel/File/FileSystem")
const FileSystemManager = require("@kernel/File/FileSystemManager")
const FilePath = require("@kernel/File/FileSystem/FilePath")
const FileContext = require("@kernel/File/FileContext")

local FS = CFileSystem.new()
FileSystemManager.SetActiveFileSystem(FS)

-- Load in our pre-defined file system (src/client/FileSystem/...)
do
	-- stylua: ignore
	local FileSystemFolder = game:GetService("StarterPlayer")
								:FindFirstChild("Client")
								:FindFirstChild("Static")

	local Context = FileContext()

	local function LoadFolder(Folder: Folder, PathString: string)
		for _, Child in Folder:GetChildren() do
			if Child:IsA("Folder") then
				FS:CreateDirectory(FilePath.new(`{PathString}/{Child.Name}`), Context)
				LoadFolder(Child, `{PathString}/{Child.Name}`)
			elseif Child:IsA("ModuleScript") then
				xpcall(function()
					local File = require(Child)
					local FileName = File.Name
					local Contents = File.Contents

					local Path = FilePath.new(`{PathString}/{FileName}`)
					local Result = FS:CreateFile(Path, Context)
					assert(Result.Success, Result.Reason)

					Result.Value:Write(Contents)
				end, warn)
			end
		end
	end

	LoadFolder(FileSystemFolder, "/")
end

require("@client/Debug/DebugLoader")

const TableExplorer = require("@core/Debug/Graphics/TableExplorer")
TableExplorer.AddTable("FileSystemHandles", FS.m_Handles)

const ProcessFactory = require("@kernel/Process/ProcessFactory")
const ProcessScheduler = require("@kernel/Process/ProcessScheduler")

game:GetService("RunService").Heartbeat:Connect(function()
    ProcessScheduler.Tick()
end)

task.wait(5)

local Result = ProcessFactory.CreateProcess(FilePath.new("/tests/vm/runConformance.luau"), {}, {}, FileContext())
assert(Result.Success, Result.Reason)

Result = ProcessFactory.CreateProcess(FilePath.new("/tests/vm/runRequireFiles.luau"), {}, {}, FileContext())
assert(Result.Success, Result.Reason)

Result = ProcessFactory.CreateProcess(FilePath.new("/tests/core/runCore.luau"), {}, {}, FileContext())
assert(Result.Success, Result.Reason)

Result = ProcessFactory.CreateProcess(FilePath.new("/tests/kernel/runProcess.luau"), {}, {}, FileContext())
assert(Result.Success, Result.Reason)

Result = ProcessFactory.CreateProcess(FilePath.new("/tests/kernel/runFileSystem.luau"), {}, {}, FileContext())
assert(Result.Success, Result.Reason)

-- TODO: handle escalated processes, figure out how file handles will be owned (per process? per root process?) probably per process thinking abt it now, makes way more sense since you can detach at any point
