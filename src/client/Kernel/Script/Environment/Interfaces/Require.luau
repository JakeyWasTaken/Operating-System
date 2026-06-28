const CFilePath = require("@kernel/File/FilePath")
const FileSystemInterface = require("@kernel/File/FileSystemInterface")
const FileSystemManager = require("@kernel/File/FileSystemManager")
const EnvironmentContext = require("../EnvironmentContext")
const FileContext = require("@kernel/File/FileContext")

-- All libraries should be added here, otherwise they will be unavailable within processes
const Libraries = {
    require("../Libraries/LibProcess"),
    require("../Libraries/LibFileSystem"),
    require("../Libraries/LibWindow"),
    require("../Libraries/LibTest"),
    require("../Libraries/LibTOML"),
}

type EnvironmentContext = EnvironmentContext.EnvironmentContext

return function(Context: EnvironmentContext)
    const PID, ScriptPath = Context.PID, Context.ScriptPath

    local LoadedLibraries = {}
    const function GetLibrary(Name: string)
		if LoadedLibraries[Name] then
			return LoadedLibraries[Name]
		end

		for _, LibraryDefinition in Libraries do
			if LibraryDefinition.Name == Name and LibraryDefinition.Enabled then
				const Library = LibraryDefinition.MakeLibrary(PID, ScriptPath)
				LoadedLibraries[Name] = Library
				return Library
			end
		end

		return nil
	end

    return function(Target: string)
        if Target:sub(1, 1) == "@" then
            local Data = Target:sub(2, #Target)
            local SplitData = Data:split("/")
            if SplitData[1] ~= "osiris" then
                error(`unknown alias "{SplitData[1]}"`, 0)
            end

            local LibraryName = SplitData[2]
			local Library = GetLibrary(LibraryName)
			if Library == nil then
				error(`error requiring "{Target}": library does not exist`, 0)
			end

			return Library
		end

		local FilePathStr = Target

		assert(shared.ProcessFactory, `ProcessFactory was not ready in-time`)
		local Process = shared.ProcessFactory.GetProcess(PID)
		assert(Process, `No process with PID "{PID}"`)

		local FilePath = CFilePath.new(FilePathStr)
		if not FilePath:IsValid() then
			error(`error requiring "{FilePathStr}": invalid path`, 0)
		end

		local FirstPart = FilePath:GetParts()[1]
		if not FirstPart or (FirstPart.Type ~= "Root" and FirstPart.Type ~= "Home") then
			FilePath = ScriptPath:Append(FilePathStr)
		end

		if not FilePath:IsValid() then
			-- This is pretty vague, this could be weird to debug
			error(`error requiring "{FilePathStr}": expanded path was invalid`, 0)
		end

		local Context = FileContext(Process.FileContext)
		Context.WorkingDirectory = ScriptPath:GetString()

		local FS = FileSystemManager.GetActiveFileSystem()
		if not FS then
			error(`error requiring "{FilePathStr}": no active file system`, 0)
		end

		local Node = FS:ResolvePath(FilePath, Context)
		if not Node then
			error(`error requiring "{FilePathStr}": no path exists`, 0)
		end

		if not Node:IsFile() then
			error(`error requiring "{FilePathStr}": provided path does not point to a file`, 0)
		end

		local Contents = (Node :: FileSystemInterface.IFile):Read()

		-- Make script
		local Script = shared.ScriptFactory.CreateScript(Contents, FilePath:GetParent(), Node:GetHandle(), PID)
		if not Script:IsCompiled() then
			local CompilationResult = Script:Compile()
			if not CompilationResult.Success then
				error(`error requiring "{FilePathStr}": failed to compile, {CompilationResult.Reason}`, 0)
			end
		end

		local RunResult = Script:Run()
		if not RunResult.Success then
			error(`error requiring "{FilePathStr}": failed to run, {RunResult.Reason}`, 0)
		end

		if RunResult.Value == nil or #(RunResult.Value :: {any}) ~= 1 then
			error(`Module did not return exactly one value.`)
		end

		return (RunResult.Value :: {any})[1]
    end
end
