const grOverlay = require("@core/Debug/Graphics/Overlay")
const Overlays = require("./Overlays")

local RunService = game:GetService("RunService")

RunService.Heartbeat:Connect(function()
    grOverlay.PushStyle({
        Height = 8
    })

    for _, Overlay in Overlays do
        Overlay.Render()
    end

    grOverlay.PopStyle()

    grOverlay.Render()
end)

return true
