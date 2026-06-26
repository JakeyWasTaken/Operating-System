_G.DEV = true

const grOverlay = require("@core/Debug/Graphics/Overlay")
const Overlays = require("./Overlays")

local RunService = game:GetService("RunService")

RunService.Heartbeat:Connect(function()
    grOverlay.PushStyle({
        Height = 8
    })

    grOverlay.SetActiveLayer(grOverlay.GetLayer("Main", UDim2.new(0.5, 0)))

    for _, Overlay in Overlays do
        Overlay.Render()
    end

    grOverlay.PopActiveLayer()

    grOverlay.PopStyle()

    grOverlay.Render()
end)

return true
