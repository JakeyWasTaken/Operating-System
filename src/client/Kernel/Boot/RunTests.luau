const ProcessFactory = require("@kernel/Process/ProcessFactory")
const CFilePath = require("@kernel/File/FilePath")
const FileContext = require("@kernel/File/FileContext")

const BootInterface = require("@kernel/Interface/Interfaces/BootInterface")

-- Returns a function instead of running at require-time - GetExitCode() blocks, and
-- blocking during require() never resumes (see ConditionVariable:Wait).
return function(): boolean
	BootInterface.PushString("")
	BootInterface.PushString("-- RUNNING TESTS --")
	BootInterface.PushString("")

	local Failed = false
	local function RunTest(Label: string, Path: string)
		local Process = ProcessFactory.CreateProcess(CFilePath.new(Path), {}, {}, FileContext())
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

				BootInterface.PushString(`[{Label}]: {Data}`)
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

	if Failed then
		BootInterface.PushString("A test(s) failed, boot cannot continue.")
	else
		BootInterface.PushString("All tests succeeded, booting")
	end

	return not Failed
end
