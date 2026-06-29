_G.DEV = true

const grOverlay = require("@core/Debug/Graphics/Overlay")
const Overlays = require("./Overlays")

const RunService = game:GetService("RunService")
const UserInputService = game:GetService("UserInputService")

local Draw = true

RunService.Heartbeat:Connect(function()
    if Draw then
        grOverlay.PushStyle({
            Height = 8
        })

        grOverlay.SetActiveLayer(grOverlay.GetLayer("Main", UDim2.new(0.5, 0)))
        grOverlay.Text("F2 to show / hide")

        for _, Overlay in Overlays do
            Overlay.Render()
        end

        grOverlay.PopActiveLayer()

        grOverlay.PopStyle()
    end

    grOverlay.Render()
end)

UserInputService.InputEnded:Connect(function(Input: InputObject)
    if Input.KeyCode ~= Enum.KeyCode.F2 then
        return
    end

    Draw = not Draw
end)

return true
