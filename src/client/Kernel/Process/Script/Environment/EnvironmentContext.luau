const FilePath = require("@kernel/File/FileSystem/FilePath")

type CFilePath = FilePath.CFilePath
export type EnvironmentContext = {
    PID: number,
    ScriptPath: CFilePath,
}

return true
