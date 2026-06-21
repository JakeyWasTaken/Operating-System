_G.DEV = true

require("@kernel/File/FileSystem"):Initialize()
require("@client/Debug/DebugLoader")

const TableExplorer = require("@core/Debug/Graphics/TableExplorer")
TableExplorer.AddTable("NodeRegistry", require("@kernel/File/NodeRegistry").GetRegistry())

const ProcessFactory = require("@kernel/Process/ProcessFactory")
const ProcessScheduler = require("@kernel/Process/ProcessScheduler")
const CPath = require("@kernel/File/Path")
const Context = require("@kernel/File/Context")

game:GetService("RunService").Heartbeat:Connect(function()
    ProcessScheduler.Tick()
end)

task.wait(5)

local Result = ProcessFactory.CreateProcess(CPath.new("/tests/vm/runConformance.luau"), Context.new())
assert(Result.Success, Result.Reason)

Result = ProcessFactory.CreateProcess(CPath.new("/tests/vm/runRequireFiles.luau"), Context.new())
assert(Result.Success, Result.Reason)

Result = ProcessFactory.CreateProcess(CPath.new("/tests/core/runCore.luau"), Context.new())
assert(Result.Success, Result.Reason)
