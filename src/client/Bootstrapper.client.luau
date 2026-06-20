require("@kernel/File/FileSystem"):Initialize()

const TableExplorer = require("@core/Debug/Graphics/TableExplorer")
TableExplorer.AddTable("NodeRegistry", require("@kernel/File/NodeRegistry").GetRegistry())

const ProcessFactory = require("@kernel/Process/ProcessFactory")
const ProcessScheduler = require("@kernel/Process/ProcessScheduler")
const CPath = require("@kernel/File/Path")
const Context = require("@kernel/File/Context")

game:GetService("RunService").Heartbeat:Connect(function()
    ProcessScheduler.Tick()
end)

local Result = ProcessFactory.CreateProcess(CPath.new("/tests/vm/runConformance.luau"), Context.new())
assert(Result.Success, Result.Reason)
