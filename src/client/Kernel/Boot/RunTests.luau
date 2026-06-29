const ProcessFactory = require("@kernel/Process/ProcessFactory")
const CFilePath = require("@kernel/File/FilePath")
const FileContext = require("@kernel/File/FileContext")
const FileSystemManager = require("@kernel/File/FileSystemManager")

const BootInterface = require("@kernel/Interface/Interfaces/BootInterface")

const TEST_WORKING_DIRECTORY = "/tmp/tests"

-- Returns a function instead of running at require-time - GetExitCode() blocks, and
-- blocking during require() never resumes (see ConditionVariable:Wait).
return function(): boolean
	const RootContext = FileContext()
	const TestContext = FileContext()
	TestContext.WorkingDirectory = TEST_WORKING_DIRECTORY

	-- Setup the temp directory

	const FileSystem = FileSystemManager.GetActiveFileSystem()
	const TempPath = CFilePath.new(TEST_WORKING_DIRECTORY)
	const Result = FileSystem:CreateDirectory(TempPath, RootContext)
	if not Result.Success then
		BootInterface.PushString("Failed to make tests temporary file, cannot boot.")
		return false
	end

	BootInterface.PushString("")
	BootInterface.PushString("-- RUNNING TESTS --")
	BootInterface.PushString("")

	local Failed = false
	local function RunTest(Label: string, Path: string)
		local Process = ProcessFactory.CreateProcess(CFilePath.new(Path), {}, {}, TestContext)
		if not Process.Success then
			BootInterface.PushString(`[{Path}][ERROR] Failed to create test process:`)
			BootInterface.PushString(Process.Value)
			return
		end

		task.spawn(function()
			while true do
				local Data = Process.Value.StdOut:Read()
				if not Data then
					break
				end

				-- A single chunk can contain several newline-separated entries
				-- (print/warn now each end in "\n"), so prefix every line with
				-- the label instead of just the chunk as a whole.
				for _, Line in Data:split("\n") do
					if Line ~= "" then
						BootInterface.PushString(`[{Label}]: {Line}`)
					end
				end
			end
		end)

		Failed = Failed or Process.Value:GetExitCode() == -1
	end

	RunTest("VM/Conformance", "/tests/vm/runConformance.luau")
	RunTest("VM/Require", "/tests/vm/runRequireFiles.luau")
	RunTest("Core", "/tests/core/runCore.luau")
	RunTest("Kernel/Process", "/tests/kernel/runProcess.luau")
	RunTest("Kernel/FileSystem", "/tests/kernel/runFileSystem.luau")

	BootInterface.PushString("")

	-- Cleanup temp directory

	const TempNode = FileSystem:ResolvePath(TempPath, RootContext)
	if not TempNode then
		BootInterface.PushString("Failed to get temporary test directory")
	else
		if not FileSystem:DeleteNode(TempNode:GetHandle()) then
			BootInterface.PushString("Failed to delete temporary test directory")
		end
	end

	if Failed then
		BootInterface.PushString("A test(s) failed, boot cannot continue.")
	else
		BootInterface.PushString("All tests succeeded, booting")
	end

	return not Failed
end
