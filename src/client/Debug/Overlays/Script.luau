const grOverlay = require("@core/Debug/Graphics/Overlay")
const ScriptFactory = require("@kernel/Script/ScriptFactory")

local Overlay = {}

function Overlay.Render()
    grOverlay.Begin("Script", Color3.new(0.4, 0.4, 0.4))

    --- The source and byte code cache size
    grOverlay.Text(`Script data cache memory: {ScriptFactory.GetCacheSize()}B`)
    grOverlay.Text(`Script cache count: {ScriptFactory.GetCacheCount()}`)

    grOverlay.End()
end

return Overlay
