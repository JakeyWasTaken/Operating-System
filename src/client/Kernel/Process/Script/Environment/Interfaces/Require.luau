const CPath = require("@kernel/File/Path")
const FileSystem = require("@kernel/File/FileSystem")
const EnvironmentContext = require("../EnvironmentContext")
const FileContext = require("@kernel/File/Context")

-- All libraries should be added here, otherwise they will be unavailable within processes
const Libraries = {
    require("../Libraries/LibProcess"),
    require("../Libraries/LibProcess")
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
			local Name = Target:sub(2, #Target)
			local Library = GetLibrary(Name)
			if Library == nil then
				error(`error requiring "{Target}": library does not exist`, 0)
			end

			return Library
		end

		local FilePathStr = Target

		assert(shared.ProcessFactory, `ProcessFactory was not ready in-time`)
		local Process = shared.ProcessFactory.GetProcess(PID)
		assert(Process, `No process with PID "{PID}"`)

		local FilePath = CPath.new(FilePathStr)
		if not FilePath:IsValid() then
			error(`error requiring "{FilePathStr}": invalid path`, 0)
		end

		if FilePath:GetPathType() == "Relative" then
			FilePath = ScriptPath:Append(FilePathStr)
		end

		if not FilePath:IsValid() then
			-- This is pretty vague, this could be weird to debug
			error(`error requiring "{FilePathStr}": expanded path was invalid`, 0)
		end

		local Context = FileContext.Copy(Process.FileContext)
		Context.WorkingDirectory = ScriptPath:ToString()

		local NodeHandle = FileSystem:Resolve(FilePath, Context)
		if not NodeHandle.Success then
			error(`error requiring "{FilePathStr}": no path exists`, 0)
		end

		local Type = FileSystem:GetType(NodeHandle.Value :: string)
		if not Type.Success or Type.Value ~= "File" then
			error(`error requiring "{FilePathStr}": provided path does not point to a file`, 0)
		end

		local Contents = FileSystem:Read(NodeHandle.Value :: string)
		if not Contents.Success then
			error(`error requiring "{FilePathStr}": failed to read file contents`, 0)
		end

		-- Make script
		local Script = shared.ScriptFactory.CreateScript(Contents.Value, FilePath:GetParent(), NodeHandle.Value, PID)
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
