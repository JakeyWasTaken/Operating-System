const grOverlay = require("@core/Debug/Graphics/Overlay")
const ProcessScheduler = require("@kernel/Process/ProcessScheduler")
const ProcessFactory = require("@kernel/Process/ProcessFactory")

local Overlay = {}

function Overlay.Render()
    grOverlay.Begin("Process", Color3.new(0.4, 0.4, 0.4))

    grOverlay.Begin("List", Color3.new(0.2, 0.2, 0.2))

    for _, Process in ProcessFactory.GetAllProcesses() do
        grOverlay.Begin(`Process Id: {Process:GetPID()}`, Color3.new(0.8, 0.4, 0.4))
        grOverlay.Text((`Alive For: %.2fs`):format(os.clock() - Process.StartedAt))

        if Process:GetParentPID() then
            grOverlay.Text(`Parent Process Id: {Process:GetParentPID()}`)
        end

        if #Process:GetChildPIDs() > 0 then
            grOverlay.Begin("Child Processes")
            for _, ChildPID in Process:GetChildPIDs() do
                grOverlay.Text(`Process Id: {ChildPID}`)
            end
            grOverlay.End()
        end

        grOverlay.End()
    end

    grOverlay.End()

    grOverlay.Begin("Threads", Color3.new(0.2, 0.2, 0.2))

    for _, Thread in ProcessScheduler.GetAllThreads() do
        grOverlay.Begin(`Thread Id: {Thread.ThreadId}`, Color3.new(0.8, 0.4, 0.4))
        grOverlay.Text(`Process Id: {Thread.PID}`)
        grOverlay.Text(`Is Main: {Thread.IsMain}`)
        grOverlay.Text(`State: {Thread.State}`)
        grOverlay.Text(Thread.WakeAt and (`Waking In: %.2fs`):format(Thread.WakeAt - os.clock()) or "Waking In: ~s")
        grOverlay.End()
    end

    grOverlay.End()

    grOverlay.End()
end

return Overlay
