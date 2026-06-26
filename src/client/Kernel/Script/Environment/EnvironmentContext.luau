const FilePath = require("@kernel/File/FilePath")

type CFilePath = FilePath.CFilePath
export type EnvironmentContext = {
    PID: number,
    ScriptPath: CFilePath,
}

return true
