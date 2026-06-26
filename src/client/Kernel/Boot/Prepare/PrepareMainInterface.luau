const InterfaceManager = require("@kernel/Interface/InterfaceManager")
const MainInterface = require("@kernel/Interface/Interfaces/MainInterface")
const BootInterface = require("@kernel/Interface/Interfaces/BootInterface")
const WindowFactory = require("@kernel/Window/WindowFactory")

InterfaceManager.SetInterface(MainInterface)
BootInterface.Clear()

const JDI = require("@vendor/JustDrawIt")

local Window = WindowFactory.CreateWindow()
Window:SetFullscreen(true)
Window:SetDrawCallback(function()
    return JDI.create "Frame" {
        AnchorPoint = Vector2.one * 0.5,
        Size = UDim2.fromOffset(25, 25),
        BackgroundColor3 = Color3.new(1, 0.3, 0.3),
        Position = UDim2.new(0.5, math.sin(os.clock()) * 150, 0.5, math.cos(os.clock()) * 150)
    }
end)

return true
